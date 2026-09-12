import 'dart:convert';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EstadoImpressao { aguardandoPedido, aguardandoEnvio, semConfirmacao, erro }

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

  late final Map<String, dynamic> dados =
      Map.unmodifiable(jsonDecode(mensagem) as Map<String, dynamic>);
  late final String id = dados['idRequisicao'].toString();

  Map<String, dynamic> toMap() => {
        'mensagem': mensagem,
        'estado': estado.name,
        'erro': erro,
        'servidor': servidor,
        'tentativas': tentativas,
        'ultimaTentativa': ultimaTentativa?.toIso8601String(),
      };

  factory ImpressaoPendente.fromMap(Map<String, dynamic> map) =>
      ImpressaoPendente(map['mensagem'] as String,
          estado: EstadoImpressao.values.byName(map['estado'] as String),
          servidor: map['servidor'] as String? ?? '',
          tentativas: map['tentativas'] as int? ?? 0,
          ultimaTentativa:
              DateTime.tryParse(map['ultimaTentativa'] as String? ?? ''),
          erro: map['erro'] as String?);
}

class FilaImpressao extends ChangeNotifier {
  static const chave = 'fila_impressao_confirmada_v1';
  static const chaveLegada = 'fila_mensagens_socket_pendentes';
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
      await banco.gravar(chave, jsonEncode(itens.map((e) => e.toMap()).toList()));
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
    final salvo = banco == null ? prefs.getString(chave) : await banco.ler(chave);
    final itens = salvo == null
        ? <ImpressaoPendente>[]
        : (jsonDecode(salvo) as List)
            .map((e) =>
                ImpressaoPendente.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
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
        for (final mensagem in mensagens) {
          final item =
              ImpressaoPendente(mensagem, servidor: servidor, estado: estado);
          if (item.dados['idRequisicao'] == null || item.id.trim().isEmpty) {
            throw ArgumentError('Impressao sem identificador.');
          }
          if (await BancoLocal.instancia?.ler('impressaoConfirmada:${item.id}') != null) {
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

  Future<void> confirmar(String id) => _executar(() async {
        await _carregar();
        if (!_itens.any((e) => e.id == id)) return;
        final banco = BancoLocal.instancia;
        if (banco != null) {
          final proximos = _itens.where((e) => e.id != id).toList();
          await banco.db.transaction((tx) async {
            await BancoLocal.gravarDocumento(tx, 'impressaoConfirmada:$id', 'true');
            await BancoLocal.gravarDocumento(tx, chave,
                jsonEncode(proximos.map((e) => e.toMap()).toList()));
          });
          _itens = proximos;
          _notificar();
          return;
        }
        await _salvar(_itens.where((e) => e.id != id).toList());
      });

  Future<void> registrarErro(String id, String erro) =>
      _alterarEstado(id, EstadoImpressao.erro, erro);

  Future<void> autorizarReenvio(String id) =>
      _alterarEstado(id, EstadoImpressao.aguardandoEnvio, null);

  Future<void> _alterarEstado(
          String id, EstadoImpressao estado, String? erro) =>
      _executar(() async {
        await _carregar();
        final index = _itens.indexWhere((e) => e.id == id);
        if (index < 0) return;
        final proximos = [..._itens];
        proximos[index] = ImpressaoPendente(proximos[index].mensagem,
            estado: estado,
            erro: erro,
            servidor: proximos[index].servidor,
            tentativas: proximos[index].tentativas,
            ultimaTentativa: proximos[index].ultimaTentativa);
        await _salvar(proximos);
      });

  @override
  void dispose() {
    _descartada = true;
    super.dispose();
  }
}
