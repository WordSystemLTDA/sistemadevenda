import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/modulos/autenticacao/modelos/cidade_modelo.dart';

class ServicoCidade {
  DioCliente dio;
  ServicoCidade(this.dio);

  Future<List<CidadeModelo>> listar(String? nome) async {
    var url = 'cidade/listar_por_nome.php?nome=$nome';

    final response = await dio.cliente.get(url);

    var jsonData = response.data;

    return List<CidadeModelo>.from(
      jsonData.map((elemento) {
        return CidadeModelo.fromMap(elemento);
      }),
    );
  }
}
