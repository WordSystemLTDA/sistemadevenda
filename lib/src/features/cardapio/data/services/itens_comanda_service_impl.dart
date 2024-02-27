import 'dart:convert';
import 'dart:io';
import 'package:app/src/shared/services/api.dart';
import 'package:app/src/shared/shared_prefs/shared_prefs_config.dart';
import 'package:dio/dio.dart';

class ItensComandaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<List<dynamic>> listarComandasPedidos(String idComanda, String idMesa) async {
    final comanda = idComanda.isEmpty ? 0 : idComanda;
    final mesa = idMesa.isEmpty ? 0 : idMesa;

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/pedidos/listar.php?id_comanda=$comanda&id_mesa=$mesa';

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

  Future<bool> removerComandasPedidos(List<String> listaIdItemComanda) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}/pedidos/remover.php';

    final response = await dio.post(
      url,
      data: {'listaIdItemComanda': listaIdItemComanda},
    );

    if (response.statusCode == 200) {
      if (response.data['sucesso']) return true;
      return false;
    }
    return false;
  }

  Future<bool> inserir(tipo, idMesa, idComanda, valor, observacaoMesa, idProduto, quantidade, observacao, listaAdicionais) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}pedidos/inserir.php';

    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final response = await dio.post(
      url,
      data: jsonEncode({
        'tipo': tipo,
        'idMesa': idMesa,
        'idComanda': idComanda,
        'valor': valor,
        'observacaoMesa': observacaoMesa,
        'idProduto': idProduto,
        'quantidade': quantidade,
        'observacao': observacao,
        'listaAdicionais': [...listaAdicionais.map((e) => e.toMap())],
        'idUsuario': idUsuario,
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

  Future<bool> lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}pedidos/lancar_pedido.php';

    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final response = await dio.post(
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
