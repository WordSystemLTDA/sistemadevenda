import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ModeloHistoricoPagamentos {
  String id;
  String valor;
  String pagamento;
  String somaValorHistorico;

  ModeloHistoricoPagamentos({
    required this.id,
    required this.valor,
    required this.pagamento,
    required this.somaValorHistorico,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'valor': valor,
      'pagamento': pagamento,
      'somaValorHistorico': somaValorHistorico,
    };
  }

  factory ModeloHistoricoPagamentos.fromMap(Map<String, dynamic> map) {
    return ModeloHistoricoPagamentos(
      id: map['id'] as String,
      valor: map['valor'] as String,
      pagamento: map['pagamento'] as String,
      somaValorHistorico: map['somaValorHistorico'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloHistoricoPagamentos.fromJson(String source) => ModeloHistoricoPagamentos.fromMap(json.decode(source) as Map<String, dynamic>);
}
