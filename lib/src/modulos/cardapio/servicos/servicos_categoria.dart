import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/categoria_model.dart';

class ServicosCategoria {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicosCategoria(this.dio, this.usuarioProvedor);

  Future<List<CategoriaModel>> listar() async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('categorias/listar.php?empresa=$empresa');

    if (response.statusCode == 200) {
      return List<CategoriaModel>.from(
        response.data.map((elemento) {
          return CategoriaModel.fromMap(elemento);
        }),
      );
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
