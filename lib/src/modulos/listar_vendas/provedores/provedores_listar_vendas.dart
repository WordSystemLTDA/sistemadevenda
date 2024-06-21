import 'dart:convert';

import 'package:app/src/modulos/listar_vendas/modelos/salvar_listar_vendas_modelo.dart';
import 'package:app/src/modulos/listar_vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final ValueNotifier<List<SalvarListarVendasModelo>> dados = ValueNotifier([]);

class ProvedoresListarVendas extends ChangeNotifier {
  final ServicosListarVendas _service;

  ProvedoresListarVendas(this._service);

  // List<SalvarListarVendasModelo> dados = [];

  // void listar(String pesquisa, {String dataInicial = '', String dataFinal = ''}) async {
  //   dados = await _service.listar(pesquisa, dataInicial, dataFinal);
  //   notifyListeners();
  // }

  void listar() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<dynamic> res = jsonDecode(prefs.getString('listar_vendas') ?? '[]');

    print(res);

    dados.value = List<SalvarListarVendasModelo>.from(res.map((elemento) {
      return SalvarListarVendasModelo.fromMap(elemento);
    }));
    notifyListeners();
  }

  Future<bool> inserir(SalvarListarVendasModelo modelo) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<SalvarListarVendasModelo> dados =
        List<SalvarListarVendasModelo>.from(jsonDecode(prefs.getString('listar_vendas') ?? '[]').map((elemento) {
      return SalvarListarVendasModelo.fromMap(elemento);
    }));

    // if (podeRemover) {
    //   for (int index = 0; index < dados.length; index++) {
    //     final item = dados[index];

    //     if (item.id == modelo.id) {
    //       final res = await prefs.setString(
    //         'carrinho',
    //         jsonEncode(
    //           [
    //             ...dados.where((e) => e.id != item.id).map((e) => e.toMap()),
    //           ],
    //         ),
    //       );

    //       // buscarQuantDoCarrinho();
    //       // listarIdsQueEstaNoCarrinho();

    //       return res;
    //     }
    //   }
    // }

    final res = await prefs.setString(
      'listar_vendas',
      jsonEncode(
        [
          ...dados.map((e) => e.toMap()),
          {...modelo.toMap()}
        ],
      ),
    );

    // buscarQuantDoCarrinho();
    // listarIdsQueEstaNoCarrinho();

    return res;
  }
}
