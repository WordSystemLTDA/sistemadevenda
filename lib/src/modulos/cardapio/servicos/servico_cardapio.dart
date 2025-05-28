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

  Future<Modeloworddadoscardapio> listarPorId(String id, TipoCardapio tipo, String mostraritens, {String? codigoQrcode}) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;

    final response =
        await dio.cliente.get('cardapio/listar_por_id.php?id=$id&codigoQrcode=$codigoQrcode&empresa=$empresa&id_usuario=$idUsuario&tipo=${tipo.nome}&mostrar_itens=$mostraritens');

    if (response.statusCode == 200) {
      return Modeloworddadoscardapio.fromMap(response.data);
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }

  Future<({String id, String codigo, String nome, String idComandaPedido, bool ocupado, bool sucesso, String idCliente, bool fechamento})> listarIdCodigoQrcode(
      TipoCardapio tipo, String? codigoQrcode) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.get('cardapio/listar_id_por_codigo.php?codigoQrcode=$codigoQrcode&empresa=$empresa&id_usuario=$idUsuario&tipo=${tipo.nome}');

    var jsonData = response.data;
    bool ocupado = jsonData['ocupado'];
    bool sucesso = jsonData['sucesso'];
    String id = jsonData['id'];
    String codigo = jsonData['codigo'];
    String nome = jsonData['nome'];
    String idComandaPedido = jsonData['idComandaPedido'];
    String idCliente = jsonData['idCliente'];
    bool fechamento = jsonData['fechamento'];

    return (
      id: id,
      codigo: codigo,
      nome: nome,
      idComandaPedido: idComandaPedido,
      ocupado: ocupado,
      sucesso: sucesso,
      idCliente: idCliente,
      fechamento: fechamento,
    );
  }

  Future<(bool, String)> inserirProdutosComanda(List<Modelowordprodutos> produtos, String idMesa, String idComandaPedido, String idComanda, String idcliente) async {
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

  Future<(bool, String)> inserirProdutosMesa(List<Modelowordprodutos> produtos, String idMesa, String idComandaPedido, String idcliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    try {
      var campos = {
        // 'produtos': produtos.map((e) => e.toMap()).toList(),
        'produtos': produtos,
        "id_comanda_pedido": idComandaPedido,
        "id_mesa": idMesa,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'id_cliente': idcliente,
      };

      // print(produtos[0].opcoesPacotesListaFinal!.where((e) => e.tipo == 2).map((e) => e.toMap()).toList());
      // return (false, '');

      var response = await dio.cliente.post('mesas/inserir_produtos.php', data: jsonEncode(campos));

      // print(response.data);
      // return (false, '');

      var jsonData = response.data;
      bool sucesso = jsonData['sucesso'];
      String mensagem = jsonData['mensagem'];

      return (sucesso, mensagem);
    } on DioException catch (e) {
      // print(e);

      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return (false, 'Erro');
    }
  }

  Future<({bool sucesso, String mensagem})> fecharAbrirComanda(String idComandaPedido, String status) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    try {
      var campos = {
        "id_comanda_pedido": idComandaPedido,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'status': status,
      };

      var response = await dio.cliente.post('comandas/fechar_abrir_comanda.php', data: jsonEncode(campos));

      var jsonData = response.data;
      bool sucesso = jsonData['sucesso'];
      String mensagem = jsonData['mensagem'];

      return (sucesso: sucesso, mensagem: mensagem);
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return (sucesso: false, mensagem: 'Erro');
    }
  }
}
