import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:dio/dio.dart';

class ServicosCategoria {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicosCategoria(this.dio, this.usuarioProvedor);

  Future<List<ModeloCategoria>> listar({bool cachePrimeiro = false}) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final filtroPersonalizados = usuarioProvedor
        .configbigchef?.mostrarApenasProdutosAtivoVendaHabilitado;

    final parametroPersonalizados = filtroPersonalizados == true
        ? '&mostrar_apenas_produtos_ativo_venda=Sim'
        : '';
    final response = await dio.cliente
        .get('categorias/listar.php?empresa=$empresa$parametroPersonalizados',
            options: Options(extra: {
              if (cachePrimeiro) 'cachePrimeiro': true,
            }));

    if (response.statusCode == 200) {
      final categorias = List<ModeloCategoria>.from(
        response.data.map((elemento) {
          return ModeloCategoria.fromMap(elemento);
        }),
      );
      return categorias
          .where((categoria) =>
              categoria.id == '0' ||
              (int.tryParse(categoria.quantidadeProdutos) ?? 0) > 0)
          .toList(growable: false);
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
