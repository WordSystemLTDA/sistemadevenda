import 'dart:convert';
import 'dart:io';

import 'package:app/src/features/produto/interactor/services/salvar_produto_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class SalvarProdutoServiceImpl implements SalvarProdutoService {
  final Dio dio;
  SalvarProdutoServiceImpl(this.dio);

  // var usuarioProvider = usuarioProvider.getUsuario();
  // late final empresa = usuarioProvider['empresa'];
  // late final idUsuario = usuarioProvider['id'];

  @override
  Future<bool> inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    const url = '${Apis.baseUrl}pedidos/inserir.php';

    final response = await dio.post(
      url,
      data: jsonEncode({
        'idComanda': idComanda,
        'valor': valor,
        'observacaoMesa': observacaoMesa,
        'idProduto': idProduto,
        'quantidade': quantidade,
        'observacao': observacao,
      }),
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: 'application/json',
      }),
    );

    final Map<dynamic, dynamic> result = response.data;
    final bool sucesso = result['sucesso'];

    if (response.statusCode == 200 && sucesso == true) {
      return sucesso;
    }

    return false;
  }
}
