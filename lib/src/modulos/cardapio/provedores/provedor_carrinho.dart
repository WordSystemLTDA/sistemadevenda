import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/itens_comanda_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProvedorCarrinho extends ChangeNotifier {
  final ServicosItensComanda _servico;
  // final ServicoCardapio _servicoCardapio;

  ProvedorCarrinho(this._servico);

  var itensCarrinho = ItensModeloComandao(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);

  Future<dynamic> listarComandasPedidos() async {
    // final res = await _servicoCardapio.listarPorId(idComanda, TipoCardapio.comanda);

    // if (res.produtos != null && res.produtos!.isEmpty) {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.remove('carrinho');
    var carrinhoString = prefs.getString('carrinho');
    List<dynamic> carrinho = carrinhoString != null ? jsonDecode(carrinhoString) : [];

    List<ModeloProduto> listaItens = [];
    num quantidadeTotal = 0;
    double precoTotal = 0;

    for (int index = 0; index < carrinho.length; index++) {
      final item = carrinho[index];

      var itemF = item is String ? ModeloProduto.fromJson(item) : ModeloProduto.fromMap(item);

      listaItens.add(itemF);
      quantidadeTotal += itemF.quantidade ?? 1;
      precoTotal += double.parse(itemF.valorVenda) * (itemF.quantidade ?? 1);
    }

    itensCarrinho = ItensModeloComandao(
      listaComandosPedidos: listaItens,
      quantidadeTotal: quantidadeTotal,
      precoTotal: precoTotal,
    );
    notifyListeners();
    // } else {
    //   List<ModeloProduto> listaItens = [];
    //   num quantidadeTotal = 0;
    //   double precoTotal = 0;

    //   for (int index = 0; index < res.produtos!.length; index++) {
    //     final item = res.produtos![index];

    //     listaItens.add(item);
    //     quantidadeTotal += item.quantidade ?? 1;
    //     precoTotal += double.parse(item.valorVenda) * (item.quantidade ?? 1);
    //   }

    //   itensCarrinho = ItensModeloComandao(
    //     listaComandosPedidos: listaItens,
    //     quantidadeTotal: quantidadeTotal,
    //     precoTotal: precoTotal,
    //   );
    //   notifyListeners();
    // }
  }

  Future<bool> removerComandasPedidos() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('carrinho', jsonEncode([]));
    return true;
  }

  Future<bool> inserir(
    ModeloProduto produto,
    tipo,
    idMesa,
    idComanda,
    valor,
    observacaoMesa,
    idProduto,
    String nomeProduto,
    quantidade,
    observacao,
  ) async {
    final res = await _servico.inserir(
      produto,
      tipo,
      idMesa,
      idComanda,
      valor,
      observacaoMesa,
      idProduto,
      nomeProduto,
      quantidade,
      observacao,
    );

    if (res) {
      await listarComandasPedidos();
    }

    notifyListeners();
    return res;
  }

  Future<bool> lancarPedido(idMesa, idComanda, String idComandaPedido, valorTotal, quantidade, observacao, listaIdProdutos) async {
    final res = await _servico.lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos);

    if (res) {
      await listarComandasPedidos();
    }

    notifyListeners();
    return res;
  }
}
