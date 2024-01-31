import 'package:app/src/features/cardapio/data/services/itens_comanda_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/models/item_Comanda_modelo.dart';
import 'package:app/src/features/cardapio/interactor/models/itens_comanda_modelo.dart';
import 'package:flutter/material.dart';

final ValueNotifier itensComandaState = ValueNotifier(ItensComandaModelo(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0));

class ItensComandaState {
  final ItensComandaServiceImpl _service = ItensComandaServiceImpl();

  Future<dynamic> listarComandasPedidos(String idComanda) async {
    List<dynamic> listaComandosPedidos = await _service.listarComandasPedidos(idComanda);

    List<ItemComandaModelo> listaItens = [];
    num quantidadeTotal = 0;
    double precoTotal = 0;

    for (int index = 0; index < listaComandosPedidos.length; index++) {
      final item = listaComandosPedidos[index];

      listaItens.add(ItemComandaModelo(
        id: item['id'],
        nome: item['nome'],
        foto: item['foto'],
        valor: double.parse(item['valor']),
        quantidade: num.parse(item['quantidade']),
      ));
      quantidadeTotal += num.parse(item['quantidade']);
      precoTotal += double.parse(item['valor']) * num.parse(item['quantidade']);
    }

    itensComandaState.value = ItensComandaModelo(
      listaComandosPedidos: listaItens,
      quantidadeTotal: quantidadeTotal,
      precoTotal: precoTotal,
    );
  }

  Future<dynamic> removerComandasPedidos(String idComanda, String idItemComanda) async {
    final res = await _service.removerComandasPedidos(idItemComanda);
    if (res) {
      await listarComandasPedidos(idComanda);
    }
    return res;
  }

  Future<dynamic> inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    final res = await _service.inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao);
    if (res) {
      await listarComandasPedidos(idComanda);
    }
    return res;
  }
}
