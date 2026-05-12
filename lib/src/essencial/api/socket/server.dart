import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Server extends ChangeNotifier {
  WebSocketChannel? channel;

  bool connected = false;
  String nomedopc = '';
  String hostname = '';
  int port = 0;
  bool aparecendoModalReconectar = false;

  bool _desconexaoIntencional = false;
  int _tentativaReconexao = 0;
  Timer? _temporizadorReconexao;
  Completer<bool>? _conexaoEmAndamento;
  bool _reenviandoMensagensPendentes = false;

  static const int _maximoTentativasReconexao = 12;
  static const Duration _timeoutConexao = Duration(seconds: 8);
  static const int _maximoMensagensPendentes = 200;
  static const Duration _tempoMaximoAguardandoConfirmacaoImpressao = Duration(minutes: 10);
  static const String _chaveMensagensPendentes = 'fila_mensagens_socket_pendentes';

  Future<bool> connect(String ip, String porta) async {
    if (_conexaoEmAndamento != null) {
      return _conexaoEmAndamento!.future;
    }

    final Completer<bool> completer = Completer<bool>();
    _conexaoEmAndamento = completer;

    try {
      final int? portaConvertida = int.tryParse(porta);
      if (portaConvertida == null || portaConvertida <= 0) {
        completer.complete(false);
        return false;
      }

      if (connected && channel != null && hostname == ip && port == portaConvertida) {
        completer.complete(true);
        return true;
      }

      _desconexaoIntencional = false;
      _temporizadorReconexao?.cancel();
      _temporizadorReconexao = null;

      await _encerrarCanalAtual();

      final WebSocket socket = await WebSocket.connect(
        'ws://$ip:$portaConvertida',
      ).timeout(_timeoutConexao);
      socket.pingInterval = const Duration(seconds: 5);

      final WebSocketChannel canalConexao = IOWebSocketChannel(socket);
      channel = canalConexao;
      await canalConexao.ready;

      hostname = ip;
      port = portaConvertida;
      connected = true;
      _tentativaReconexao = 0;
      notifyListeners();

      unawaited(_enviarHandshakeRede());
      unawaited(_reenviarMensagensPendentes());

      canalConexao.stream.listen(
        (message) {
          if (!identical(channel, canalConexao)) {
            return;
          }

          onData(message);
        },
        onError: (error) {
          if (!identical(channel, canalConexao)) {
            return;
          }

          log('WebSocket erro: $error');
          _processarQuedaConexao();
        },
        onDone: () {
          if (!identical(channel, canalConexao)) {
            return;
          }

          log('WebSocket conexao finalizada (onDone).');
          _processarQuedaConexao();
        },
        cancelOnError: true,
      );

      completer.complete(true);
      return true;
    } catch (e, stackTrace) {
      log('Excecao ao conectar', error: e, stackTrace: stackTrace);
      _processarQuedaConexao();
      completer.complete(false);
      return false;
    } finally {
      _conexaoEmAndamento = null;
    }
  }

  Future<void> disconnect() async {
    _desconexaoIntencional = true;
    _tentativaReconexao = 0;
    _temporizadorReconexao?.cancel();
    _temporizadorReconexao = null;
    await _encerrarCanalAtual();
  }

  Future<void> _encerrarCanalAtual() async {
    final WebSocketChannel? canalAtual = channel;
    final bool haviaConexao = channel != null || connected;

    channel = null;
    connected = false;

    if (haviaConexao) {
      notifyListeners();
    }

    if (canalAtual != null) {
      try {
        await canalAtual.sink.close();
      } catch (_) {
        // Ignora erro no fechamento do canal.
      }
    }
  }

  void _processarQuedaConexao() {
    final bool haviaConexao = channel != null || connected;
    channel = null;
    connected = false;

    if (haviaConexao) {
      notifyListeners();
    }

    if (_desconexaoIntencional) {
      log('Reconexao ignorada: desconexao intencional.');
      return;
    }

    _agendarReconexao();
  }

  void _agendarReconexao() {
    if (_desconexaoIntencional) {
      return;
    }

    if (_temporizadorReconexao != null) {
      return;
    }

    if (_tentativaReconexao >= _maximoTentativasReconexao) {
      _mostrarAvisoFalhaReconexao();
      return;
    }

    final Duration atraso = _calcularAtrasoReconexao();
    _tentativaReconexao++;

    log('Tentando reconectar em ${atraso.inSeconds} segundos...');
    _temporizadorReconexao = Timer(atraso, () async {
      _temporizadorReconexao = null;

      if (_desconexaoIntencional) {
        return;
      }

      final ConfigSharedPreferences config = ConfigSharedPreferences();
      final conexao = await config.getConexao();

      if (conexao == null || conexao.servidor.isEmpty || conexao.porta.isEmpty) {
        _mostrarAvisoFalhaReconexao('Dados de conexao nao encontrados para reconectar.');
        return;
      }

      await connect(conexao.servidor, conexao.porta);
    });
  }

  Duration _calcularAtrasoReconexao() {
    final int segundos = (2 * (1 << _tentativaReconexao)).clamp(2, 30);
    return Duration(seconds: segundos);
  }

  void _mostrarAvisoFalhaReconexao([String? mensagem]) {
    final BuildContext? context = navigatorKey?.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(mensagem ?? 'Falha ao reconectar. Verifique o servidor e a rede.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
  }

  Future<void> _enviarHandshakeRede() async {
    final String nomeDispositivo = await _obterNomeDispositivo();
    final String? ip = await _obterIpLocal();

    final Map<String, dynamic> mensagem = <String, dynamic>{
      'tipo': 'Rede',
      'nomedopc': nomeDispositivo,
      'tipodeempresa': '2',
      'nomedosistema': 'Big Chef Garcom',
      'sistemaoperacional': Platform.operatingSystem,
      'ip': ip ?? '',
    };

    nomedopc = nomeDispositivo;
    write(jsonEncode(mensagem));
  }

  Future<String> _obterNomeDispositivo() async {
    try {
      final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        final String modeloAndroid = androidInfo.model.trim();
        if (modeloAndroid.isNotEmpty) {
          return modeloAndroid;
        }
      }

      if (Platform.isIOS) {
        final IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
        final String nomeIos = iosInfo.name.trim();
        if (nomeIos.isNotEmpty) {
          return nomeIos;
        }

        final String modeloIos = iosInfo.model.trim();
        if (modeloIos.isNotEmpty) {
          return modeloIos;
        }
      }
    } catch (_) {
      // Ignora erro de leitura do DeviceInfo.
    }

    final String nomeHost = Platform.localHostname.trim();
    if (nomeHost.isNotEmpty) {
      return nomeHost;
    }

    final String fallbackAmbiente = (Platform.environment['COMPUTERNAME'] ?? Platform.environment['HOSTNAME'] ?? Platform.environment['USER'] ?? '').trim();
    if (fallbackAmbiente.isNotEmpty) {
      return fallbackAmbiente;
    }

    return 'Dispositivo';
  }

  Future<String?> _obterIpLocal() async {
    try {
      final String ip = await ConfigSistema.retornarIPMaquina();
      return ip.isEmpty ? null : ip;
    } catch (_) {
      return null;
    }
  }

  String _serializarMensagemEnvelope(Map<String, dynamic> mensagem) {
    return jsonEncode(<String, dynamic>{
      'type': 'customMessage',
      'data': <String, dynamic>{
        'customType': 'modelo_retorno_socket',
        'customData': mensagem,
      },
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? _desserializarMensagem(dynamic data) {
    try {
      final dynamic mensagemBruta = data is String ? jsonDecode(data) : data;
      if (mensagemBruta is! Map) {
        return null;
      }

      final Map<String, dynamic> mapa = Map<String, dynamic>.from(mensagemBruta);

      if (mapa['type'] == 'customMessage' && mapa['data'] is Map) {
        final Map<String, dynamic> dadosEnvelope = Map<String, dynamic>.from(mapa['data'] as Map);
        final dynamic customData = dadosEnvelope['customData'];
        if (customData is Map) {
          final Map<String, dynamic> mapaCustom = Map<String, dynamic>.from(customData);
          if (mapaCustom['tipo'] != null) {
            return mapaCustom;
          }
        }
      }

      if (mapa['tipo'] != null) {
        return mapa;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Map<String, dynamic>? _decodificarMensagemParaMapa(String mensagem) {
    try {
      final dynamic mensagemDecodificada = jsonDecode(mensagem);
      if (mensagemDecodificada is Map) {
        return Map<String, dynamic>.from(mensagemDecodificada);
      }
    } catch (_) {
      // Ignora mensagens nao JSON.
    }

    return null;
  }

  String? _obterIdRequisicaoDaMensagemMapa(Map<String, dynamic>? mensagemMapa) {
    if (mensagemMapa == null) {
      return null;
    }

    final dynamic idRequisicao = mensagemMapa['idRequisicao'];
    if (idRequisicao == null) {
      return null;
    }

    final String idRequisicaoNormalizado = idRequisicao.toString().trim();
    if (idRequisicaoNormalizado.isEmpty) {
      return null;
    }

    return idRequisicaoNormalizado;
  }

  String? _obterIdRequisicaoDaMensagem(String mensagem) {
    final Map<String, dynamic>? mensagemMapa = _decodificarMensagemParaMapa(mensagem);
    return _obterIdRequisicaoDaMensagemMapa(mensagemMapa);
  }

  bool _mensagemExigeConfirmacaoEntrega(String mensagem) {
    final Map<String, dynamic>? mensagemMapa = _decodificarMensagemParaMapa(mensagem);
    if (mensagemMapa == null) {
      return false;
    }

    final bool possuiTipoImpressao = mensagemMapa['tipoImpressao'] != null;
    final bool possuiIdRequisicao = _obterIdRequisicaoDaMensagemMapa(mensagemMapa) != null;
    return possuiTipoImpressao && possuiIdRequisicao;
  }

  String? _extrairIdRequisicaoDaReferenciaImpressao(String? referenciaImpressaoOrigem) {
    final String referenciaNormalizada = (referenciaImpressaoOrigem ?? '').trim();
    if (referenciaNormalizada.isEmpty) {
      return null;
    }

    final List<String> partes = referenciaNormalizada.split('|');
    if (partes.isEmpty) {
      return null;
    }

    final String ultimoTrecho = partes.last.trim();
    if (ultimoTrecho.isEmpty || ultimoTrecho == '-') {
      return null;
    }

    return ultimoTrecho;
  }

  bool _idRequisicaoExpirou(String idRequisicao) {
    final String prefixoMicrossegundos = idRequisicao.split('_').first.trim();
    final int? microssegundos = int.tryParse(prefixoMicrossegundos);
    if (microssegundos == null || microssegundos <= 0) {
      return false;
    }

    final DateTime dataCriacao = DateTime.fromMicrosecondsSinceEpoch(microssegundos);
    return DateTime.now().difference(dataCriacao) > _tempoMaximoAguardandoConfirmacaoImpressao;
  }

  bool _enviarMensagemNoCanal(String mensagem) {
    if (channel == null || !connected) {
      return false;
    }

    try {
      final dynamic mensagemDecodificada = jsonDecode(mensagem);
      if (mensagemDecodificada is Map && mensagemDecodificada['tipo'] != null) {
        final String envelope = _serializarMensagemEnvelope(
          Map<String, dynamic>.from(mensagemDecodificada),
        );
        channel!.sink.add(envelope);
        return true;
      }
    } catch (_) {
      // Mensagem nao e JSON valido. Mantem envio bruto para compatibilidade.
    }

    try {
      channel!.sink.add(mensagem);
      return true;
    } catch (e, stackTrace) {
      log('Falha ao enviar mensagem no socket', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _removerMensagemPendenteEspecifica(String mensagem) async {
    try {
      final List<String> pendentes = await _carregarMensagensPendentes();
      if (!pendentes.contains(mensagem)) {
        return;
      }

      pendentes.remove(mensagem);
      await _salvarMensagensPendentes(pendentes);
    } catch (e, stackTrace) {
      log('Falha ao remover mensagem pendente especifica', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _removerMensagemPendentePorIdRequisicao(String idRequisicao) async {
    try {
      final List<String> pendentes = await _carregarMensagensPendentes();
      bool houveAlteracao = false;

      final List<String> filtradas = pendentes.where((String mensagemPendente) {
        final String? idRequisicaoMensagem = _obterIdRequisicaoDaMensagem(mensagemPendente);
        final bool manter = idRequisicaoMensagem == null || idRequisicaoMensagem != idRequisicao;
        if (!manter) {
          houveAlteracao = true;
        }

        return manter;
      }).toList();

      if (houveAlteracao) {
        await _salvarMensagensPendentes(filtradas);
      }
    } catch (e, stackTrace) {
      log('Falha ao remover mensagem pendente por idRequisicao', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _limparPendenciasExpiradas() async {
    try {
      final List<String> pendentes = await _carregarMensagensPendentes();
      bool houveAlteracao = false;

      final List<String> filtradas = pendentes.where((String mensagemPendente) {
        if (!_mensagemExigeConfirmacaoEntrega(mensagemPendente)) {
          return true;
        }

        final String? idRequisicao = _obterIdRequisicaoDaMensagem(mensagemPendente);
        if (idRequisicao == null) {
          return true;
        }

        final bool expirou = _idRequisicaoExpirou(idRequisicao);
        if (expirou) {
          houveAlteracao = true;
          log('Mensagem de impressao expirada removida da fila pendente. idRequisicao: $idRequisicao');
          return false;
        }

        return true;
      }).toList();

      if (houveAlteracao) {
        await _salvarMensagensPendentes(filtradas);
      }
    } catch (e, stackTrace) {
      log('Falha ao limpar pendencias expiradas', error: e, stackTrace: stackTrace);
    }
  }

  bool write(String message) {
    final bool exigeConfirmacaoEntrega = _mensagemExigeConfirmacaoEntrega(message);

    if (exigeConfirmacaoEntrega) {
      // Persistimos antes do envio para garantir ao menos uma tentativa apos falhas de rede.
      unawaited(_enfileirarMensagemPendente(message));
      unawaited(_limparPendenciasExpiradas());
    }

    if (channel == null || !connected) {
      if (!exigeConfirmacaoEntrega) {
        unawaited(_enfileirarMensagemPendente(message));
      }
      return false;
    }

    final bool enviado = _enviarMensagemNoCanal(message);
    if (enviado) {
      if (!exigeConfirmacaoEntrega) {
        unawaited(_removerMensagemPendenteEspecifica(message));
      }

      return true;
    }

    unawaited(_enfileirarMensagemPendente(message));
    return false;
  }

  Future<List<String>> _carregarMensagensPendentes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_chaveMensagensPendentes) ?? <String>[];
  }

  Future<void> _salvarMensagensPendentes(List<String> mensagens) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (mensagens.isEmpty) {
      await prefs.remove(_chaveMensagensPendentes);
      return;
    }

    await prefs.setStringList(_chaveMensagensPendentes, mensagens);
  }

  Future<void> _enfileirarMensagemPendente(String mensagem) async {
    try {
      final List<String> pendentes = await _carregarMensagensPendentes();

      if (!pendentes.contains(mensagem)) {
        pendentes.add(mensagem);
      }

      if (pendentes.length > _maximoMensagensPendentes) {
        final int quantidadeParaRemover = pendentes.length - _maximoMensagensPendentes;
        pendentes.removeRange(0, quantidadeParaRemover);
      }

      await _salvarMensagensPendentes(pendentes);
    } catch (e, stackTrace) {
      log('Falha ao enfileirar mensagem pendente', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _reenviarMensagensPendentes() async {
    if (_reenviandoMensagensPendentes) {
      return;
    }

    if (channel == null || !connected) {
      return;
    }

    _reenviandoMensagensPendentes = true;

    try {
      await _limparPendenciasExpiradas();

      final List<String> pendentes = await _carregarMensagensPendentes();
      if (pendentes.isEmpty) {
        return;
      }

      final List<String> restantes = <String>[];

      for (int indice = 0; indice < pendentes.length; indice++) {
        final String mensagem = pendentes[indice];
        final bool enviado = _enviarMensagemNoCanal(mensagem);

        if (!enviado) {
          restantes.addAll(pendentes.sublist(indice));
          break;
        }

        if (_mensagemExigeConfirmacaoEntrega(mensagem)) {
          // Mantem na fila ate receber confirmacao explicita (ou expirar por tempo).
          restantes.add(mensagem);
        }
      }

      await _salvarMensagensPendentes(restantes);
    } catch (e, stackTrace) {
      log('Falha ao reenviar mensagens pendentes', error: e, stackTrace: stackTrace);
    } finally {
      _reenviandoMensagensPendentes = false;
    }
  }

  void onData(dynamic data) async {
    try {
      final Map<String, dynamic>? mensagem = _desserializarMensagem(data);
      if (mensagem == null || mensagem['tipo'] == null) {
        return;
      }

      final ModeloRetornoSocket dados = ModeloRetornoSocket.fromMap(mensagem);

      if (dados.tipo == 'RespostaImpressao' && dados.tipoResposta == 'impressao') {
        final String? idRequisicao = (dados.idRequisicao ?? _extrairIdRequisicaoDaReferenciaImpressao(dados.referenciaImpressaoOrigem))?.trim();

        if (idRequisicao != null && idRequisicao.isNotEmpty) {
          if (dados.statusResposta == 'sucesso') {
            await _removerMensagemPendentePorIdRequisicao(idRequisicao);
          } else if (dados.statusResposta == 'erro') {
            log('Servidor respondeu erro para impressao idRequisicao=$idRequisicao: ${dados.mensagemErro ?? 'Sem detalhes'}');
          }
        }

        await _limparPendenciasExpiradas();
        notifyListeners();
        return;
      }

      if (dados.tipo == 'PC') {
        nomedopc = dados.nomedopc ?? '';
        notifyListeners();
        return;
      }

      AtualizacaoDeTela().call(dados);
      notifyListeners();
    } catch (e, stackTrace) {
      log('erro em onData', error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _temporizadorReconexao?.cancel();
    super.dispose();
  }
}
