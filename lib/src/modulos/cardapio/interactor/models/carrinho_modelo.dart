import 'dart:convert';

import 'package:app/src/modulos/cardapio/interactor/models/adicional_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/acompanhamentos_modelo.dart';

class CarrinhoModelo {
  final String id;
  final String nome;
  final String foto;
  final double valor;
  num quantidade;
  bool estaExpandido;
  final List<AdicionalModelo> listaAdicionais;
  final List<AcompanhamentosModelo> listaAcompanhamentos;
  final String tamanhoSelecionado;

  CarrinhoModelo({
    required this.id,
    required this.nome,
    required this.foto,
    required this.valor,
    required this.quantidade,
    required this.estaExpandido,
    required this.listaAdicionais,
    required this.listaAcompanhamentos,
    required this.tamanhoSelecionado,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'foto': foto,
      'valor': valor,
      'quantidade': quantidade,
      'estaExpandido': estaExpandido,
      'listaAdicionais': listaAdicionais.map((x) => x.toMap()).toList(),
      'listaAcompanhamentos': listaAcompanhamentos.map((x) => x.toMap()).toList(),
      'tamanhoSelecionado': tamanhoSelecionado,
    };
  }

  factory CarrinhoModelo.fromMap(Map<String, dynamic> map) {
    return CarrinhoModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      foto: map['foto'] as String,
      valor: map['valor'] as double,
      quantidade: map['quantidade'] as num,
      estaExpandido: map['estaExpandido'] as bool,
      listaAdicionais: List<AdicionalModelo>.from(
        (map['listaAdicionais'] as List<dynamic>).map<AdicionalModelo>(
          (x) => AdicionalModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      listaAcompanhamentos: List<AcompanhamentosModelo>.from(
        (map['listaAcompanhamentos'] as List<dynamic>).map<AcompanhamentosModelo>(
          (x) => AcompanhamentosModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      tamanhoSelecionado: map['tamanhoSelecionado'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory CarrinhoModelo.fromJson(String source) => CarrinhoModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
