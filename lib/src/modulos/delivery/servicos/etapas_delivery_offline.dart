import 'dart:convert';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:sqflite/sqflite.dart';

import '../modelos/modelo_delivery.dart';

/// A intenção operacional é durável e independente do snapshot financeiro.
/// O mesmo recibo é reenviado até a API confirmar, inclusive após reiniciar.
class EtapasDeliveryOffline {
  final BancoLocal banco;
  final String escopo;
  EtapasDeliveryOffline(this.banco, this.escopo);

  String get _chaveEtapas => 'etapas-delivery-operacao:$escopo';
  String get _chaveConfig => 'config-delivery-operacao:$escopo';

  Future<void> prepararEtapas(List<EtapaDelivery> etapas) async {
    final oficiais =
        etapas.where((e) => (int.tryParse(e.id) ?? 0) > 0).toList();
    if (oficiais.isEmpty) return;
    await banco.gravar(
        _chaveEtapas,
        jsonEncode([
          for (final e in oficiais)
            {
              'id': e.id,
              'impressao': e.impressao,
              'entregador': e.selecionarEntregador,
            }
        ]));
  }

  Future<void> prepararConfig(ConfigDelivery config) => banco.gravar(
      _chaveConfig, jsonEncode({'receberNoFinal': config.receberNoFinal}));

  Future<String> _identidade(DatabaseExecutor db, String id) async {
    if (id.startsWith('delivery-local:')) return id;
    for (final op in await db.query('operacoes',
        where: "escopo = ? AND acao = 'delivery'", whereArgs: [escopo])) {
      final recibo = jsonDecode(op['resposta'] as String? ?? '{}') as Map;
      if (recibo['idDelivery']?.toString() == id) {
        return op['atendimento'] as String;
      }
    }
    return id;
  }

  Future<Map<String, Object?>?> _ultima(DatabaseExecutor db, String id) async =>
      (await db.query('operacoes',
              where:
                  "escopo = ? AND atendimento = ? AND acao = 'etapa_delivery' "
                  "AND estado <> 'arquivado'",
              whereArgs: [escopo, id],
              orderBy: 'criado DESC, rowid DESC',
              limit: 1))
          .firstOrNull;

  PedidoDelivery _projecao(Map<String, Object?> op, {PedidoDelivery? atual}) {
    final dados = jsonDecode(op['dados'] as String) as Map;
    return PedidoDelivery.fromMap({
      ...Map<String, dynamic>.from(dados['pedido_local'] as Map),
      if (atual != null) ...atual.dados,
      'idopcoescarrossel': dados['status'],
      'etapaLocalPendente': op['estado'] != 'concluido',
      'estadoEtapaLocal': op['estado'],
      'erroEtapaLocal': op['erro'],
      'idOperacaoEtapaLocal': op['id'],
    });
  }

  Future<PedidoDelivery> projetar(PedidoDelivery pedido) async {
    if (pedido.cancelado || pedido.aguardandoPagamentoOnline) return pedido;
    final id = await _identidade(banco.db, pedido.id);
    final op = await _ultima(banco.db, id);
    if (op == null || op['estado'] == 'concluido') return pedido;
    return _projecao(op, atual: pedido);
  }

  Future<PedidoDelivery> avancar({
    required PedidoDelivery pedido,
    required EtapaDelivery destino,
    required String empresa,
    required String usuario,
    required String conexao,
    required String entregador,
    required String valorEntrega,
    required List<String> impressoes,
  }) async {
    if (escopo.isEmpty ||
        pedido.cancelado ||
        pedido.aguardandoPagamentoOnline) {
      throw StateError('Este pedido não está liberado para avançar.');
    }
    if (pedido.salvoNoAparelho && !pedido.aguardandoSincronizacao) {
      throw StateError('Confirme os produtos e o pagamento antes de preparar.');
    }
    if (pedido.quantidade <= 0) {
      throw StateError('Adicione produtos antes de avançar.');
    }
    if ((int.tryParse(destino.id) ?? 0) <= 0 || pedido.etapa.isEmpty) {
      throw StateError('Atualize as etapas do Delivery antes de avançar.');
    }
    if (pedido.tipoEntrega == '1' &&
        destino.selecionarEntregador &&
        (int.tryParse(entregador) ?? 0) <= 0) {
      throw StateError('Selecione o entregador para avançar o pedido.');
    }
    final taxa = double.tryParse(valorEntrega.replaceAll(',', '.'));
    if (taxa == null || !taxa.isFinite || taxa < 0) {
      throw StateError('Confira o valor da entrega.');
    }
    if (destino.impressao == '3' && pedido.restante > .009) {
      throw StateError('Ainda há saldo a receber neste pedido.');
    }
    return banco.db.transaction((tx) async {
      final configuracao =
          jsonDecode(await BancoLocal.lerDocumento(tx, _chaveConfig) ?? '{}')
              as Map;
      if (configuracao['receberNoFinal'] == false &&
          pedido.restante > .009 &&
          !pedido.pagamentoPendente) {
        throw StateError('Receba o saldo do pedido antes de avançar.');
      }
      final quadro =
          jsonDecode(await BancoLocal.lerDocumento(tx, _chaveEtapas) ?? '[]')
              as List;
      if (quadro.isNotEmpty) {
        final indice = quadro.indexWhere((e) => e['id'] == pedido.etapa);
        final proxima = indice < 0 || indice + 1 >= quadro.length
            ? null
            : quadro[indice + 1] as Map;
        if (indice < 0 ||
            quadro[indice]['impressao'] == '3' ||
            proxima?['id'] != destino.id ||
            proxima?['impressao'] != destino.impressao ||
            proxima?['entregador'] != destino.selecionarEntregador) {
          throw StateError(
              'Confira a próxima etapa e sua configuração no Delivery.');
        }
      }
      final id = await _identidade(tx, pedido.id);
      final anterior = await _ultima(tx, id);
      if (anterior?['estado'] == 'conflito') {
        throw StateError('Confira a etapa em conflito nas pendências.');
      }
      if (anterior != null) {
        final anteriorDados = jsonDecode(anterior['dados'] as String) as Map;
        // Dois cliques sobre o mesmo retrato não criam dois avanços.
        if (anteriorDados['statusOrigem'] == pedido.etapa &&
            anteriorDados['status'] == destino.id) {
          return _projecao(anterior, atual: pedido);
        }
        if (anterior['estado'] != 'concluido' &&
            anteriorDados['status'] != pedido.etapa) {
          throw StateError('A etapa do pedido mudou. Confira o Delivery.');
        }
      }
      final cancelamentos = await tx.query('operacoes',
          where: "escopo = ? AND acao = 'cancelar_delivery' "
              "AND atendimento IN (?, ?) AND estado NOT IN ('conflito', 'arquivado')",
          whereArgs: [escopo, pedido.id, id],
          limit: 1);
      if (cancelamentos.isNotEmpty) {
        throw StateError('O cancelamento deste pedido já está salvo.');
      }
      final operacao = BancoLocal.novoId();
      final dados = {
        'empresa': empresa,
        'id_usuario': usuario,
        'id': pedido.id,
        'status': destino.id,
        'statusOrigem': pedido.etapa,
        'tipoImpressaoEsperado': destino.impressao,
        'valorOriginal': pedido.total,
        'idEntregador': entregador,
        'valor_da_entrega': valorEntrega,
        'impressoes': impressoes,
        'impressao_local': true,
        'concluir': destino.impressao == '3',
        'pedido_local': {
          ...pedido.dados,
          'idopcoescarrossel': destino.id,
          'idEntregador': entregador,
        },
      };
      await tx.insert('operacoes', {
        'id': operacao,
        'escopo': escopo,
        'atendimento': id,
        'acao': 'etapa_delivery',
        'estado': 'pendente',
        'dados': jsonEncode(dados),
        'impressoes': '[]',
        'destino': conexao,
        'criado': DateTime.now().millisecondsSinceEpoch,
      });
      return PedidoDelivery.fromMap({
        ...Map<String, dynamic>.from(dados['pedido_local'] as Map),
        'etapaLocalPendente': true,
        'estadoEtapaLocal': 'pendente',
        'idOperacaoEtapaLocal': operacao,
      });
    });
  }

  Future<List<EtapaDelivery>> projetarQuadro(List<EtapaDelivery> etapas,
      {bool Function(PedidoDelivery pedido)? filtro}) async {
    final ultimas = <String, Map<String, Object?>>{};
    for (final op in await banco.db.query('operacoes',
        where:
            "escopo = ? AND acao = 'etapa_delivery' AND estado <> 'arquivado'",
        whereArgs: [escopo],
        orderBy: 'criado, rowid')) {
      ultimas[op['atendimento'] as String] = op;
    }
    final locais = <PedidoDelivery>[];
    final substituidos = <String>{};
    for (final entrada in ultimas.entries) {
      final op = entrada.value;
      if (op['estado'] == 'concluido') continue;
      var local = _projecao(op);
      final aliases = {
        entrada.key,
        local.id,
        local.texto('idDeliveryConfirmado')
      };
      if (entrada.key.startsWith('delivery-local:')) {
        final origem = (await banco.db.query('operacoes',
                where: "escopo = ? AND atendimento = ? AND acao = 'delivery'",
                whereArgs: [escopo, entrada.key],
                limit: 1))
            .firstOrNull;
        if (origem != null) {
          final recibo =
              jsonDecode(origem['resposta'] as String? ?? '{}') as Map;
          aliases.add(recibo['idDelivery']?.toString() ?? '');
        }
      }
      final atual = etapas
          .expand((e) => e.pedidos)
          .where((p) => aliases.contains(p.id))
          .firstOrNull;
      // A API omite MP estornado/bloqueado da lista operacional. A cópia
      // aprovada antiga nunca pode recolocar esse pagamento no painel.
      if (atual == null && local.pagamentoMercadoPagoObrigatorio) continue;
      if (atual != null) {
        if (atual.cancelado || atual.aguardandoPagamentoOnline) continue;
        local = _projecao(op, atual: atual);
      }
      substituidos.addAll(aliases.where((id) => id.isNotEmpty));
      if (filtro == null || filtro(local)) locais.add(local);
    }
    return [
      for (final etapa in etapas)
        EtapaDelivery.comPedidos(etapa, [
          ...etapa.pedidos.where((p) => !substituidos.contains(p.id)),
          ...locais.where((p) => p.etapa == etapa.id),
        ])
    ];
  }
}
