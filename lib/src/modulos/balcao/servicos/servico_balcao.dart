import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_enderecos_clientes.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_historico_pagamentos.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_lista_financeiro_venda.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoBalcao {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoBalcao(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'balcao';

  Future<List<ModeloVendasBalcao>> listar(int pagina, int linhasPorPagina, String pesquisa, String dataInicio, String dataFim, String hora) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final id = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.post(
        '/$caminhoAPI/listar.php?id_empresa=$empresa&id_usuario=$id&pagina=$pagina&linhasPorPagina=$linhasPorPagina&pesquisa=$pesquisa&dataInicio=$dataInicio&dataFim=$dataFim&hora=$hora');

    if (response.data.isNotEmpty) {
      return List<ModeloVendasBalcao>.from(response.data.map((elemento) {
        return ModeloVendasBalcao.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<RetornoListarPorIdBalcao> listarPorId(String idVenda) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    try {
      var response = await dio.cliente.get('$caminhoAPI/listar_por_id.php?id_empresa=$idEmpresa&id_usuario=$idUsuario&id=$idVenda');

      var jsonData = response.data;
      var dados = jsonData['dados'];

      return RetornoListarPorIdBalcao.fromMap(dados);
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return RetornoListarPorIdBalcao.fromMap({});
    }
  }

  Future<List<ModeloHistoricoPagamentos>> listarHistoricoPagamentos(String id, TipoCardapio tipo) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.get('balcao/listar_historico_pagamentos.php?id=$id&empresa=$idEmpresa&id_usuario=$idUsuario');

    var jsonData = response.data;
    var produtos = List<ModeloHistoricoPagamentos>.from(jsonData.map((elemento) {
      return ModeloHistoricoPagamentos.fromMap(elemento);
    }));

    return produtos;
  }

  Future<List<Modelolistafinanceirovenda>> listarFinanceiroVenda(String idVenda) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    var response = await dio.cliente.get('$caminhoAPI/listar_financeiro_venda.php?id_empresa=$idEmpresa&id_usuario=$idUsuario&id=$idVenda');

    var jsonData = response.data;
    var dados = jsonData['dados'];

    return List<Modelolistafinanceirovenda>.from(dados.map((elemento) {
      return Modelolistafinanceirovenda.fromMap(elemento);
    }));
  }

  Future<({bool sucesso, String mensagem})> excluir(String id, String justificativaCancelamento) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.post(
      '$caminhoAPI/excluir.php',
      data: jsonEncode({
        'id_empresa': idEmpresa,
        'id_usuario': idUsuario,
        'nivel_usuario': usuarioProvedor.usuario?.nivel,
        'usuario_adm': '',
        'senha_adm': '',
        'id-excluir': id,
        'justificativa_cancelamento': justificativaCancelamento,
      }),
    );

    var jsonData = response.data;

    bool sucesso = jsonData['sucesso'];
    String mensagem = jsonData['mensagem'];

    return (sucesso: sucesso, mensagem: mensagem);
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';
    final response = await dio.cliente.get(url);

    return response.data;
  }

  Future<List<Modelowordenderecosclientes>> listarEnderecosClientes(String pesquisa, String idCliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.post('enderecos_clientes/listar_por_cliente.php?empresa=$idEmpresa&id_usuario=$idUsuario&pesquisa=$pesquisa&cliente=$idCliente');
    var jsonData = response.data;

    dynamic dados = jsonData;

    return List<Modelowordenderecosclientes>.from(dados.map((elemento) {
      return Modelowordenderecosclientes.fromMap(elemento);
    }));
  }

  Future<({bool sucesso, String idvenda})> inserir(String idCliente, String obs) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final usuario = usuarioProvedor.usuario!.id;

    const url = 'balcao/inserir.php';
    final response = await dio.cliente.post(
      url,
      data: {
        'idCliente': idCliente,
        'obs': obs,
        'empresa': empresa,
        'usuario': usuario,
      },
    );

    bool sucesso = response.data['sucesso'];
    String idvenda = response.data['idvenda'];

    return (sucesso: sucesso, idvenda: idvenda);
  }
}
