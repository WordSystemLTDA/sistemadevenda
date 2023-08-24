import 'dart:convert';
import 'dart:io';

import 'package:app/src/features/produto/interactor/services/salvar_produto_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class SalvarProdutoServiceImpl implements SalvarProdutoService {
  final Dio dio;

  SalvarProdutoServiceImpl(this.dio);

  @override
  Future<bool> inserir(idLugar, tipo, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    var campos = {
      "idLugar": idLugar,
      "tipo": tipo,
      "valor": valor,
      "observacaoMesa": observacaoMesa,
      "idProduto": idProduto,
      "quantidade": quantidade,
      "observacao": observacao,
    };

    final response = await dio.post(
      '${Apis.baseUrl}pedidos/inserir.php',
      data: jsonEncode(campos),
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      }),
    );

    Map result = response.data;
    bool sucesso = result['sucesso'];

    if (response.statusCode == 200 && sucesso == true) {
      return sucesso;
    }

    return false;
  }
}
