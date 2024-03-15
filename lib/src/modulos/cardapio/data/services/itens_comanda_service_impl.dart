import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/services/api.dart';
import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:app/src/modulos/produto/interactor/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/tamanhos_modelo.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<bool> inserir(
    tipo,
    idMesa,
    idComanda,
    valor,
    observacaoMesa,
    idProduto,
    String nomeProduto,
    quantidade,
    observacao,
    List<AdicionaisModelo> listaAdicionais,
    List<AcompanhamentosModelo> listaAcompanhamentos,
    TamanhosModelo? tamanhoSelecionado,
  ) async {
    // final conexao = await Apis().getConexao();
    // if (conexao == null) return false;
    // final url = '${conexao['servidor']}pedidos/inserir.php';

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var carrinhoString = prefs.getString('carrinho');
    var carrinho = carrinhoString != null ? jsonDecode(carrinhoString) : [];

    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    var salvarCarrinho = [
      {
        'nome': nomeProduto,
        'tipo': tipo,
        'idMesa': idMesa,
        'idComanda': idComanda,
        'valor': valor,
        'observacaoMesa': observacaoMesa,
        'idProduto': idProduto,
        'quantidade': quantidade,
        'observacao': observacao,
        'listaAdicionais': [...listaAdicionais.map((e) => e.toMap())],
        'listaAcompanhamentos': [...listaAcompanhamentos.map((e) => e.toMap())],
        'tamanhoSelecionado': tamanhoSelecionado != null ? tamanhoSelecionado.id : 0,
        'idUsuario': idUsuario,
        'empresa': empresa,
      },
      ...carrinho,
    ];

    await prefs.setString('carrinho', jsonEncode(salvarCarrinho));

    return true;
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
