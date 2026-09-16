import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

class ServicoDelivery {
  final DioCliente dio;
  final UsuarioProvedor usuario;
  ServicoDelivery(this.dio, this.usuario);

  // O Delivery usa a mesma API de venda configurada no aplicativo.
  static Uri enderecoApi(String servidor) => Uri.parse(servidor);

  Future<dynamic> consultar(String rota,
          [Map<String, dynamic> campos = const {}]) =>
      _requisicao(rota, campos, false);

  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await _requisicao(rota, campos, true);
    if (resposta is! Map || resposta['sucesso'] != true) {
      throw StateError(resposta is Map
          ? (resposta['mensagem'] ?? 'Não foi possível salvar.').toString()
          : 'Resposta inválida do servidor.');
    }
    return Map<String, dynamic>.from(resposta);
  }

  Future<dynamic> _requisicao(
      String rota, Map<String, dynamic> campos, bool post) async {
    final empresa = usuario.usuario?.empresa;
    final idUsuario = usuario.usuario?.id;
    if (empresa == null || idUsuario == null) {
      throw StateError('Entre novamente no aplicativo.');
    }
    final servidor =
        enderecoApi((await Apis().getConexao()).servidor).toString();
    final dados = {...campos, 'empresa': empresa, 'id_usuario': idUsuario};
    final opcoes = Options(extra: {'servidorFixo': servidor, 'semCache': true});
    final resposta = post
        ? await dio.cliente.post(rota, data: jsonEncode(dados), options: opcoes)
        : await dio.cliente.get(rota, queryParameters: dados, options: opcoes);
    final json = resposta.data is String
        ? jsonDecode(resposta.data as String)
        : resposta.data;
    if (json is! Map && json is! List) {
      throw StateError('Resposta inválida do Delivery.');
    }
    return json;
  }

  Future<List<EtapaDelivery>> listar(
      {required DateTime inicio,
      required DateTime fim,
      required String horaInicio,
      required String horaFim,
      String pesquisa = '',
      String tipo = '0'}) async {
    final json = await consultar('delivery/listar_opcoes.php', {
      'dataInicio': DateFormat('yyyy-MM-dd').format(inicio),
      'dataFim': DateFormat('yyyy-MM-dd').format(fim),
      'horaSelecionada': horaInicio,
      'horaFimSelecionada': horaFim,
      'pesquisa': pesquisa,
      'tipoentrega': tipo,
    });
    if (json is! Map) throw StateError('Resposta inválida do Delivery.');
    if (json['sucesso'] != true && json['mensagem'] != null) {
      throw StateError(json['mensagem'].toString());
    }
    return [
      for (final e in json['dados'] as List? ?? [])
        EtapaDelivery.fromMap(Map<String, dynamic>.from(e as Map))
    ];
  }

  Future<ConfigDelivery> configuracao() async =>
      ConfigDelivery.fromMap(Map<String, dynamic>.from(
          await consultar('permissoes_bigchef/listar_permissoes_bigchef.php')
              as Map));

  Future<PedidoDelivery> pedido(String id) async {
    final json = await consultar(
        'delivery/listar_opcoes_por_id.php', {'id': id, 'nomedopcLocal': ''});
    if (json is! Map || json['sucesso'] != true || json['dados'] is! Map) {
      throw StateError('Não foi possível consultar o pedido.');
    }
    final pedido =
        PedidoDelivery.fromMap(Map<String, dynamic>.from(json['dados'] as Map));
    if (pedido.id != id) throw StateError('Pedido não encontrado.');
    return pedido;
  }

  Future<Modeloworddadoscardapio> dadosCardapio(String id) async {
    final json = await consultar('cardapio/listar_por_id.php', {
      'id': id,
      'codigoQrcode': '',
      'tipo': 'Delivery',
      'imprimir': 'false',
      'mostrar_itens': 'true',
      'nomedopcLocal': '',
    });
    final dados =
        Modeloworddadoscardapio.fromMap(Map<String, dynamic>.from(json as Map));
    if (dados.id != id) throw StateError('Pedido não encontrado.');
    return dados;
  }

  Future<String> criar(
      {required String cliente,
      required String endereco,
      required String tipo,
      required String observacao}) async {
    if (!['1', '2', '3'].contains(tipo)) {
      throw StateError('Selecione um tipo de entrega válido.');
    }
    if (tipo == '1' &&
        ((int.tryParse(cliente) ?? 0) <= 0 ||
            (int.tryParse(endereco) ?? 0) <= 0)) {
      throw StateError('Selecione o cliente e o endereço da entrega.');
    }
    final res = await salvar('delivery/inserir.php', {
      'cliente': cliente,
      'endereco': tipo == '1' ? endereco : '0',
      'tipoentrega': tipo,
      'obs': observacao,
      'idDeliveryEmEspera': '0',
    });
    final id = (res['dados'] as Map?)?['idDelivery']?.toString();
    if (id == null || id.isEmpty || id == '0') {
      throw StateError('Pedido sem identificação. Atualize o Delivery.');
    }
    return id;
  }

  Future<void> inserirProdutos(
      String id, List<Modelowordprodutos> produtos) async {
    if (produtos.isEmpty) throw StateError('Adicione produtos ao carrinho.');
    final atual = await pedido(id);
    if (atual.encerrado) throw StateError('Este pedido já está encerrado.');
    await salvar('delivery/inserir_produtos.php', {
      'id_delivery': id,
      'id_cliente': atual.cliente,
      'idCardDeFluxos': '0',
      'produtos':
          produtos.map((p) => normalizarProdutoParaEnvio(p.toMap())).toList(),
    });
  }

  Future<Map<String, dynamic>> avancar(
          PedidoDelivery pedido, EtapaDelivery destino,
          {String entregador = '', String valorEntrega = '0'}) =>
      salvar('delivery/mudar_status_delivery.php', {
        'id': pedido.id,
        'status': destino.id,
        'statusOrigem': pedido.etapa,
        'valorOriginal': pedido.total,
        'irParaProximo': false,
        'idEntregador': entregador,
        'valor_da_entrega': valorEntrega,
      });

  Future<void> concluir(PedidoDelivery pedido) => salvar(
      'delivery/finalizar_pedido_delivery.php',
      {'id_delivery': pedido.id, 'cliente': pedido.cliente});

  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
          [Map<String, dynamic> campos = const {}]) =>
      salvar('delivery/acoes_pedido.php', {
        ...campos,
        'acao': acao,
        'id': pedido.id,
        'statusOrigem': pedido.etapa,
      });

  Future<Uri> documentoFiscal(PedidoDelivery pedido, {bool xml = false}) async {
    final chave = pedido.texto('cp15');
    final documento = pedido.texto('docempresa');
    final data = DateTime.tryParse(pedido.texto('dataEmissao'));
    if (!RegExp(r'^\d{44}$').hasMatch(chave) ||
        !RegExp(r'^\d{11,14}$').hasMatch(documento) ||
        data == null) {
      throw StateError(
          'Documento fiscal indisponível. Confira a venda no módulo fiscal.');
    }
    final servidor =
        enderecoApi((await Apis().getConexao()).servidor).resolve('../../../');
    final modelo = pedido.texto('cp16') == '55' ? 'NF-e' : 'NFCe';
    return servidor.resolve(
        'fiscal/Arquivos_XML/$modelo/$documento/producao/enviadas/aprovadas/${DateFormat('yy/MM').format(data)}/$chave-${xml ? 'nfe.xml' : 'pdf.pdf'}');
  }

  Future<void> prepararClone(
      String id, List<Modelowordprodutos> produtos) async {
    final contexto = ContextoCarrinho(
        empresa: usuario.usuario!.empresa!,
        tipo: 'delivery',
        idAtendimento: id);
    final copias = produtos
        .map((p) => Modelowordprodutos.fromMap(_limparClone(p.toMap())))
        .toList();
    final salvo =
        await ArmazenamentoCarrinhos.instancia.alterar(contexto, (itens) {
      if (itens.isNotEmpty) {
        throw StateError('Este pedido já possui um rascunho.');
      }
      itens.addAll(copias);
    });
    if (!salvo) {
      throw StateError('Não foi possível preparar os produtos do clone.');
    }
  }

  static Map<String, dynamic> _limparClone(Map<String, dynamic> mapa) => {
        for (final e in mapa.entries)
          e.key: switch (e.value) {
            Map valor => _limparClone(Map<String, dynamic>.from(valor)),
            List valor => [
                for (final v in valor)
                  v is Map ? _limparClone(Map<String, dynamic>.from(v)) : v
              ],
            _ => e.value,
          },
        if (mapa.containsKey('valorVenda')) ...{
          'iditensvenda': null,
          'hashprodutos': null,
          'novo': true,
          'conferidoNoCarrinho': false,
        },
      };

  Future<void> pagar(PedidoDelivery pedido, int forma, double recebido,
      {double? valorOriginal,
      double? valorAPagar,
      double? desconto,
      double? acrescimo}) async {
    final totalOriginal = valorOriginal ?? pedido.total;
    final totalAPagar = valorAPagar ?? pedido.restante;
    if (forma < 1 ||
        forma > 9 ||
        pedido.encerrado ||
        totalAPagar <= 0.009 ||
        recebido <= 0 ||
        !recebido.isFinite) {
      throw StateError('Confira o valor do pagamento.');
    }
    final troco =
        forma == 1 && recebido > totalAPagar ? recebido - totalAPagar : 0.0;
    if (forma != 1 && recebido > totalAPagar + 0.009) {
      throw StateError('Valor maior que o saldo do pedido.');
    }
    await salvar('delivery/pagar_pedido.php', {
      'id': pedido.id,
      'id_comanda': '0',
      'id_mesa': '0',
      'cliente': pedido.cliente,
      'editar_movimentacao': '0',
      'limpar_pagamentos_anteriores': '0',
      'valor_original': totalOriginal.toStringAsFixed(2),
      'valor_lancamento': recebido.toStringAsFixed(2),
      'pagamentoSelecionado': forma,
      'quantidadePessoas': 1,
      'subTotal': totalOriginal.toStringAsFixed(2),
      'dataLancamento': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'parcelas': '1',
      'parcelasLista': [],
      'tipo': 'Delivery',
      'valortroco': troco.toStringAsFixed(2),
      'valor_da_entrega': pedido.texto('valordaentrega', '0'),
      'valoresProduto': '0',
      'novo': false,
      'tipodeentrega': pedido.tipoEntrega,
      'valorAPagarOriginal': totalOriginal.toStringAsFixed(2),
      'valorAPagar': totalAPagar.toStringAsFixed(2),
      'valordataxadeservico': '0',
      'valordesconto':
          (desconto ?? valorDelivery(pedido.dados['valorDesconto']))
              .toStringAsFixed(2),
      'valoracrescimo':
          (acrescimo ?? valorDelivery(pedido.dados['valorAcrescimo']))
              .toStringAsFixed(2),
      'produtosParaFinalizar': [],
    });
  }
}
