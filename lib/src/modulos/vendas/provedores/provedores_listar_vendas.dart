import 'dart:convert';

import 'package:app/src/modulos/vendas/modelos/salvar_vendas_modelo.dart';
import 'package:app/src/modulos/vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<List<SalvarVendasModelo>> dados = ValueNotifier([]);

class ProvedoresListarVendas extends ChangeNotifier {
  final ServicosListarVendas servico;

  ProvedoresListarVendas(this.servico);

  void listar() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<dynamic> res = jsonDecode(prefs.getString('listar_vendas') ?? '[]');

    dados.value = List<SalvarVendasModelo>.from(res.map((elemento) {
      return SalvarVendasModelo.fromMap(elemento);
    }));
    notifyListeners();
  }

  Future<bool> inserir(SalvarVendasModelo modelo) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<SalvarVendasModelo> dados = List<SalvarVendasModelo>.from(jsonDecode(prefs.getString('listar_vendas') ?? '[]').map((elemento) {
      return SalvarVendasModelo.fromMap(elemento);
    }));

    final res = await prefs.setString(
      'listar_vendas',
      jsonEncode(
        [
          ...dados.map((e) => e.toMap()),
          {...modelo.toMap()}
        ],
      ),
    );

    return res;
  }
}
