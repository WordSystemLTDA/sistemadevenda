import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoCardapio {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoCardapio(this.dio, this.usuarioProvedor);

  Future<Modeloworddadoscardapio> listarPorId(String id, TipoCardapio tipo) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('cardapio/listar_por_id.php?id=$id&empresa=$empresa&tipo=${tipo.nome}');

    if (response.statusCode == 200) {
      return Modeloworddadoscardapio.fromMap(response.data);
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }

  Future<(bool, String)> inserirProdutosComanda(List<ModeloProduto> produtos, String idMesa, String idComandaPedido, String idComanda, String idcliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    try {
      var campos = {
        'produtos': produtos,
        "id_comanda_pedido": idComandaPedido,
        "id_comanda": idComanda,
        "id_mesa": idMesa,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'id_cliente': idcliente,
      };

      var response = await dio.cliente.post('comandas/inserir_produtos.php', data: jsonEncode(campos));

      var jsonData = response.data;
      bool sucesso = jsonData['sucesso'];
      String mensagem = jsonData['mensagem'];

      return (sucesso, mensagem);
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return (false, 'Erro');
    }
  }
}
