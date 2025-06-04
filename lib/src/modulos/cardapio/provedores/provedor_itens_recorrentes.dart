import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_itens_recorrentes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProvedorItensRecorrentes extends ChangeNotifier {
  final ServicosItensComanda _servico;
  // final ServicoCardapio _servicoCardapio;

  ProvedorItensRecorrentes(this._servico);

  // var itensCarrinho = ItensModeloComandao(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);
  List<Modelowordprodutos> itensCarrinho = [];

  Future<dynamic> listarComandasPedidos(String idComandaPedido) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var itensRecorrentesString = prefs.getString('itens_recorrentes');
    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<Modelowordprodutos> produtos = [];
    for (int index = 0; index < itensRecorrentes.length; index++) {
      final item = itensRecorrentes[index];

      if (item['idComandaPedido'] == idComandaPedido) {
        var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);
        itemF.produtos.map((e) => produtos.add(e)).toList();
        break;
      }
    }

    itensCarrinho = produtos;
    notifyListeners();
  }

  Future<bool> removerComandasPedidos() async {
    // final SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.setString('itens_recorrentes', jsonEncode([]));
    return true;
  }

  Future<bool> excluirItemCarrinho(String id, int index) async {
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // // prefs.remove(ChavesSharedPreferences.carrinho);

    // String? itensCarrinho = prefs.getString('itens_recorrentes');

    // if (itensCarrinho != null) {
    //   List<Modelowordprodutos> carrinho = List<Modelowordprodutos>.from(json.decode(itensCarrinho).map((e) {
    //     if (e is String) {
    //       return Modelowordprodutos.fromMap(jsonDecode(e));
    //     } else {
    //       return Modelowordprodutos.fromMap(e);
    //     }
    //   }));

    //   carrinho.removeAt(index);

    //   // var carrinho = await listarCarrinho();
    //   prefs.setString('itens_recorrentes', json.encode(carrinho));
    // }

    return true;
  }

  Future<bool> inserir(
    String idComandaPedido,
    Modelowordprodutos produto,
    // Modelowordprodutos produto,
    // tipo,
    // idMesa,
    // idComanda,
    // valor,
    // observacaoMesa,
    // idProduto,
    // String nomeProduto,
    // quantidade,
    // observacao,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var itensRecorrentesString = prefs.getString('itens_recorrentes');
    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<Modelowordprodutos> produtos = [];
    for (int index = 0; index < itensRecorrentes.length; index++) {
      final item = itensRecorrentes[index];

      if (item['idComandaPedido'] == idComandaPedido) {
        var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);
        itemF.produtos.map((e) => produtos.add(e)).toList();
        break;
      }
    }

    produtos.add(produto);

    final res = await prefs.setString('itens_recorrentes', json.encode(ModeloItensRecorrentes(idComandaPedido: idComandaPedido, produtos: produtos)));

    return res;
    // final res = await _servico.inserir(
    //   produto,
    //   tipo,
    //   idMesa,
    //   idComanda,
    //   valor,
    //   observacaoMesa,
    //   idProduto,
    //   nomeProduto,
    //   quantidade,
    //   observacao,
    // );

    // if (res) {
    //   await listarComandasPedidos();
    // }

    // notifyListeners();
    // return res;
  }

  // Future<bool> lancarPedido(idMesa, idComanda, String idComandaPedido, valorTotal, quantidade, observacao, listaIdProdutos) async {
  //   final res = await _servico.lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos);

  //   if (res) {
  //     await listarComandasPedidos();
  //   }

  //   notifyListeners();
  //   return res;
  // }
}
