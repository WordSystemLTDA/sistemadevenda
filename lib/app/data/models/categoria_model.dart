class CategoriaModel {
  String id;
  String nomeCategoria;

  CategoriaModel({
    required this.id,
    required this.nomeCategoria,
  });

  CategoriaModel.fromJson(Map<String, dynamic> json)
      : id = json['id'].toString(),
        nomeCategoria = json['nomeCategoria'].toString();
}
