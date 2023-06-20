class ProdutoModel {
  String id;
  String nome;
  String tamanho;
  String imagem;
  num valor;
  String descricao;

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.tamanho,
    required this.imagem,
    required this.valor,
    required this.descricao,
  });

  ProdutoModel.fromJson(Map<String, dynamic> json)
      : id = json['id'].toString(),
        nome = json['nome'].toString(),
        tamanho = json['tamanho'].toString(),
        valor = json['valor'],
        descricao = json['descricao'],
        imagem = json['imagem'].toString();
}
