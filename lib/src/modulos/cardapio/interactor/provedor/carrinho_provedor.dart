import 'package:app/src/modulos/cardapio/data/services/itens_comanda_service_impl.dart';
import 'package:app/src/modulos/cardapio/interactor/models/adicional_modelo.dart';
import 'package:app/src/modulos/cardapio/interactor/models/carrinho_modelo.dart';
import 'package:app/src/modulos/cardapio/interactor/models/itens_comanda_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/tamanhos_modelo.dart';
import 'package:flutter/material.dart';

class CarrinhoProvedor extends ChangeNotifier {
  final ItensComandaServiceImpl _service = ItensComandaServiceImpl();

  var itensCarrinho = ItensComandaModelo(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);

  Future<dynamic> listarComandasPedidos(String idComanda, String idMesa) async {
    List<dynamic> listaComandosPedidos = await _service.listarComandasPedidos(idComanda, idMesa);

    List<CarrinhoModelo> listaItens = [];
    num quantidadeTotal = 0;
    double precoTotal = 0;

    for (int index = 0; index < listaComandosPedidos.length; index++) {
      final item = listaComandosPedidos[index];

      listaItens.add(CarrinhoModelo(
        id: item['id'],
        nome: item['nome'],
        foto: item['foto'],
        valor: double.parse(item['valor']),
        quantidade: num.parse(item['quantidade']),
        estaExpandido: false,
        listaAcompanhamentos: List<AcompanhamentosModelo>.from(item['listaAcompanhamentos'].map((e) {
          return AcompanhamentosModelo.fromMap(e);
        })),
        tamanhoSelecionado: item['tamanhoSelecionado'],
        listaAdicionais: [
          ...item['listaAdicionais'].map(
            (e) => AdicionalModelo(
              id: e['id'],
              quantidade: num.parse(e['quantidade']),
              valorAdicional: double.parse(e['valorAdicional']),
              nome: e['nome'],
            ),
          ),
        ],
      ));
      quantidadeTotal += num.parse(item['quantidade']);
      precoTotal += double.parse(item['valor']) * num.parse(item['quantidade']);
      item['listaAdicionais'].map((e) {
        precoTotal += double.parse(e['valorAdicional']) * num.parse(e['quantidade']);
      }).toList();
    }

    itensCarrinho = ItensComandaModelo(
      listaComandosPedidos: listaItens,
      quantidadeTotal: quantidadeTotal,
      precoTotal: precoTotal,
    );
    notifyListeners();
  }

  Future<bool> removerComandasPedidos(String idComanda, String idMesa, List<String> listaIdItemComanda) async {
    final res = await _service.removerComandasPedidos(listaIdItemComanda);
    if (res) {
      await listarComandasPedidos(idComanda, idMesa);
    }
    return res;
  }

  Future<bool> inserir(
    tipo,
    idMesa,
    idComanda,
    valor,
    observacaoMesa,
    idProduto,
    quantidade,
    observacao,
    List<AdicionaisModelo> listaAdicionais,
    List<AcompanhamentosModelo> listaAcompanhamentos,
    TamanhosModelo? tamanhoSelecionado,
  ) async {
    final res =
        await _service.inserir(tipo, idMesa, idComanda, valor, observacaoMesa, idProduto, quantidade, observacao, listaAdicionais, listaAcompanhamentos, tamanhoSelecionado);
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
