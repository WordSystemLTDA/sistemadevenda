import 'dart:convert';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:sqflite/sqflite.dart';

/// Um novo Delivery fica duravel no aparelho antes de qualquer envio. A API
/// recebe um unico snapshot idempotente somente depois da confirmacao.
class FilaDeliveryOffline {
  final BancoLocal banco;
  final String escopo, empresa, usuario, destino;

  FilaDeliveryOffline(this.banco,
      {required this.escopo,
      required this.empresa,
      required this.usuario,
      required this.destino});

  static bool local(String id) => id.startsWith('delivery-local:');
  String get _chave => 'delivery_rascunhos_v1:$escopo';

  Future<Map<String, dynamic>> _todos(DatabaseExecutor db) async =>
      Map<String, dynamic>.from(
          jsonDecode(await BancoLocal.lerDocumento(db, _chave) ?? '{}') as Map);

  Future<bool> habilitada() async {
    if (escopo.isEmpty) return false;
    final estado = jsonDecode(await banco.ler('estado:$escopo') ?? '{}') as Map;
    return estado['offline_delivery'] == 1;
  }

  Future<String> criar({
    required String cliente,
    required String endereco,
    required String tipo,
    required String observacao,
    double taxa = 0,
    Map<String, dynamic> exibicao = const {},
  }) async {
    if (!['1', '2', '3'].contains(tipo) ||
        taxa < 0 ||
        !taxa.isFinite ||
        tipo == '1' &&
            ((int.tryParse(cliente) ?? 0) <= 0 ||
                (int.tryParse(endereco) ?? 0) <= 0)) {
      throw StateError('Confira o cliente, endereço e a taxa de entrega.');
    }
    if (!await habilitada()) {
      throw StateError(
          'Conecte ao servidor atualizado para preparar o Delivery offline.');
    }
    final estado = jsonDecode(await banco.ler('estado:$escopo') ?? '{}') as Map;
    final id = 'delivery-local:${BancoLocal.novoId()}';
    await banco.db.transaction((tx) async {
      final todos = await _todos(tx);
      todos[id] = {
        'id': id,
        'cliente': cliente,
        'endereco': endereco,
        'tipoentrega': tipo,
        'obs': observacao,
        'valor_da_entrega': (tipo == '1' ? taxa : 0).toStringAsFixed(2),
        'valor_desconto': '0.00',
        'valor_acrescimo': '0.00',
        'caixa_id': estado['caixa_id'],
        'produtos': <dynamic>[],
        'pagamentos': <dynamic>[],
        'criado': DateTime.now().toIso8601String(),
        'fase': 'rascunho',
        'exibicao': exibicao,
      };
      await BancoLocal.gravarDocumento(tx, _chave, jsonEncode(todos));
    });
    return id;
  }

  Future<Map<String, dynamic>> _obter(DatabaseExecutor db, String id) async {
    final valor = (await _todos(db))[id];
    if (!local(id) || valor is! Map) {
      throw StateError(
          'Este Delivery pertence a outra conta ou não está salvo neste aparelho.');
    }
    return Map<String, dynamic>.from(valor);
  }

  Future<void> _alterar(String id,
      Future<void> Function(Map<String, dynamic>, Transaction) alterar) async {
    await banco.db.transaction((tx) async {
      final todos = await _todos(tx);
      final registro = await _obter(tx, id);
      if (registro['fase'] != 'rascunho') {
        throw StateError(
            'Este Delivery já está na fila de sincronização. Confira suas pendências.');
      }
      await alterar(registro, tx);
      todos[id] = registro;
      await BancoLocal.gravarDocumento(tx, _chave, jsonEncode(todos));
    });
  }

  Future<void> definirTaxa(
    String id,
    String tipo,
    double taxa, {
    String? endereco,
    Map<String, dynamic>? dadosEndereco,
  }) =>
      _alterar(id, (r, _) async {
        if (taxa < 0 || !taxa.isFinite || !['1', '2', '3'].contains(tipo)) {
          throw StateError('Confira a taxa e o tipo de entrega.');
        }
        final enderecoAtual = r['endereco']?.toString() ?? '0';
        final novoEndereco = tipo == '1' ? (endereco ?? enderecoAtual) : '0';
        if (tipo == '1' && (int.tryParse(novoEndereco) ?? 0) <= 0) {
          throw StateError('Selecione um endereço para entrega.');
        }
        if ((r['pagamentos'] as List).isNotEmpty &&
            (tipo != r['tipoentrega'] ||
                (taxa - valorDelivery(r['valor_da_entrega'])).abs() > .009)) {
          throw StateError(
              'Há pagamento parcial salvo. Mantenha a taxa original do pedido.');
        }
        r['tipoentrega'] = tipo;
        r['endereco'] = novoEndereco;
        r['valor_da_entrega'] = (tipo == '1' ? taxa : 0).toStringAsFixed(2);
        if (tipo == '1' && dadosEndereco != null) {
          final exibicao =
              Map<String, dynamic>.from(r['exibicao'] as Map? ?? {});
          exibicao.addAll({
            'enderecoCliente': dadosEndereco['endereco']?.toString() ?? '',
            'numeroCliente': dadosEndereco['numero']?.toString() ?? '',
            'complementoCliente':
                dadosEndereco['complemento']?.toString() ?? '',
            'bairroCliente': dadosEndereco['bairro']?.toString() ?? '',
            'cidadeCliente': dadosEndereco['cidade']?.toString() ?? '',
          });
          r['exibicao'] = exibicao;
        }
      });

  Future<void> definirAjustes(String id,
          {required double desconto, required double acrescimo}) =>
      _alterar(id, (r, _) async {
        if (!desconto.isFinite ||
            !acrescimo.isFinite ||
            desconto < 0 ||
            acrescimo < 0) {
          throw StateError('Confira o desconto e o acréscimo do pedido.');
        }
        if ((r['pagamentos'] as List).isNotEmpty &&
            ((desconto - valorDelivery(r['valor_desconto'])).abs() > .009 ||
                (acrescimo - valorDelivery(r['valor_acrescimo'])).abs() >
                    .009)) {
          throw StateError(
              'Há pagamento parcial salvo. Mantenha os ajustes originais do pedido.');
        }
        r['valor_desconto'] = desconto.toStringAsFixed(2);
        r['valor_acrescimo'] = acrescimo.toStringAsFixed(2);
        if (_total(r) < 0) {
          throw StateError('O desconto não pode superar o valor do pedido.');
        }
      });

  Future<void> inserirProdutos(String id, List<Modelowordprodutos> produtos) =>
      ArmazenamentoCarrinhos.instancia
          .executarComCarrinhosBloqueados(() => _alterar(id, (r, tx) async {
                if ((r['pagamentos'] as List).isNotEmpty) {
                  throw StateError(
                      'Conclua o pagamento deste pedido antes de acrescentar produtos.');
                }
                final contexto = ContextoCarrinho(
                    empresa: empresa, tipo: 'delivery', idAtendimento: id);
                final carrinhos = Map<String, dynamic>.from(jsonDecode(
                    await BancoLocal.lerDocumento(tx, banco.chaveCarrinhos) ??
                        '{}') as Map);
                final carrinho = carrinhos[contexto.chave] as Map?;
                final itens = produtos.map((p) => p.toMap()).toList();
                if (itens.isEmpty ||
                    carrinho == null ||
                    carrinho['bloqueado'] == true ||
                    carrinho['encerrado'] == true ||
                    jsonEncode(carrinho['itens']) != jsonEncode(itens)) {
                  throw StateError(
                      'O carrinho mudou. Confira os produtos antes de finalizar.');
                }
                r['produtos'] = [
                  ...r['produtos'] as List,
                  ...itens.map(normalizarProdutoParaEnvio),
                ];
                // Transferencia atomica: mesmo se o processo encerrar neste instante,
                // os itens ficam no pedido OU no carrinho, nunca perdidos/duplicados.
                carrinho['itens'] = <dynamic>[];
                await BancoLocal.gravarDocumento(
                    tx, banco.chaveCarrinhos, jsonEncode(carrinhos));
              }));

  static double _total(Map<String, dynamic> r) {
    var centavos = (valorDelivery(r['valor_da_entrega']) * 100).round() -
        (valorDelivery(r['valor_desconto']) * 100).round() +
        (valorDelivery(r['valor_acrescimo']) * 100).round();
    for (final item in r['produtos'] as List) {
      centavos += (valorDelivery(item['valorVenda']) *
              (item['quantidade'] == null
                  ? 1
                  : valorDelivery(item['quantidade'])) *
              100)
          .round();
    }
    return centavos / 100;
  }

  static double _pago(Map<String, dynamic> r) =>
      (r['pagamentos'] as List).fold<int>(
          0,
          (total, p) =>
              total +
              (valorDelivery(p['valor_lancamento']) * 100).round() -
              (valorDelivery(p['valortroco']) * 100).round()) /
      100;

  Future<Map<String, dynamic>> pagar(
      String id, Map<String, dynamic> dados) async {
    await _alterar(id, (r, tx) async {
      final pagamentos = r['pagamentos'] as List;
      final chave = dados['chavePagamento']?.toString() ?? '';
      if (chave.isEmpty) throw StateError('Pagamento sem identificação.');
      final anterior = pagamentos
          .whereType<Map>()
          .where((p) => p['chavePagamento'] == chave)
          .firstOrNull;
      if (anterior != null) {
        if (jsonEncode(anterior) != jsonEncode(dados)) {
          throw StateError(
              'Este pagamento já foi salvo com outros valores. Confira o pedido.');
        }
        return;
      }
      final contexto = ContextoCarrinho(
          empresa: empresa, tipo: 'delivery', idAtendimento: id);
      final carrinhos = jsonDecode(
              await BancoLocal.lerDocumento(tx, banco.chaveCarrinhos) ?? '{}')
          as Map;
      if (((carrinhos[contexto.chave] as Map?)?['itens'] as List? ?? [])
          .isNotEmpty) {
        throw StateError(
            'Há novos produtos no carrinho. Finalize os itens antes de receber o pagamento.');
      }
      // `0` e um estado valido confirmado pela API: significa que nao existe
      // caixa aberto para este usuario e preserva o mesmo comportamento do
      // pagamento online. Antes ele era confundido com "nunca sincronizou".
      // No primeiro pagamento tambem aproveita um caixa que tenha sido aberto
      // depois da criacao do rascunho.
      final estado = jsonDecode(
          await BancoLocal.lerDocumento(tx, 'estado:$escopo') ?? '{}') as Map;
      final caixaAtual = estado.containsKey('caixa_id')
          ? int.tryParse('${estado['caixa_id']}')
          : null;
      if (pagamentos.isEmpty && caixaAtual != null && caixaAtual >= 0) {
        r['caixa_id'] = caixaAtual.toString();
      }
      final caixaConfirmado = int.tryParse('${r['caixa_id'] ?? ''}');
      if (caixaConfirmado == null || caixaConfirmado < 0) {
        throw StateError(
            'Sincronize o aplicativo antes de receber este pagamento.');
      }
      final desconto = valorDelivery(dados['valordesconto']);
      final acrescimo = valorDelivery(dados['valoracrescimo']);
      if (desconto < 0 || acrescimo < 0) {
        throw StateError('Confira o desconto e o acréscimo do pedido.');
      }
      if (pagamentos.isNotEmpty &&
          ((desconto - valorDelivery(r['valor_desconto'])).abs() > .009 ||
              (acrescimo - valorDelivery(r['valor_acrescimo'])).abs() > .009)) {
        throw StateError(
            'Há pagamento parcial salvo. Mantenha os ajustes originais do pedido.');
      }
      r['valor_desconto'] = desconto.toStringAsFixed(2);
      r['valor_acrescimo'] = acrescimo.toStringAsFixed(2);
      final restante = _total(r) - _pago(r);
      final recebido = valorDelivery(dados['valor_lancamento']);
      final troco = valorDelivery(dados['valortroco']);
      if (recebido <= 0 ||
          troco < 0 ||
          recebido <= troco ||
          recebido - troco > restante + .009 ||
          restante <= .009) {
        throw StateError(
            'O saldo do pedido mudou. Confira o pagamento antes de continuar.');
      }
      pagamentos.add(dados);
    });
    return {'sucesso': true, 'salvo_no_aparelho': true};
  }

  Future<void> concluir(String id) => _alterar(id, (r, _) async {
        if (_total(r) - _pago(r) > .009) {
          throw StateError('Ainda há saldo a receber neste pedido.');
        }
        r['concluido'] = true;
      });

  /// Descarta o rascunho e qualquer carrinho ainda associado em um unico
  /// commit. Pedidos que ja entraram na fila de sincronizacao nao podem ser
  /// removidos por esta acao.
  Future<void> excluirRascunho(String id) =>
      ArmazenamentoCarrinhos.instancia.executarComCarrinhosBloqueados(() async {
        await banco.db.transaction((tx) async {
          final todos = await _todos(tx);
          final registro = await _obter(tx, id);
          if (registro['fase'] != 'rascunho') {
            throw StateError(
                'Este pedido já está na fila de sincronização e não pode ser excluído.');
          }

          final contexto = ContextoCarrinho(
              empresa: empresa, tipo: 'delivery', idAtendimento: id);
          final carrinhos = Map<String, dynamic>.from(jsonDecode(
              await BancoLocal.lerDocumento(tx, banco.chaveCarrinhos) ??
                  '{}') as Map);
          todos.remove(id);
          carrinhos.remove(contexto.chave);
          await BancoLocal.gravarDocumento(tx, _chave, jsonEncode(todos));
          await BancoLocal.gravarDocumento(
              tx, banco.chaveCarrinhos, jsonEncode(carrinhos));
        });
      });

  Future<void> confirmar(String id) async {
    await banco.db.transaction((tx) async {
      final todos = await _todos(tx);
      final r = await _obter(tx, id);
      if (r['fase'] == 'enfileirado') return;
      if ((r['produtos'] as List).isEmpty) {
        throw StateError('Adicione produtos antes de confirmar o Delivery.');
      }
      final contexto = ContextoCarrinho(
          empresa: empresa, tipo: 'delivery', idAtendimento: id);
      final carrinhos = jsonDecode(
              await BancoLocal.lerDocumento(tx, banco.chaveCarrinhos) ?? '{}')
          as Map;
      if (((carrinhos[contexto.chave] as Map?)?['itens'] as List? ?? [])
          .isNotEmpty) {
        throw StateError(
            'Há novos produtos no carrinho deste Delivery. Confira e finalize esses itens antes de confirmar.');
      }
      final operacao = id.substring('delivery-local:'.length);
      final dados = {
        'empresa': empresa,
        'id_usuario': usuario,
        'tipo': 'delivery',
        for (final campo in [
          'cliente',
          'endereco',
          'tipoentrega',
          'obs',
          'valor_da_entrega',
          'valor_desconto',
          'valor_acrescimo',
          'caixa_id',
          'produtos',
          'pagamentos'
        ])
          campo: r[campo],
        'concluido': true,
      };
      await tx.insert('operacoes', {
        'id': operacao,
        'escopo': escopo,
        'atendimento': id,
        'acao': 'delivery',
        'estado': 'pendente',
        'dados': jsonEncode(dados),
        'impressoes': '[]',
        'destino': destino,
        'criado': DateTime.now().millisecondsSinceEpoch,
      });
      r['fase'] = 'enfileirado';
      todos[id] = r;
      await BancoLocal.gravarDocumento(tx, _chave, jsonEncode(todos));
    });
  }

  Future<PedidoDelivery> pedido(String id) async {
    final registro = await _obter(banco.db, id);
    final op = await _operacao(id);
    return _pedido(registro, op);
  }

  Future<Map<String, Object?>?> _operacao(String id) async =>
      (await banco.db.query('operacoes',
              where: 'escopo = ? AND atendimento = ? AND acao = ?',
              whereArgs: [escopo, id, 'delivery'],
              limit: 1))
          .firstOrNull;

  Future<List<PedidoDelivery>> listar() async {
    final todos = await _todos(banco.db);
    final carrinhos =
        jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}') as Map;
    final pedidos = <PedidoDelivery>[];
    for (final valor in todos.values.whereType<Map>()) {
      final r = Map<String, dynamic>.from(valor);
      final op = await _operacao(r['id'] as String);
      if (['concluido', 'arquivado'].contains(op?['estado'])) continue;
      final contexto = ContextoCarrinho(
          empresa: empresa, tipo: 'delivery', idAtendimento: r['id'] as String);
      final itensCarrinho =
          (carrinhos[contexto.chave] as Map?)?['itens'] as List?;
      pedidos.add(_pedido(r, op, itensCarrinho: itensCarrinho));
    }
    pedidos.sort(
        (a, b) => b.texto('dataAbertura').compareTo(a.texto('dataAbertura')));
    return pedidos;
  }

  PedidoDelivery _pedido(Map<String, dynamic> r, Map<String, Object?>? op,
      {List<dynamic>? itensCarrinho}) {
    final produtosConfirmados = r['produtos'] as List;
    final produtos = [
      ...produtosConfirmados,
      if (r['fase'] == 'rascunho') ...itensCarrinho ?? [],
    ];
    final total = _total({...r, 'produtos': produtos}).toStringAsFixed(2);
    final id = r['id'] as String;
    final exibicao = r['exibicao'] as Map? ?? {};
    final recibo = jsonDecode(op?['resposta'] as String? ?? '{}') as Map;
    return PedidoDelivery.fromMap({
      ...exibicao,
      'id': id,
      'idVenda': '0',
      'numeroPedido': recibo['numeroPedido']?.toString() ?? '',
      'idCliente': r['cliente'],
      'idendereco': r['endereco'],
      'tipodeentrega': r['tipoentrega'],
      'observacaoDoPedido': r['obs'],
      'dataAbertura': r['criado'],
      'idopcoescarrossel': 'local',
      'status': 'Pendente',
      'recorrenteVinculado': false,
      'valorVenda': total,
      'valorTotal': total,
      'somaValorHistorico': _pago(r).toStringAsFixed(2),
      'valordaentrega': r['valor_da_entrega'],
      'valorentrega': r['valor_da_entrega'],
      'valorDesconto': r['valor_desconto'],
      'valorAcrescimo': r['valor_acrescimo'],
      'quantidadeprodutos': produtos.length.toString(),
      'produtos': produtos,
      'produtosConfirmadosLocal': produtosConfirmados.isNotEmpty,
      'possuiRascunhoLocal': itensCarrinho?.isNotEmpty == true,
      'lancamentos': [
        for (final p in r['pagamentos'] as List)
          {
            'nome': _nomePagamentoLocal(p as Map),
            'valor': (valorDelivery(p['valor_lancamento']) -
                    valorDelivery(p['valortroco']))
                .toStringAsFixed(2)
          }
      ],
      'faseLocal': r['fase'],
      'estadoSincronizacao': op?['estado'] ?? 'rascunho',
      'erroSincronizacao': op?['erro'],
    });
  }

  static String _nomePagamentoLocal(Map pagamento) {
    final informado = pagamento['nomePagamento']?.toString().trim() ?? '';
    if (informado.isNotEmpty) return informado;
    return switch (int.tryParse('${pagamento['pagamentoSelecionado']}')) {
      1 => 'Dinheiro',
      2 => 'Conta',
      3 => 'Débito',
      4 => 'Crédito',
      5 => 'Pix',
      _ => 'Forma de pagamento',
    };
  }
}
