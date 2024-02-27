import 'dart:io';
import 'package:app/src/features/produto/interactor/modelos/adicionais_modelo.dart';
import 'package:app/src/shared/services/api.dart';
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
    final url = '${conexao['servidor']}/produtos/listar_adicionais.php?id=$id';

    final response = await dio.get(
      url,
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      }),
    );

    final dados = response.data;

    if (dados.isNotEmpty) {
      return [
        ...dados.map(
          (e) => AdicionaisModelo(
            id: e['id'],
            nome: e['nome'],
            valor: e['valor'],
            foto: e['foto'],
            quantidade: 1,
            estaSelecionado: false,
          ),
        ),
      ];
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
