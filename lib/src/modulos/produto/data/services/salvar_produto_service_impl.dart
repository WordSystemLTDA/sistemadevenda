import 'package:app/src/essencial/services/api.dart';
import 'package:app/src/modulos/produto/interactor/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/interactor/modelos/tamanhos_modelo.dart';
import 'package:dio/dio.dart';

class SalvarProdutoService {
  final Dio dio = Dio();
  // final sharedPrefs = SharedPrefsConfig();

  // var usuarioProvider = usuarioProvider.getUsuario();
  // late final empresa = usuarioProvider['empresa'];
  // late final idUsuario = usuarioProvider['id'];

  Future<List<AdicionaisModelo>> listarAdicionais(String id) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/produtos/listar_adicionais.php?produto=$id';

    final response = await dio.get(url);

    if (response.data.isNotEmpty) {
      return List<AdicionaisModelo>.from(response.data.map((e) {
        return AdicionaisModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<AcompanhamentosModelo>> listarAcompanhamentos(String id) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/produtos/listar_acompanhamentos.php?produto=$id';

    final response = await dio.get(url);

    if (response.data.isNotEmpty) {
      return List<AcompanhamentosModelo>.from(response.data.map((e) {
        return AcompanhamentosModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<TamanhosModelo>> listarTamanhos(String id) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/produtos/listar_tamanhos.php?produto=$id';

    final response = await dio.get(url);

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
