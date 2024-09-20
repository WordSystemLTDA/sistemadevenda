import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/modelos/tamanhos_modelo.dart';

class ServicoProduto {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoProduto(this.dio, this.usuarioProvedor);
  // final sharedPrefs = SharedPrefsConfig();

  // var usuarioProvider = usuarioProvider.getUsuario();
  // late final empresa = usuarioProvider['empresa'];
  // late final idUsuario = usuarioProvider['id'];

  Future<List<ModeloProduto>> listarPorCategoria(String categoria) async {
    var empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('produtos/listar_por_categoria.php?categoria=$categoria&empresa=$empresa');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<ModeloProduto>.from(response.data.map((elemento) {
          return ModeloProduto.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<List<ModeloProduto>> listarPorNome(String pesquisa) async {
    final response = await dio.cliente.get('produtos/listar.php?pesquisa=$pesquisa');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<ModeloProduto>.from(response.data.map((elemento) {
          return ModeloProduto.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<List<AdicionaisModelo>> listarAdicionais(String id) async {
    final url = '/produtos/listar_adicionais.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<AdicionaisModelo>.from(response.data.map((e) {
        return AdicionaisModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<AcompanhamentosModelo>> listarAcompanhamentos(String id) async {
    final url = '/produtos/listar_acompanhamentos.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<AcompanhamentosModelo>.from(response.data.map((e) {
        return AcompanhamentosModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<TamanhosModelo>> listarTamanhos(String id) async {
    final url = '/produtos/listar_tamanhos.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<TamanhosModelo>.from(response.data.map((e) {
        return TamanhosModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<bool> inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    // const url = '${Apis.baseUrl}pedidos/inserir.php';

    // final response = await dio.post(
    //   url,
    //   data: jsonEncode({
    //     'idComanda': idComanda,
    //     'valor': valor,
    //     'observacaoMesa': observacaoMesa,
    //     'idProduto': idProduto,
    //     'quantidade': quantidade,
    //     'observacao': observacao,
    //   }),
    //   options: Options(headers: {
    //     HttpHeaders.contentTypeHeader: 'application/json',
    //   }),
    // );

    // final Map<dynamic, dynamic> result = response.data;
    // final bool sucesso = result['sucesso'];

    // if (response.statusCode == 200 && sucesso == true) {
    //   return sucesso;
    // }

    return false;
  }
}
