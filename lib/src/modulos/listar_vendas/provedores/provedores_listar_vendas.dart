import 'dart:convert';

import 'package:app/src/modulos/listar_vendas/modelos/salvar_listar_vendas_modelo.dart';
import 'package:app/src/modulos/listar_vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<List<SalvarListarVendasModelo>> dados = ValueNotifier([]);

class ProvedoresListarVendas extends ChangeNotifier {
  final ServicosListarVendas servico;

  ProvedoresListarVendas(this.servico);

  void listar() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<dynamic> res = jsonDecode(prefs.getString('listar_vendas') ?? '[]');

    dados.value = List<SalvarListarVendasModelo>.from(res.map((elemento) {
      return SalvarListarVendasModelo.fromMap(elemento);
    }));
    notifyListeners();
  }

  Future<bool> inserir(SalvarListarVendasModelo modelo) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<SalvarListarVendasModelo> dados = List<SalvarListarVendasModelo>.from(jsonDecode(prefs.getString('listar_vendas') ?? '[]').map((elemento) {
      return SalvarListarVendasModelo.fromMap(elemento);
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
