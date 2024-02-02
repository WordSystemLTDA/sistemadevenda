import 'package:app/src/features/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';
import 'package:flutter/material.dart';

final ValueNotifier categoriaState = ValueNotifier<List<CategoriaModel>>([]);

class CategortiaState {
  final CategoriaServiceImpl _service = CategoriaServiceImpl();

  void listarCategorias() async {
    final res = await _service.listar();
    categoriaState.value = res;
  }
}
