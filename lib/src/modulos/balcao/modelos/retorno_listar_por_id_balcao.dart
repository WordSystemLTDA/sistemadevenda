// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/balcao/modelos/informacoes_retorno_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class RetornoListarPorIdBalcao {
  List<Modelowordprodutos> produtos;
  InformacoesRetornoModelo informacoes;

  RetornoListarPorIdBalcao({
    required this.produtos,
    required this.informacoes,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'produtos': produtos.map((x) => x.toMap()).toList(),
      'informacoes': informacoes.toMap(),
    };
  }

  factory RetornoListarPorIdBalcao.fromMap(Map<String, dynamic> map) {
    return RetornoListarPorIdBalcao(
      produtos: List<Modelowordprodutos>.from(
        (map['produtos'] as List<dynamic>).map<Modelowordprodutos>(
          (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
        ),
      ),
      informacoes: InformacoesRetornoModelo.fromMap(map['informacoes'] as Map<String, dynamic>),
    );
  }

  String toJson() => json.encode(toMap());

  factory RetornoListarPorIdBalcao.fromJson(String source) => RetornoListarPorIdBalcao.fromMap(json.decode(source) as Map<String, dynamic>);
}
