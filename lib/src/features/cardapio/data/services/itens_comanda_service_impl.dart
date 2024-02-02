import 'dart:convert';
import 'dart:io';

import 'package:app/src/shared/services/api.dart';
import 'package:app/src/shared/shared_prefs/shared_prefs_config.dart';
import 'package:dio/dio.dart';

class ItensComandaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<List<dynamic>> listarComandasPedidos(String idComanda) async {
    final url = '${Apis.baseUrl}/pedidos/listar.php?id_comanda=$idComanda';

    final response = await dio.get(url);

    if (response.statusCode == 200) return response.data;

    return [];

    //     if (response.statusCode == 200) {
    //   return List<CategoriaModel>.from(
    //     response.data.map((elemento) {
    //       return CategoriaModel.fromMap(elemento);
    //     }),
    //   );
    // } else {
    //   return Future.error("Ops! Um erro ocorreu.");
    // }
  }

  Future<bool> removerComandasPedidos(String idItemComanda) async {
    const url = '${Apis.baseUrl}/pedidos/remover.php';

    final response = await dio.post(
      url,
      data: {'idItemComanda': idItemComanda},
    );

    if (response.statusCode == 200) {
      if (response.data['sucesso']) return true;
      return false;
    }
    return false;
  }

  Future<bool> inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    const url = '${Apis.baseUrl}pedidos/inserir.php';

    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];

    final response = await dio.post(
      url,
      data: jsonEncode({
        'idComanda': idComanda,
        'valor': valor,
        'observacaoMesa': observacaoMesa,
        'idProduto': idProduto,
        'quantidade': quantidade,
        'observacao': observacao,
        'idUsuario': idUsuario,
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

  Future<bool> lancarPedido(idComanda, valorTotal, quantidade, observacao, listaIdProdutos) async {
    const url = '${Apis.baseUrl}pedidos/lancar_pedido.php';

    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final response = await dio.post(
      url,
      data: jsonEncode({
        'usuario': idUsuario,
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
    // print(response.data);

    return false;
  }
}
