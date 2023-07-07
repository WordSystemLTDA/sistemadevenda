class PedidoModel {
  String id;

  PedidoModel({
    required this.id,
  });

  PedidoModel.fromJson(Map<String, dynamic> json) : id = json['id'].toString();
}
