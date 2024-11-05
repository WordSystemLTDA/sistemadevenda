// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloProdutosListaVenda {
  final String? id;
  final String codigo;
  final String nomeProduto;
  final String separadorGrade;
  final String tamanhoDaGrade;
  final String unidadeMedida;
  String quantidade;
  String valorUnitarioF;
  final String valorTotalItemF;
  final String produto;
  final String idItem;
  String valorUnitario;
  final num valorTotalItem;
  final String valorProduto;
  final String totalVenda;
  final String valorVenda;
  final String valorTotal;
  final String estoque;
  final String valordoimposto;
  final String idGrade;
  String cstCsosnProduto;
  String cfopProduto;
  String ncmProduto;
  final String valorCusto;
  final String valorCustoTotal;
  final String comissao;
  final String? permissaoCompra;
  final String? tamanhoGrade;
  final String habilitarservico;
  bool? editou;
  bool? novo;
  final int? tamanhoLista;
  final String? totaldavenda;

  ModeloProdutosListaVenda({
    this.id,
    required this.codigo,
    required this.nomeProduto,
    required this.separadorGrade,
    required this.tamanhoDaGrade,
    required this.unidadeMedida,
    required this.quantidade,
    required this.valorUnitarioF,
    required this.valorTotalItemF,
    required this.produto,
    required this.idItem,
    required this.valorUnitario,
    required this.valorTotalItem,
    required this.valorProduto,
    required this.totalVenda,
    required this.valorVenda,
    required this.valorTotal,
    required this.estoque,
    required this.valordoimposto,
    required this.idGrade,
    required this.cstCsosnProduto,
    required this.cfopProduto,
    required this.ncmProduto,
    required this.valorCusto,
    required this.valorCustoTotal,
    required this.comissao,
    required this.permissaoCompra,
    this.tamanhoGrade,
    required this.habilitarservico,
    this.editou = false,
    this.novo = true,
    this.tamanhoLista,
    this.totaldavenda,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'codigo': codigo,
      'nomeProduto': nomeProduto,
      'separadorGrade': separadorGrade,
      'tamanhoDaGrade': tamanhoDaGrade,
      'unidadeMedida': unidadeMedida,
      'quantidade': quantidade,
      'valorUnitarioF': valorUnitarioF,
      'valorTotalItemF': valorTotalItemF,
      'produto': produto,
      'idItem': idItem,
      'valorUnitario': valorUnitario,
      'valorTotalItem': valorTotalItem,
      'valorProduto': valorProduto,
      'totalVenda': totalVenda,
      'valorVenda': valorVenda,
      'valorTotal': valorTotal,
      'estoque': estoque,
      'valordoimposto': valordoimposto,
      'idGrade': idGrade,
      'cstCsosnProduto': cstCsosnProduto,
      'cfopProduto': cfopProduto,
      'ncmProduto': ncmProduto,
      'valorCusto': valorCusto,
      'valorCustoTotal': valorCustoTotal,
      'comissao': comissao,
      'permissaoCompra': permissaoCompra,
      'tamanhoGrade': tamanhoGrade,
      'habilitarservico': habilitarservico,
      'editou': editou,
      'novo': novo,
      'tamanhoLista': tamanhoLista,
      'totaldavenda': totaldavenda,
    };
  }

  factory ModeloProdutosListaVenda.fromMap(Map<String, dynamic> map) {
    return ModeloProdutosListaVenda(
      id: map['id'] != null ? map['id'] as String : null,
      codigo: map['codigo'] as String,
      nomeProduto: map['nomeProduto'] as String,
      separadorGrade: map['separadorGrade'] as String,
      tamanhoDaGrade: map['tamanhoDaGrade'] as String,
      unidadeMedida: map['unidadeMedida'] as String,
      quantidade: map['quantidade'] as String,
      valorUnitarioF: map['valorUnitarioF'] as String,
      valorTotalItemF: map['valorTotalItemF'] as String,
      produto: map['produto'] as String,
      idItem: map['idItem'] as String,
      valorUnitario: map['valorUnitario'] as String,
      valorTotalItem: map['valorTotalItem'] as num,
      valorProduto: map['valorProduto'] as String,
      totalVenda: map['totalVenda'] as String,
      valorVenda: map['valorVenda'] as String,
      valorTotal: map['valorTotal'] as String,
      estoque: map['estoque'] as String,
      valordoimposto: map['valordoimposto'] as String,
      idGrade: map['idGrade'] as String,
      cstCsosnProduto: map['cstCsosnProduto'] as String,
      cfopProduto: map['cfopProduto'] as String,
      ncmProduto: map['ncmProduto'] as String,
      valorCusto: map['valorCusto'] as String,
      valorCustoTotal: map['valorCustoTotal'] as String,
      comissao: map['comissao'] as String,
      permissaoCompra: map['permissaoCompra'] != null ? map['permissaoCompra'] as String : null,
      tamanhoGrade: map['tamanhoGrade'] != null ? map['tamanhoGrade'] as String : null,
      habilitarservico: map['habilitarservico'] as String,
      editou: map['editou'] != null ? map['editou'] as bool : null,
      novo: map['novo'] != null ? map['novo'] as bool : null,
      tamanhoLista: map['tamanhoLista'] != null ? map['tamanhoLista'] as int : null,
      totaldavenda: map['totaldavenda'] != null ? map['totaldavenda'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloProdutosListaVenda.fromJson(String source) => ModeloProdutosListaVenda.fromMap(json.decode(source) as Map<String, dynamic>);
}
