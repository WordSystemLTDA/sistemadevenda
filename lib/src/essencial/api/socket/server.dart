import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Server extends ChangeNotifier {
  final FilaImpressao filaImpressao;
  Timer? _avisoImpressao;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>?
      _avisoImpressaoVisivel;
  bool _descartado = false;
  Timer? _retentativaImpressao;
  Timer? _proximoLoteImpressao;
  final Map<String, DateTime> _consultasImpressao = {};
  final Map<String, int> _quantidadeConsultas = {};
  DateTime? _ultimoAvisoImpressao;
  final DateTime Function() _agora;

  Server({FilaImpressao? filaImpressao, DateTime Function()? agora})
      : _agora = agora ?? DateTime.now,
        filaImpressao = filaImpressao ?? FilaImpressao() {
    this.filaImpressao.addListener(_atualizarFilaImpressao);
  }

  void _atualizarFilaImpressao() {
    if (filaImpressao.itens.every((item) =>
        item.estado == EstadoImpressao.pausada ||
        item.estado == EstadoImpressao.aguardandoPedido)) {
      _retentativaImpressao?.cancel();
      _retentativaImpressao = null;
      _consultasImpressao.clear();
      _quantidadeConsultas.clear();
      _avisoImpressaoVisivel?.close();
      _avisoImpressaoVisivel = null;
    } else if (!_descartado && !_desconexaoIntencional) {
      _retentativaImpressao ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(processarImpressoesPendentes()),
      );
    }
    if (!_descartado) notifyListeners();
  }

  void abrirPendenciasImpressao(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PendenciasImpressao(
              fila: filaImpressao,
              reenviar: (id) async {
                _quantidadeConsultas.remove(id);
                _consultasImpressao.remove(id);
                await filaImpressao.autorizarReenvio(id, manual: true);
                await _reenviarMensagensPendentes();
              },
              limpar: limparImpressoes,
              pertenceAoEscopo: _pertenceAConexao,
            )));
  }

  void Function(String tipo)? aoAtualizarDados;

  void _avisarImpressaoPendente() {
    if (_descartado || filaImpressao.itens.isEmpty) return;
    if (_ultimoAvisoImpressao != null &&
        _agora().difference(_ultimoAvisoImpressao!) <
            const Duration(minutes: 1)) {
      return;
    }
    final context = navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    _ultimoAvisoImpressao = _agora();
    _avisoImpressaoVisivel?.close();
    _avisoImpressaoVisivel = messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 5),
      content: const Text('Impressão pendente. O atendimento pode continuar.'),
      action: SnackBarAction(
          label: 'Conferir',
          onPressed: () => abrirPendenciasImpressao(context)),
    ));
  }

  Future<void> enviarImpressoes(List<String> mensagens) async {
    if (mensagens.isEmpty) return;
    await filaImpressao.registrar(mensagens,
        servidor: hostname.isEmpty ? '' : '$hostname:$port');
    // Escrever no socket nao aguarda a impressora. Conectar fica em segundo plano.
    if (connected) {
      await _reenviarMensagensPendentes();
    }
    if (!connected) _avisarImpressaoPendente();
  }

  Future<void> prepararImpressoes(List<String> mensagens) =>
      filaImpressao.registrar(mensagens,
          servidor: hostname.isEmpty ? '' : '$hostname:$port',
          estado: EstadoImpressao.aguardandoPedido);

  Future<void> limparImpressoes(List<String> ids) async {
    final cancelar = <String>{};
    for (final id in ids) {
      final item =
          filaImpressao.itens.where((item) => item.id == id).firstOrNull;
      if (item == null ||
          !_pertenceAConexao(item) ||
          item.estado == EstadoImpressao.aguardandoPedido) {
        continue;
      }
      cancelar.add(id);
      _consultasImpressao.remove(id);
    }
    await filaImpressao.cancelarLote(cancelar);
    unawaited(processarImpressoesPendentes());
  }

  void avisarFalhaImpressao(Object erro) {
    log('Falha ao salvar impressão; atendimento liberado', error: erro);
    final context = navigatorKey?.currentContext;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
      content: Text('Impressão não salva. Confira o pedido com a cozinha.'),
      showCloseIcon: true,
    ));
  }

  Future<void> processarImpressoesPendentes(
      {bool reconectarAgora = false}) async {
    if (_descartado || _desconexaoIntencional) return;
    try {
      await filaImpressao.carregar();
      if (!connected) {
        if (reconectarAgora) {
          final conexao = await ConfigSharedPreferences().getConexao();
          if (conexao != null && !_descartado && !_desconexaoIntencional) {
            await connect(conexao.servidor, conexao.porta);
          }
        }
      }
      if (!connected) {
        if (_conexaoEmAndamento == null && _temporizadorReconexao == null) {
          if (hostname.isNotEmpty && port > 0) {
            _agendarReconexao();
          } else {
            final conexao = await ConfigSharedPreferences().getConexao();
            if (conexao != null && !_descartado && !_desconexaoIntencional) {
              await connect(conexao.servidor, conexao.porta);
            }
          }
        }
        return;
      }
      await _reenviarMensagensPendentes();
    } catch (erro, stack) {
      log('Falha na recuperacao automatica da impressao',
          error: erro, stackTrace: stack);
      _avisarImpressaoPendente();
    }
  }

  bool _pertenceAConexao(ImpressaoPendente item) {
    if (item.servidor.isNotEmpty && item.servidor != '$hostname:$port') {
      return false;
    }
    final empresa = item.dados['idEmpresa']?.toString() ?? '';
    return empresa.isEmpty || empresa == usuarioProvedor.usuario?.empresa;
  }

  Future<void> _enviarImpressoesAguardando() async {
    await filaImpressao.carregar();
    var enviados = 0;
    // Envios novos nao aguardam as consultas dos pedidos anteriores.
    final itens = filaImpressao.itens;
    for (final item in [
      ...itens.where((item) => item.estado == EstadoImpressao.aguardandoEnvio),
      ...itens.where((item) => item.estado != EstadoImpressao.aguardandoEnvio),
    ]) {
      if (enviados >= 3) break;
      if (!connected || channel == null) break;
      if (!_pertenceAConexao(item)) continue;
      if (item.estado == EstadoImpressao.aguardandoPedido ||
          item.estado == EstadoImpressao.pausada) {
        continue;
      }
      if (item.estado == EstadoImpressao.cancelamentoPendente) {
        final ultima = _consultasImpressao[item.id];
        if (ultima != null &&
            _agora().difference(ultima) < const Duration(minutes: 1)) {
          continue;
        }
        _consultasImpressao[item.id] = _agora();
        _enviarMensagemNoCanal(jsonEncode({
          'tipo': 'CancelarImpressao',
          'protocoloImpressao': 2,
          'idRequisicao': item.id,
          'idEmpresa': item.dados['idEmpresa'],
          'nomedopc': item.dados['nomedopc'],
        }));
        enviados++;
        continue;
      }
      if (item.estado != EstadoImpressao.aguardandoEnvio) {
        if (item.dados['tipoImpressao']?.toString() != '1') continue;
        final ultima = _consultasImpressao[item.id] ?? item.ultimaTentativa;
        final intervalo = !_consultasImpressao.containsKey(item.id)
            ? const Duration(seconds: 15)
            : const Duration(minutes: 1);
        if (ultima != null && _agora().difference(ultima) < intervalo) {
          continue;
        }
        _consultasImpressao[item.id] = _agora();
        final consultas = _quantidadeConsultas
            .update(item.id, (valor) => valor + 1, ifAbsent: () => 1);
        if (consultas > 3) {
          await filaImpressao.pausar(item.id,
              'Recuperação pausada. Confira a cozinha ou limpe a pendência.');
          continue;
        }
        // Consulta o mesmo ID antes de repetir: o ACK pode ter se perdido.
        final enviada = _enviarMensagemNoCanal(jsonEncode({
          'tipo': 'ConsultarImpressao',
          'protocoloImpressao': 2,
          'idRequisicao': item.id,
          'idEmpresa': item.dados['idEmpresa'],
          'nomedopc': item.dados['nomedopc'],
        }));
        if (!enviada) {
          _processarQuedaConexao();
          break;
        }
        enviados++;
        continue;
      }
      if (!await filaImpressao.iniciarEnvio(item.id, agora: _agora())) continue;
      enviados++;
      if (!_enviarMensagemNoCanal(
          jsonEncode({...item.dados, 'protocoloImpressao': 2}))) {
        await filaImpressao.registrarErro(item.id,
            'Conexao interrompida. Aguardando recuperacao automatica.');
        _processarQuedaConexao();
        break;
      }
    }
    if (filaImpressao.itens.isNotEmpty) {
      _avisoImpressao ??= Timer(const Duration(seconds: 20), () {
        _avisoImpressao = null;
        _avisarImpressaoPendente();
      });
    }
  }

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
  HttpClient? _clienteConexao;
  int _geracaoConexao = 0;
  bool _reenviandoMensagensPendentes = false;
  bool _novoEnvioSolicitado = false;

  static const Duration _timeoutConexao = Duration(seconds: 8);
  static const Duration _timeoutFechamento = Duration(seconds: 1);
  static const int _maximoMensagensPendentes = 200;
  static const String _chaveMensagensPendentes =
      'fila_mensagens_socket_pendentes';

  Future<bool> connect(String ip, String porta) async {
    if (_descartado) return false;
    ip = ip.trim();
    final portaConvertida = int.tryParse(porta.trim());
    if (ip.isEmpty ||
        portaConvertida == null ||
        portaConvertida <= 0 ||
        portaConvertida > 65535) {
      return false;
    }
    unawaited(filaImpressao.carregar().then((_) {
      if (!_descartado && filaImpressao.itens.isNotEmpty) {
        _avisoImpressao ??= Timer(const Duration(seconds: 20), () {
          _avisoImpressao = null;
          _avisarImpressaoPendente();
        });
      }
    }).catchError((Object erro, StackTrace stack) {
      log('Falha ao recuperar impressoes pendentes',
          error: erro, stackTrace: stack);
    }));
    if (_conexaoEmAndamento != null) {
      if (hostname == ip && port == portaConvertida) {
        return _conexaoEmAndamento!.future;
      }
      _cancelarTentativaConexao();
    }
    if (connected &&
        channel != null &&
        hostname == ip &&
        port == portaConvertida) {
      return true;
    }

    final Completer<bool> completer = Completer<bool>();
    _conexaoEmAndamento = completer;
    final geracao = ++_geracaoConexao;
    HttpClient? cliente;

    try {
      _desconexaoIntencional = false;
      _atualizarFilaImpressao();
      hostname = ip;
      port = portaConvertida;
      _temporizadorReconexao?.cancel();
      _temporizadorReconexao = null;

      await _encerrarCanalAtual();
      if (!_tentativaConexaoAtual(geracao)) return false;

      cliente = HttpClient()..connectionTimeout = _timeoutConexao;
      _clienteConexao = cliente;
      final WebSocket socket = await WebSocket.connect(
        Uri(scheme: 'ws', host: ip, port: portaConvertida).toString(),
        customClient: cliente,
      ).timeout(_timeoutConexao, onTimeout: () {
        cliente?.close(force: true);
        throw TimeoutException(
            'O servidor local nao respondeu.', _timeoutConexao);
      });
      if (!_tentativaConexaoAtual(geracao)) {
        unawaited(socket.close());
        return false;
      }
      socket.pingInterval = const Duration(seconds: 5);

      final WebSocketChannel canalConexao = IOWebSocketChannel(socket);
      channel = canalConexao;
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

      await canalConexao.ready.timeout(_timeoutConexao);
      if (!_tentativaConexaoAtual(geracao) ||
          !identical(channel, canalConexao)) {
        return false;
      }
      connected = true;
      _consultasImpressao.clear();
      _tentativaReconexao = 0;
      notifyListeners();

      unawaited(_enviarHandshakeRede());
      unawaited(_reenviarMensagensPendentes());

      if (!completer.isCompleted) completer.complete(true);
      return true;
    } catch (e, stackTrace) {
      log('Excecao ao conectar', error: e, stackTrace: stackTrace);
      if (_tentativaConexaoAtual(geracao)) _processarQuedaConexao();
      return false;
    } finally {
      cliente?.close(force: true);
      if (identical(_clienteConexao, cliente)) _clienteConexao = null;
      if (!completer.isCompleted) completer.complete(false);
      if (identical(_conexaoEmAndamento, completer)) _conexaoEmAndamento = null;
    }
  }

  bool _tentativaConexaoAtual(int geracao) =>
      !_descartado && !_desconexaoIntencional && geracao == _geracaoConexao;

  void _cancelarTentativaConexao() {
    _geracaoConexao++;
    _clienteConexao?.close(force: true);
    _clienteConexao = null;
    final tentativa = _conexaoEmAndamento;
    _conexaoEmAndamento = null;
    if (tentativa != null && !tentativa.isCompleted) tentativa.complete(false);
  }

  Future<void> disconnect() async {
    _desconexaoIntencional = true;
    _cancelarTentativaConexao();
    _tentativaReconexao = 0;
    _temporizadorReconexao?.cancel();
    _temporizadorReconexao = null;
    _retentativaImpressao?.cancel();
    _retentativaImpressao = null;
    await _encerrarCanalAtual();
  }

  Future<void> _encerrarCanalAtual() async {
    final WebSocketChannel? canalAtual = channel;
    final bool haviaConexao = channel != null || connected;

    channel = null;
    connected = false;

    if (haviaConexao && !_descartado) {
      notifyListeners();
    }

    if (canalAtual != null) {
      try {
        await canalAtual.sink.close().timeout(_timeoutFechamento);
      } catch (_) {
        // Ignora erro no fechamento do canal.
      }
    }
  }

  void _processarQuedaConexao() {
    final bool haviaConexao = channel != null || connected;
    if (haviaConexao) unawaited(_encerrarCanalAtual());

    if (_desconexaoIntencional || _descartado) {
      log('Reconexao ignorada: desconexao intencional.');
      return;
    }

    _agendarReconexao();
  }

  void _agendarReconexao() {
    if (_desconexaoIntencional || _descartado) {
      return;
    }

    if (_temporizadorReconexao != null) {
      return;
    }

    final Duration atraso = _calcularAtrasoReconexao();
    _tentativaReconexao = (_tentativaReconexao + 1).clamp(0, 4);

    log('Tentando reconectar em ${atraso.inSeconds} segundos...');
    _temporizadorReconexao = Timer(atraso, () async {
      _temporizadorReconexao = null;

      if (_desconexaoIntencional || _descartado) {
        return;
      }

      final ConfigSharedPreferences config = ConfigSharedPreferences();
      if (hostname.isNotEmpty && port > 0) {
        await connect(hostname, '$port');
        return;
      }
      final conexao = await config.getConexao();

      if (conexao == null ||
          conexao.servidor.isEmpty ||
          conexao.porta.isEmpty) {
        _mostrarAvisoFalhaReconexao(
            'Dados de conexao nao encontrados para reconectar.');
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
          content: Text(mensagem ??
              'Falha ao reconectar. Verifique o servidor e a rede.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
          showCloseIcon: true,
        ),
      );
  }

  Future<void> _enviarHandshakeRede() async {
    final canal = channel;
    final String nomeDispositivo = await _obterNomeDispositivo();
    final String? ip = await _obterIpLocal();
    if (_descartado || !connected || !identical(channel, canal)) return;

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

    final String fallbackAmbiente = (Platform.environment['COMPUTERNAME'] ??
            Platform.environment['HOSTNAME'] ??
            Platform.environment['USER'] ??
            '')
        .trim();
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

      final Map<String, dynamic> mapa =
          Map<String, dynamic>.from(mensagemBruta);

      if (mapa['type'] == 'customMessage' && mapa['data'] is Map) {
        final Map<String, dynamic> dadosEnvelope =
            Map<String, dynamic>.from(mapa['data'] as Map);
        final dynamic customData = dadosEnvelope['customData'];
        if (customData is Map) {
          final Map<String, dynamic> mapaCustom =
              Map<String, dynamic>.from(customData);
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

  bool _mensagemExigeConfirmacaoEntrega(String mensagem) {
    final Map<String, dynamic>? mensagemMapa =
        _decodificarMensagemParaMapa(mensagem);
    if (mensagemMapa == null) {
      return false;
    }

    final bool possuiTipoImpressao = mensagemMapa['tipoImpressao'] != null;
    final bool possuiIdRequisicao =
        _obterIdRequisicaoDaMensagemMapa(mensagemMapa) != null;
    return possuiTipoImpressao && possuiIdRequisicao;
  }

  String? _extrairIdRequisicaoDaReferenciaImpressao(
      String? referenciaImpressaoOrigem) {
    final String referenciaNormalizada =
        (referenciaImpressaoOrigem ?? '').trim();
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

  bool _enviarMensagemNoCanal(String mensagem) {
    if (channel == null || !connected) {
      return false;
    }

    var mensagemParaEnviar = mensagem;
    try {
      final dynamic mensagemDecodificada = jsonDecode(mensagem);
      if (mensagemDecodificada is Map && mensagemDecodificada['tipo'] != null) {
        mensagemParaEnviar = _serializarMensagemEnvelope(
          Map<String, dynamic>.from(mensagemDecodificada),
        );
      }
    } catch (_) {
      // Mensagem nao e JSON valido. Mantem envio bruto para compatibilidade.
    }

    try {
      channel!.sink.add(mensagemParaEnviar);
      return true;
    } catch (e, stackTrace) {
      log('Falha ao enviar mensagem no socket',
          error: e, stackTrace: stackTrace);
      return false;
    }
  }

  bool write(String message) {
    if (_mensagemExigeConfirmacaoEntrega(message)) {
      unawaited(enviarImpressoes([message])
          .catchError((Object erro, StackTrace stack) {
        log('Falha ao registrar impressao', error: erro, stackTrace: stack);
        final context = navigatorKey?.currentContext;
        if (context != null && context.mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            duration: Duration(seconds: 5),
            content: Text(
                'Falha ao salvar a impressao. Confira o pedido com a cozinha antes de sair.'),
          ));
        }
      }));
      return connected;
    }
    final enviado = _enviarMensagemNoCanal(message);
    if (!enviado) unawaited(_enfileirarMensagemPendente(message));
    return enviado;
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
      await filaImpressao.carregar();
      final List<String> pendentes = await _carregarMensagensPendentes();

      if (!pendentes.contains(mensagem)) {
        pendentes.add(mensagem);
      }

      if (pendentes.length > _maximoMensagensPendentes) {
        final int quantidadeParaRemover =
            pendentes.length - _maximoMensagensPendentes;
        pendentes.removeRange(0, quantidadeParaRemover);
      }

      await _salvarMensagensPendentes(pendentes);
    } catch (e, stackTrace) {
      log('Falha ao enfileirar mensagem pendente',
          error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _reenviarMensagensPendentes() async {
    try {
      await filaImpressao.carregar();
    } catch (erro, stack) {
      log('Falha ao recuperar a fila para envio',
          error: erro, stackTrace: stack);
      return;
    }
    if (_reenviandoMensagensPendentes) {
      _novoEnvioSolicitado = true;
      return;
    }
    if (channel == null || !connected) return;

    _reenviandoMensagensPendentes = true;
    _novoEnvioSolicitado = false;
    var loteConcluido = false;

    try {
      await _enviarImpressoesAguardando();
      loteConcluido = true;

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
      }

      await _salvarMensagensPendentes(restantes);
    } catch (e, stackTrace) {
      log('Falha ao reenviar mensagens pendentes',
          error: e, stackTrace: stackTrace);
      _novoEnvioSolicitado = false;
      loteConcluido = false;
      _avisarImpressaoPendente();
    } finally {
      _reenviandoMensagensPendentes = false;
      if (loteConcluido &&
          !_descartado &&
          connected &&
          (_novoEnvioSolicitado ||
              filaImpressao.itens.any((item) =>
                  item.estado == EstadoImpressao.aguardandoEnvio &&
                  _pertenceAConexao(item)))) {
        _proximoLoteImpressao ??= Timer(const Duration(milliseconds: 50), () {
          _proximoLoteImpressao = null;
          unawaited(_reenviarMensagensPendentes());
        });
      }
    }
  }

  Future<void> onData(dynamic data) async {
    try {
      final Map<String, dynamic>? mensagem = _desserializarMensagem(data);
      if (mensagem == null || mensagem['tipo'] == null) {
        return;
      }

      // ACKs sao lidos sem desserializar produtos: uma resposta nao precisa de
      // todos os campos obrigatorios de um produto para confirmar a impressao.
      if (mensagem['tipo'] == 'RespostaImpressao' &&
          mensagem['tipoResposta'] == 'impressao') {
        final String? idRequisicao = (mensagem['idRequisicao']?.toString() ??
                _extrairIdRequisicaoDaReferenciaImpressao(
                    mensagem['referenciaImpressaoOrigem']?.toString()))
            ?.trim();

        if (idRequisicao != null && idRequisicao.isNotEmpty) {
          await filaImpressao.carregar();
          final item = filaImpressao.itens
              .where((e) => e.id == idRequisicao)
              .firstOrNull;
          if (item == null ||
              !_pertenceAConexao(item) ||
              item.estado == EstadoImpressao.aguardandoPedido) {
            return;
          }
          final empresaResposta = mensagem['idEmpresa']?.toString() ?? '';
          if (empresaResposta.isNotEmpty &&
              empresaResposta != item.dados['idEmpresa']?.toString()) {
            return;
          }
          final protocoloConfirmado = mensagem['protocoloImpressao'] == 2 ||
              item.dados['tipoImpressao']?.toString() != '1';
          if ((mensagem['statusResposta'] == 'sucesso' ||
                  mensagem['statusResposta'] == 'cancelada' ||
                  mensagem['statusResposta'] == 'dispensada') &&
              protocoloConfirmado) {
            await filaImpressao.confirmar(idRequisicao,
                cancelada: mensagem['statusResposta'] == 'cancelada');
            _consultasImpressao.remove(idRequisicao);
            _quantidadeConsultas.remove(idRequisicao);
          } else if (item.estado == EstadoImpressao.cancelamentoPendente) {
            return;
          } else if (mensagem['statusResposta'] == 'pausada') {
            await filaImpressao.pausar(
                idRequisicao,
                mensagem['mensagemErro']?.toString() ??
                    'Impressão pausada no servidor.');
          } else if (mensagem['statusResposta'] == 'naoEncontrada' &&
              protocoloConfirmado) {
            if (item.dados['protocoloImpressao'] == 2 && item.tentativas < 3) {
              await filaImpressao.autorizarReenvio(idRequisicao);
              unawaited(processarImpressoesPendentes());
            } else {
              await filaImpressao.registrarErro(idRequisicao,
                  'Impressao anterior a atualizacao. Confira com a cozinha antes de reenviar.');
            }
          } else if (mensagem['statusResposta'] == 'erro') {
            await filaImpressao.registrarErro(
                idRequisicao,
                mensagem['mensagemErro']?.toString() ??
                    'Falha no servidor de impressao.');
            _avisarImpressaoPendente();
          } else if (mensagem['statusResposta'] == 'sucesso' &&
              !protocoloConfirmado) {
            await filaImpressao.registrarErro(idRequisicao,
                'Servidor sem confirmacao de execucao. Atualize o servidor de impressao.');
          }
        }

        if (filaImpressao.itens.isEmpty) {
          _avisoImpressao?.cancel();
          _avisoImpressao = null;
        }
        if (!_descartado) notifyListeners();
        return;
      }

      final ModeloRetornoSocket dados = ModeloRetornoSocket.fromMap(mensagem);

      if (dados.tipo == 'PC') {
        nomedopc = dados.nomedopc ?? '';
        notifyListeners();
        return;
      }

      aoAtualizarDados?.call(dados.tipo);
      AtualizacaoDeTela().call(dados);
      notifyListeners();
    } catch (e, stackTrace) {
      log('erro em onData', error: e, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _descartado = true;
    _proximoLoteImpressao?.cancel();
    _cancelarTentativaConexao();
    unawaited(_encerrarCanalAtual());
    _temporizadorReconexao?.cancel();
    _retentativaImpressao?.cancel();
    _avisoImpressao?.cancel();
    filaImpressao.removeListener(_atualizarFilaImpressao);
    filaImpressao.dispose();
    super.dispose();
  }
}
