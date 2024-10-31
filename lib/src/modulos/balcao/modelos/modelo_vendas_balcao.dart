// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloVendasBalcao {
  final String id;
  final String nomecliente;
  final String numeropedido;
  final String quantidadeProdutos;
  final String pagamento;
  final String subtotal;
  final String status;
  final String nomeusuariocompleto;
  final String nomeusuario;
  final String dataHora;
  final String valorTotalF;
  final int tamanhoLista;
  final String tipodeentrega;
  final String nomeEmpresa;

  ModeloVendasBalcao({
    required this.id,
    required this.nomecliente,
    required this.numeropedido,
    required this.quantidadeProdutos,
    required this.pagamento,
    required this.subtotal,
    required this.status,
    required this.nomeusuariocompleto,
    required this.nomeusuario,
    required this.dataHora,
    required this.valorTotalF,
    required this.tamanhoLista,
    required this.tipodeentrega,
    required this.nomeEmpresa,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nomecliente': nomecliente,
      'numeropedido': numeropedido,
      'quantidadeProdutos': quantidadeProdutos,
      'pagamento': pagamento,
      'subtotal': subtotal,
      'status': status,
      'nomeusuariocompleto': nomeusuariocompleto,
      'nomeusuario': nomeusuario,
      'dataHora': dataHora,
      'valorTotalF': valorTotalF,
      'tamanhoLista': tamanhoLista,
      'tipodeentrega': tipodeentrega,
      'nomeEmpresa': nomeEmpresa,
    };
  }

  factory ModeloVendasBalcao.fromMap(Map<String, dynamic> map) {
    return ModeloVendasBalcao(
      id: map['id'] as String,
      nomecliente: map['nomecliente'] as String,
      numeropedido: map['numeropedido'] as String,
      quantidadeProdutos: map['quantidadeProdutos'] as String,
      pagamento: map['pagamento'] as String,
      subtotal: map['subtotal'] as String,
      status: map['status'] as String,
      nomeusuariocompleto: map['nomeusuariocompleto'] as String,
      nomeusuario: map['nomeusuario'] as String,
      dataHora: map['dataHora'] as String,
      valorTotalF: map['valorTotalF'] as String,
      tamanhoLista: map['tamanhoLista'] as int,
      tipodeentrega: map['tipodeentrega'] as String,
      nomeEmpresa: map['nomeEmpresa'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloVendasBalcao.fromJson(String source) => ModeloVendasBalcao.fromMap(json.decode(source) as Map<String, dynamic>);
}
