import 'dart:convert';

import 'package:app/src/essencial/shared_prefs/modelo_conexao.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfigSharedPreferences {
  static const usuario = 'usuario';
  static const produtosTelaEntrada = 'produtosTelaEntrada';
  static const produtosTelaSaida = 'produtosTelaSaida';
  static const produtosTelaCompra = 'produtosTelaCompra';
  static const produtosTelaPdv = 'produtosTelaPdv';
  static const produtosTelaNfeSaida = 'produtosTelaNfeSaida';
  static const produtosTelaOrcamento = 'produtosTelaOrcamento';
  static const produtosTelaOS = 'produtosTelaOS';
  static const produtosTelaRepresentante = 'produtosTelaRepresentante';
  static const produtosteladevolucao = 'produtosteladevolucao';
  static const produtosTelanfeentrada = 'produtosTelanfeentrada';

  Future<ModeloConexao?> getConexao() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // await prefs.setString(
    //   'conexao',
    //   jsonEncode({
    //     'tipoConexao': 'localhost',
    //     'servidor': '192.168.2.117',
    //   }),
    // );

    var conexao = prefs.getString('conexao');
    if (conexao == null) return null;

    return ModeloConexao.fromMap(jsonDecode(conexao));
  }
}
