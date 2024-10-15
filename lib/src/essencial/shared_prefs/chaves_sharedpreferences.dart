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

    // prefs.remove('conexao');
    var conexao = prefs.getString('conexao');

    if (conexao == null) {
      await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': 'online',
          'servidor': '192.168.2.115',
          'porta': '9980',
        }),
      );

      return ModeloConexao.fromMap({
        'tipoConexao': 'online',
        'servidor': '192.168.2.115',
        'porta': '9980',
      });
    }

    return ModeloConexao.fromMap(jsonDecode(conexao));
  }
}
