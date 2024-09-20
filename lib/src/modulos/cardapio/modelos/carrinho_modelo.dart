// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/adicional_modelo.dart';
import 'package:app/src/modulos/produto/modelos/acompanhamentos_modelo.dart';

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
  String? tipo;
  String? idMesa;
  String? idComanda;
  String? observacaoMesa;
  String? idProduto;
  String? observacao;
  String? idUsuario;
  String? empresa;

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
    this.tipo,
    this.idMesa,
    this.idComanda,
    this.observacaoMesa,
    this.idProduto,
    this.observacao,
    this.idUsuario,
    this.empresa,
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
      'tipo': tipo,
      'idMesa': idMesa,
      'idComanda': idComanda,
      'observacaoMesa': observacaoMesa,
      'idProduto': idProduto,
      'observacao': observacao,
      'idUsuario': idUsuario,
      'empresa': empresa,
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
      tipo: map['tipo'] != null ? map['tipo'] as String : null,
      idMesa: map['idMesa'] != null ? map['idMesa'] as String : null,
      idComanda: map['idComanda'] != null ? map['idComanda'] as String : null,
      observacaoMesa: map['observacaoMesa'] != null ? map['observacaoMesa'] as String : null,
      idProduto: map['idProduto'] != null ? map['idProduto'] as String : null,
      observacao: map['observacao'] != null ? map['observacao'] as String : null,
      idUsuario: map['idUsuario'] != null ? map['idUsuario'] as String : null,
      empresa: map['empresa'] != null ? map['empresa'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory CarrinhoModelo.fromJson(String source) => CarrinhoModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
