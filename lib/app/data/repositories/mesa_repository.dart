import 'dart:convert';

import 'package:http/http.dart' as http;

class MesaRepository {
  Future<Map<String, dynamic>> listar() async {
    final response = await http.get(
      Uri.parse('http://10.1.1.15/api_restaurantes/mesas/listar.php'),
    );

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        final json = jsonDecode(response.body);

        // return Map<dynamic, dynamic>.from(json.map((elemento) {
        //   return MesasModel.fromJson(elemento);
        // }));

        return json;

        // return List.from(json).map((x) => MesasModel.fromJson(Map.from(x)));
      } else {
        return {};
      }
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
