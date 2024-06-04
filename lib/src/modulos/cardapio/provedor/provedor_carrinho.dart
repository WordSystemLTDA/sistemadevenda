import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/adicional_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/carrinho_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/itens_comanda_modelo.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/produto/interactor/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/tamanhos_modelo.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProvedorCarrinho extends ChangeNotifier {
  final ServicosItensComanda _service = ServicosItensComanda();

  var itensCarrinho = ItensComandaModelo(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);

  Future<dynamic> listarComandasPedidos(String idComanda, String idMesa) async {
    final res = await _service.listarComandasPedidos(idComanda, idMesa);

    if (res.isEmpty) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      var carrinhoString = prefs.getString('carrinho');
      List<dynamic> carrinho = carrinhoString != null ? jsonDecode(carrinhoString) : [];

      List<CarrinhoModelo> listaItens = [];
      num quantidadeTotal = 0;
      double precoTotal = 0;

      for (int index = 0; index < carrinho.length; index++) {
        final item = carrinho[index];

        listaItens.add(CarrinhoModelo(
          id: item['id'] ?? '',
          nome: item['nome'] ?? '',
          foto: item['foto'] ?? '',
          valor: double.parse(item['valor'] ?? '0'),
          quantidade: num.parse(item['quantidade'].toString()),
          estaExpandido: false,
          listaAcompanhamentos: List<AcompanhamentosModelo>.from(item['listaAcompanhamentos'].map((e) {
            return AcompanhamentosModelo.fromMap(e);
          })),
          tamanhoSelecionado: item['tamanhoSelecionado'].toString(),
          listaAdicionais: [
            ...item['listaAdicionais'].map(
              (e) => AdicionalModelo(
                id: e['id'],
                quantidade: num.parse(e['quantidade'].toString()),
                valorAdicional: double.parse(e['valorAdicional'] ?? '0'),
                nome: e['nome'],
              ),
            ),
          ],
        ));
        quantidadeTotal += num.parse(item['quantidade'].toString());
        precoTotal += double.parse(item['valor'] ?? '0') * num.parse(item['quantidade'].toString());
        item['listaAdicionais'].map((e) {
          precoTotal += double.parse(e['valorAdicional'] ?? '0') * num.parse(e['quantidade'].toString());
        }).toList();
      }

      itensCarrinho = ItensComandaModelo(
        listaComandosPedidos: listaItens,
        quantidadeTotal: quantidadeTotal,
        precoTotal: precoTotal,
      );
      notifyListeners();
    } else {
      List<CarrinhoModelo> listaItens = [];
      num quantidadeTotal = 0;
      double precoTotal = 0;

      for (int index = 0; index < res.length; index++) {
        final item = res[index];

        listaItens.add(CarrinhoModelo(
          id: item['id'] ?? '',
          nome: item['nome'] ?? '',
          foto: item['foto'] ?? '',
          valor: double.parse(item['valor'] ?? '0'),
          quantidade: num.parse(item['quantidade'].toString()),
          estaExpandido: false,
          listaAcompanhamentos: List<AcompanhamentosModelo>.from(item['listaAcompanhamentos'].map((e) {
            return AcompanhamentosModelo.fromMap(e);
          })),
          tamanhoSelecionado: item['tamanhoSelecionado'].toString(),
          listaAdicionais: [
            ...item['listaAdicionais'].map(
              (e) => AdicionalModelo(
                id: e['id'],
                quantidade: num.parse(e['quantidade'].toString()),
                valorAdicional: double.parse(e['valorAdicional'] ?? '0'),
                nome: e['nome'],
              ),
            ),
          ],
        ));
        quantidadeTotal += num.parse(item['quantidade'].toString());
        precoTotal += double.parse(item['valor'] ?? '0') * num.parse(item['quantidade'].toString());
        item['listaAdicionais'].map((e) {
          precoTotal += double.parse(e['valorAdicional'] ?? '0') * num.parse(e['quantidade'].toString());
        }).toList();
      }

      itensCarrinho = ItensComandaModelo(
        listaComandosPedidos: listaItens,
        quantidadeTotal: quantidadeTotal,
        precoTotal: precoTotal,
      );
      notifyListeners();
    }
  }

  Future<bool> removerComandasPedidos(String idComanda, String idMesa, List<String> listaIdItemComanda) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('carrinho', jsonEncode([]));
    return true;
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
    final res = await _service.inserir(
      tipo,
      idMesa,
      idComanda,
      valor,
      observacaoMesa,
      idProduto,
      nomeProduto,
      quantidade,
      observacao,
      listaAdicionais,
      listaAcompanhamentos,
      tamanhoSelecionado,
    );

    if (res) {
      await listarComandasPedidos(idComanda.toString(), idMesa);
    }

    notifyListeners();
    return res;
  }

  Future<bool> lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos) async {
    final res = await _service.lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos);

    if (res) {
      await listarComandasPedidos(idComanda, idMesa);
    }

    notifyListeners();
    return res;
  }
}
