// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

bool _booleano(Object? valor, [bool padrao = false]) {
  if (valor is bool) return valor;
  final texto = (valor ?? '').toString().toLowerCase();
  if (texto == 'true' || texto == '1' || texto == 'sim') return true;
  if (texto == 'false' || texto == '0' || texto == 'nao' || texto == 'não') {
    return false;
  }
  return padrao;
}

class Modelowordtamanhosproduto {
  final String id;
  final String nome;
  final String valor;
  final String foto;
  bool estaSelecionado;
  bool excluir;

  Modelowordtamanhosproduto({
    required this.id,
    required this.nome,
    required this.valor,
    required this.foto,
    required this.estaSelecionado,
    required this.excluir,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
    };
  }

  factory Modelowordtamanhosproduto.fromMap(Map<String, dynamic> map) {
    return Modelowordtamanhosproduto(
      id: map['id']?.toString() ?? '',
      nome: map['nome']?.toString() ?? '',
      valor: map['valor']?.toString() ?? '0',
      foto: map['foto']?.toString() ?? '',
      estaSelecionado: _booleano(map['estaSelecionado']),
      excluir: _booleano(map['excluir']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordtamanhosproduto.fromJson(String source) =>
      Modelowordtamanhosproduto.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
