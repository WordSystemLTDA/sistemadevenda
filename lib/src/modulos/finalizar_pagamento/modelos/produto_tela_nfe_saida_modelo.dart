// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ProdutoTelaNfeSaidaModelo {
  final String id;
  final String idItem;
  final String codigo;
  final String codigoDeBarras;
  final String valorUnitario;
  final String totalVenda;
  final String nome;
  final String estoque;
  final String? valordoimposto;
  String? cstCsosnProduto;
  String? cfopProduto;
  String? ncmProduto;
  String? valorCusto;
  String? valorCustoTotal;
  final String foto;
  final String tipoDeEstoque;
  final bool editou;
  final bool novo;
  int quantidade;

  ProdutoTelaNfeSaidaModelo({
    required this.id,
    required this.idItem,
    required this.codigo,
    required this.codigoDeBarras,
    required this.valorUnitario,
    required this.totalVenda,
    required this.nome,
    required this.estoque,
    this.valordoimposto,
    this.cstCsosnProduto,
    this.cfopProduto,
    this.ncmProduto,
    this.valorCusto,
    this.valorCustoTotal,
    required this.foto,
    required this.tipoDeEstoque,
    required this.editou,
    required this.novo,
    required this.quantidade,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'idItem': idItem,
      'codigo': codigo,
      'codigoDeBarras': codigoDeBarras,
      'valorUnitario': valorUnitario,
      'totalVenda': totalVenda,
      'nome': nome,
      'estoque': estoque,
      'valordoimposto': valordoimposto,
      'cstCsosnProduto': cstCsosnProduto,
      'cfopProduto': cfopProduto,
      'ncmProduto': ncmProduto,
      'valorCusto': valorCusto,
      'foto': foto,
      'tipoDeEstoque': tipoDeEstoque,
      'editou': editou,
      'novo': novo,
      'quantidade': quantidade,
    };
  }

  factory ProdutoTelaNfeSaidaModelo.fromMap(Map<String, dynamic> map) {
    return ProdutoTelaNfeSaidaModelo(
      id: map['id'] as String,
      idItem: map['idItem'] as String,
      codigo: map['codigo'] as String,
      codigoDeBarras: map['codigoDeBarras'] as String,
      valorUnitario: map['valorUnitario'] as String,
      totalVenda: map['totalVenda'] as String,
      nome: map['nome'] as String,
      estoque: map['estoque'] as String,
      valordoimposto: map['valordoimposto'] != null ? map['valordoimposto'] as String : null,
      cstCsosnProduto: map['cstCsosnProduto'] != null ? map['cstCsosnProduto'] as String : null,
      cfopProduto: map['cfopProduto'] != null ? map['cfopProduto'] as String : null,
      ncmProduto: map['ncmProduto'] != null ? map['ncmProduto'] as String : null,
      valorCusto: map['valorCusto'] != null ? map['valorCusto'] as String : null,
      foto: map['foto'] as String,
      tipoDeEstoque: map['tipoDeEstoque'] as String,
      editou: map['editou'] as bool,
      novo: map['novo'] as bool,
      quantidade: map['quantidade'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProdutoTelaNfeSaidaModelo.fromJson(String source) => ProdutoTelaNfeSaidaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
