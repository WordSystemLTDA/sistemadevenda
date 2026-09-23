import 'dart:convert';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EstadoImpressao {
  aguardandoPedido,
  aguardandoEnvio,
  semConfirmacao,
  erro,
  pausada,
  cancelamentoPendente
}

class ImpressaoPendente {
  final String mensagem;
  final EstadoImpressao estado;
  final String? erro;
  final String servidor;
  final int tentativas;
  final DateTime? ultimaTentativa;

  ImpressaoPendente(this.mensagem,
      {this.estado = EstadoImpressao.aguardandoEnvio,
      this.erro,
      this.servidor = '',
      this.tentativas = 0,
      this.ultimaTentativa});

  static Map<String, dynamic> _decodificarMensagem(String mensagem) {
    try {
      final dados = jsonDecode(mensagem);
      if (dados is Map) {
        return Map.unmodifiable({
          for (final entrada in dados.entries)
            if (entrada.key != null) entrada.key.toString(): entrada.value,
        });
      }
    } catch (_) {
      return const {};
    }
    return const {};
  }

  static EstadoImpressao _estado(String? nome) {
    for (final estado in EstadoImpressao.values) {
      if (estado.name == nome) return estado;
    }
    return EstadoImpressao.erro;
  }

  late final Map<String, dynamic> dados = _decodificarMensagem(mensagem);
  late final String id = dados['idRequisicao']?.toString() ?? '';

  Map<String, dynamic> toMap() => {
        'mensagem': mensagem,
        'estado': estado.name,
        'erro': erro,
        'servidor': servidor,
        'tentativas': tentativas,
        'ultimaTentativa': ultimaTentativa?.toIso8601String(),
      };

  factory ImpressaoPendente.fromMap(Map<String, dynamic> map) =>
      ImpressaoPendente(map['mensagem']?.toString() ?? '{}',
          estado: _estado(map['estado']?.toString()),
          servidor: map['servidor'] as String? ?? '',
          tentativas: map['tentativas'] as int? ?? 0,
          ultimaTentativa:
              DateTime.tryParse(map['ultimaTentativa'] as String? ?? ''),
          erro: map['erro'] as String?);
}

class FilaImpressao extends ChangeNotifier {
  static const chave = 'fila_impressao_confirmada_v1';
  static const chaveLegada = 'fila_mensagens_socket_pendentes';
  static const chaveConfirmadas = 'impressoes_confirmadas_v1';
  static const _chaveCanceladas = 'impressoes_canceladas_v1';
  Future<void> _operacao = Future.value();
  bool _carregada = false;
  bool _descartada = false;
  List<ImpressaoPendente> _itens = [];

  List<ImpressaoPendente> get itens => List.unmodifiable(_itens);

  // Serializa leitura, alteracao e gravacao, inclusive quando o ACK chega no envio.
  Future<T> _executar<T>(Future<T> Function() acao) {
    final resultado = _operacao.then((_) => acao());
    _operacao =
        resultado.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return resultado;
  }

  void _notificar() {
    if (!_descartada) notifyListeners();
  }

  Future<void> _salvar(List<ImpressaoPendente> itens) async {
    final banco = BancoLocal.instancia;
    if (banco != null) {
      await banco.gravar(
          chave, jsonEncode(itens.map((e) => e.toMap()).toList()));
      _itens = itens;
      _notificar();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    var salvo = false;
    try {
      salvo = await prefs.setString(
          chave, jsonEncode(itens.map((e) => e.toMap()).toList()));
    } finally {
      if (!salvo) await prefs.reload();
    }
    if (!salvo) {
      throw StateError('Nao foi possivel salvar a fila de impressao.');
    }
    _itens = itens;
    _notificar();
  }

  Future<void> _carregar() async {
    if (_carregada) return;
    final prefs = await SharedPreferences.getInstance();
    final banco = BancoLocal.instancia;
    if (banco != null) await banco.migrarPreferencia(chave, chave);
    final salvo =
        banco == null ? prefs.getString(chave) : await banco.ler(chave);
    final finalizadas = {
      ...?prefs.getStringList(chaveConfirmadas),
      ...?prefs.getStringList(_chaveCanceladas),
    };
    Future<bool> jaFinalizada(String id) async =>
        finalizadas.contains(id) ||
        await banco?.ler('impressaoConfirmada:$id') != null;
    final itens = <ImpressaoPendente>[];
    if (salvo != null) {
      try {
        final salvos = jsonDecode(salvo);
        if (salvos is! List) throw const FormatException('Fila invalida');
        for (final itemSalvo in salvos) {
          if (itemSalvo is! Map) {
            throw const FormatException('Registro invalido');
          }
          var item =
              ImpressaoPendente.fromMap(Map<String, dynamic>.from(itemSalvo));
          if (item.id.trim().isEmpty) {
            throw const FormatException('Impressao sem ID');
          }
          if (await jaFinalizada(item.id)) continue;
          if (item.estado == EstadoImpressao.pausada &&
              item.erro ==
                  'Recuperação pausada. Confira a cozinha ou limpe a pendência.') {
            // Reativa apenas consultas; pausas do spooler permanecem manuais.
            item = ImpressaoPendente(item.mensagem,
                estado: EstadoImpressao.semConfirmacao,
                servidor: item.servidor,
                tentativas: item.tentativas,
                ultimaTentativa: item.ultimaTentativa);
          }
          itens.add(item);
        }
      } catch (_) {
        // Nunca apagar comprovantes ao falhar a leitura. Conserve os dados
        // originais para recuperacao e bloqueie sobrescrita por uma fila vazia.
        throw StateError(
            'Nao foi possivel ler a fila de impressao. Os dados foram preservados para recuperacao.');
      }
    }
    final antigas = prefs.getStringList(chaveLegada) ?? [];
    final outras = <String>[];
    for (final mensagem in antigas) {
      Map<String, dynamic>? dados;
      try {
        dados = jsonDecode(mensagem) as Map<String, dynamic>;
      } catch (_) {
        outras.add(mensagem);
        continue;
      }
      if (dados['tipoImpressao'] == null || dados['idRequisicao'] == null) {
        outras.add(mensagem);
      } else if (!itens.any((e) => e.id == dados!['idRequisicao'].toString())) {
        if (await jaFinalizada(dados['idRequisicao'].toString())) continue;
        // A fila antiga nao distinguia mensagens enviadas das ainda nao enviadas.
        itens.add(ImpressaoPendente(mensagem,
            estado: EstadoImpressao.semConfirmacao));
      }
    }
    if (outras.length != antigas.length) {
      await _salvar(itens);
      if (!await prefs.setStringList(chaveLegada, outras)) {
        throw StateError('Nao foi possivel migrar a fila de impressao.');
      }
    }
    _itens = itens;
    _carregada = true;
    _notificar();
  }

  Future<void> carregar() => _executar(_carregar);

  Future<void> registrar(List<String> mensagens,
          {String servidor = '',
          EstadoImpressao estado = EstadoImpressao.aguardandoEnvio}) =>
      _executar(() async {
        await _carregar();
        final proximos = [..._itens];
        final prefs = await SharedPreferences.getInstance();
        final finalizadas = {
          ...?prefs.getStringList(chaveConfirmadas),
          ...?prefs.getStringList(_chaveCanceladas),
        };
        for (final mensagem in mensagens) {
          final item =
              ImpressaoPendente(mensagem, servidor: servidor, estado: estado);
          if (item.dados['idRequisicao'] == null || item.id.trim().isEmpty) {
            throw ArgumentError('Impressao sem identificador.');
          }
          if (finalizadas.contains(item.id)) continue;
          if (await BancoLocal.instancia
                  ?.ler('impressaoConfirmada:${item.id}') !=
              null) {
            continue;
          }
          final index = proximos.indexWhere((e) => e.id == item.id);
          if (index < 0) {
            proximos.add(item);
          } else if (proximos[index].estado ==
                  EstadoImpressao.aguardandoPedido &&
              estado == EstadoImpressao.aguardandoEnvio) {
            proximos[index] = item;
          }
        }
        await _salvar(proximos);
      });

  Future<void> cancelarPreparacao(List<String> mensagens) =>
      _executar(() async {
        await _carregar();
        final ids = mensagens.map((e) => ImpressaoPendente(e).id).toSet();
        await _salvar(_itens
            .where((e) =>
                !ids.contains(e.id) ||
                e.estado != EstadoImpressao.aguardandoPedido)
            .toList());
      });

  Future<bool> iniciarEnvio(String id, {DateTime? agora}) =>
      _executar(() async {
        await _carregar();
        final index = _itens.indexWhere((e) => e.id == id);
        if (index < 0 ||
            _itens[index].estado != EstadoImpressao.aguardandoEnvio) {
          return false;
        }
        final proximos = [..._itens];
        // Marca antes de escrever no socket: uma queda deixa o resultado incerto,
        // nao autoriza repetir um comprovante que pode ja ter chegado a cozinha.
        final dados = proximos[index].dados;
        final mensagem = dados['tipoImpressao']?.toString() == '1'
            ? jsonEncode({...dados, 'protocoloImpressao': 2})
            : proximos[index].mensagem;
        proximos[index] = ImpressaoPendente(mensagem,
            servidor: proximos[index].servidor,
            tentativas: proximos[index].tentativas + 1,
            ultimaTentativa: agora ?? DateTime.now(),
            estado: EstadoImpressao.semConfirmacao);
        await _salvar(proximos);
        return true;
      });

  Future<void> confirmar(String id, {bool cancelada = false}) =>
      _executar(() async {
        await _carregar();
        if (!_itens.any((e) => e.id == id)) return;
        final banco = BancoLocal.instancia;
        if (banco != null) {
          final proximos = _itens.where((e) => e.id != id).toList();
          await banco.db.transaction((tx) async {
            await BancoLocal.gravarDocumento(
                tx, 'impressaoConfirmada:$id', 'true');
            await BancoLocal.gravarDocumento(
                tx, chave, jsonEncode(proximos.map((e) => e.toMap()).toList()));
          });
          _itens = proximos;
          _notificar();
          return;
        }
        // O fallback tambem conserva o recibo do ACK. Se o app fechar entre
        // gravar o recibo e remover a fila, a proxima leitura ignora esse ID.
        final prefs = await SharedPreferences.getInstance();
        final confirmadas =
            prefs.getStringList(chaveConfirmadas)?.toSet() ?? <String>{};
        confirmadas.add(id);
        var salvo = false;
        try {
          salvo =
              await prefs.setStringList(chaveConfirmadas, confirmadas.toList());
        } finally {
          if (!salvo) await prefs.reload();
        }
        if (!salvo) {
          throw StateError(
              'Não foi possível salvar a confirmação da impressão.');
        }
        await _salvar(_itens.where((e) => e.id != id).toList());
      });

  Future<void> registrarErro(String id, String erro) =>
      _alterarEstado(id, EstadoImpressao.erro, erro);

  Future<void> pausar(String id, String erro) =>
      _alterarEstado(id, EstadoImpressao.pausada, erro);

  Future<void> cancelar(String id) =>
      _alterarEstado(id, EstadoImpressao.cancelamentoPendente, null);

  Future<void> cancelarLote(Set<String> ids) => _executar(() async {
        await _carregar();
        await _salvar(_itens
            .map((item) => !ids.contains(item.id) ||
                    item.estado == EstadoImpressao.aguardandoPedido
                ? item
                : ImpressaoPendente(
                    item.mensagem,
                    estado: EstadoImpressao.cancelamentoPendente,
                    servidor: item.servidor,
                    tentativas: item.tentativas,
                    ultimaTentativa: item.ultimaTentativa,
                  ))
            .toList());
      });

  Future<void> autorizarReenvio(String id,
          {bool manual = false, String servidor = ''}) =>
      _alterarEstado(id, EstadoImpressao.aguardandoEnvio, null,
          retomar: manual, servidor: servidor);

  /// Move para a conexao atual apenas comprovantes que ainda nao chegaram a
  /// ser escritos em nenhum socket ou cuja escrita falhou imediatamente.
  /// Itens sem confirmacao permanecem no servidor de origem para evitar uma
  /// segunda via acidental.
  Future<Set<String>> transferirNaoEnviadasParaServidor(String servidor,
          {String empresa = ''}) =>
      _executar(() async {
        await _carregar();
        final destino = servidor.trim();
        if (destino.isEmpty) return <String>{};

        final transferidas = <String>{};
        final proximos = <ImpressaoPendente>[];
        for (final item in _itens) {
          final empresaItem = item.dados['idEmpresa']?.toString().trim() ?? '';
          final pertenceAEmpresa = empresaItem.isEmpty ||
              (empresa.isNotEmpty && empresaItem == empresa);
          final falhouAoEscrever = item.estado == EstadoImpressao.erro &&
              (item.erro ?? '').toLowerCase().contains('conexao interrompida');
          final podeTransferir =
              item.estado == EstadoImpressao.aguardandoEnvio ||
                  falhouAoEscrever;
          final deveTransferir = podeTransferir &&
              item.servidor.isNotEmpty &&
              item.servidor != destino &&
              pertenceAEmpresa;
          if (!deveTransferir) {
            proximos.add(item);
            continue;
          }
          transferidas.add(item.id);
          proximos.add(ImpressaoPendente(item.mensagem,
              estado: EstadoImpressao.aguardandoEnvio,
              servidor: destino,
              tentativas: 0));
        }
        if (transferidas.isNotEmpty) await _salvar(proximos);
        return transferidas;
      });

  Future<void> _alterarEstado(String id, EstadoImpressao estado, String? erro,
          {bool retomar = false, String servidor = ''}) =>
      _executar(() async {
        await _carregar();
        final index = _itens.indexWhere((e) => e.id == id);
        if (index < 0) return;
        if (_itens[index].estado == EstadoImpressao.cancelamentoPendente &&
            estado != EstadoImpressao.cancelamentoPendente) {
          return;
        }
        if (!retomar &&
            _itens[index].estado == estado &&
            _itens[index].erro == erro) {
          return;
        }
        final proximos = [..._itens];
        final mensagem = retomar
            ? jsonEncode({
                ...proximos[index].dados,
                'retomadaImpressao':
                    DateTime.now().microsecondsSinceEpoch.toString()
              })
            : proximos[index].mensagem;
        proximos[index] = ImpressaoPendente(mensagem,
            estado: estado,
            erro: erro,
            servidor: servidor.trim().isEmpty
                ? proximos[index].servidor
                : servidor.trim(),
            tentativas: retomar ? 0 : proximos[index].tentativas,
            ultimaTentativa: retomar ? null : proximos[index].ultimaTentativa);
        await _salvar(proximos);
      });

  @override
  void dispose() {
    _descartada = true;
    super.dispose();
  }
}
