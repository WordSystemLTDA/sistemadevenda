import 'package:app/src/features/produto/data/services/salvar_produto_service_impl.dart';
import 'package:app/src/features/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:flutter/material.dart';

final ValueNotifier<List<AdicionaisModelo>> listaAdicionais = ValueNotifier([]);

class ProdutoState {
  final SalvarProdutoService _servico = SalvarProdutoService();

  void listarAdicionais(String id) async {
    final res = await _servico.listarAdicionais(id);
    listaAdicionais.value = res;
  }
}
