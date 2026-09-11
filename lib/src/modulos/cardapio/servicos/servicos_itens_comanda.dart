import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';

class ServicosItensComanda {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicosItensComanda(this.dio, this.usuarioProvedor);
  ArmazenamentoCarrinhos get armazenamento => ArmazenamentoCarrinhos.instancia;

  Future<List<dynamic>> listarComandasPedidos(
      String idComanda, String idMesa) async {
    final comanda = idComanda.isEmpty ? 0 : idComanda;
    final mesa = idMesa.isEmpty ? 0 : idMesa;

    final url = 'pedidos/listar.php?id_comanda=$comanda&id_mesa=$mesa';
    final response = await dio.cliente.get(url);

    if (response.statusCode == 200) return response.data;

    return [];
  }

  Future<bool> removerComandasPedidos(List<String> listaIdItemComanda) async {
    const url = '/pedidos/remover.php';

    final response = await dio.cliente.post(
      url,
      data: {'listaIdItemComanda': listaIdItemComanda},
    );

    if (response.statusCode == 200) {
      if (response.data['sucesso']) return true;
      return false;
    }
    return false;
  }

  Future<bool> inserir(
    Modelowordprodutos produto,
    tipo,
    idMesa,
    idComanda,
    valor,
    observacaoMesa,
    idProduto,
    String nomeProduto,
    quantidade,
    observacao, {
    required ContextoCarrinho contexto,
  }) async {
    final copia = Modelowordprodutos.fromMap(produto.toMap());
    return armazenamento.alterar(contexto, (itens) => itens.insert(0, copia));
  }

  Future<bool> editar(Modelowordprodutos produto, int index,
      {required ContextoCarrinho contexto}) async {
    final copia = Modelowordprodutos.fromMap(produto.toMap());
    return armazenamento.alterar(contexto, (itens) => itens[index] = copia);
  }

  Future<bool> lancarPedido(
      dynamic idMesa,
      dynamic idComanda,
      dynamic valorTotal,
      dynamic quantidade,
      dynamic observacao,
      dynamic listaIdProdutos) async {
    const url = 'pedidos/lancar_pedido.php';

    final idUsuario = usuarioProvedor.usuario!.id;
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.post(
      url,
      data: jsonEncode({
        'usuario': idUsuario,
        'idMesa': idMesa,
        'id_comanda': idComanda,
        'observacoes': observacao,
        'valor_total_pedido': valorTotal,
        'quantidade_de_itens': quantidade,
        'listaIdProdutos': listaIdProdutos,
        'empresa': empresa,
      }),
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      }),
    );

    final Map<dynamic, dynamic> result = response.data;
    final bool sucesso = result['sucesso'];

    if (response.statusCode == 200 && sucesso == true) {
      return sucesso;
    }

    return false;
  }
}
