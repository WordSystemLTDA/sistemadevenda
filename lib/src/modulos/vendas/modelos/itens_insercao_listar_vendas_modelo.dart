import 'dart:convert';

// É usado para Clientes, Natureza, Vendedor, transportadoras e Frete

class ItensInsercaoListarVendasModelo {
  final String id;
  final String nome;
  final String? codigo; // Somente Frete utiliza

  ItensInsercaoListarVendasModelo({
    required this.id,
    required this.nome,
    this.codigo,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'codigo': codigo,
    };
  }

  factory ItensInsercaoListarVendasModelo.fromMap(Map<String, dynamic> map) {
    return ItensInsercaoListarVendasModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      codigo: map['codigo'] != null ? map['codigo'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItensInsercaoListarVendasModelo.fromJson(String source) =>
      ItensInsercaoListarVendasModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
