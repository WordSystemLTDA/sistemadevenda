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
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';

class ServicoBalcao {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoBalcao(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'balcao';

  Future<List<ModeloVendasBalcao>> listar(int pagina, int linhasPorPagina, String pesquisa, String dataInicio, String dataFim, String hora) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final id = usuarioProvedor.usuario!.id;

    List<dynamic> lista = [];
    try {
      final response = await dio.cliente.post('/$caminhoAPI/listar.php', queryParameters: {
      'id_empresa': empresa,
      'id_usuario': id,
      'pagina': pagina,
      'linhasPorPagina': linhasPorPagina,
      'pesquisa': pesquisa,
      'dataInicio': dataInicio,
      'dataFim': dataFim,
      'hora': hora,
      });
      lista = List<dynamic>.from(response.data);
    } on DioException catch (e) {
      if (!CacheConsultas.falhaDeConexao(e) || Sincronizador.instancia == null) rethrow;
    }
    final vendas = lista.map((e) => ModeloVendasBalcao.fromMap(e)).toList();
    final sync = Sincronizador.instancia;
    if (sync != null && pagina == 1) {
      final pendentes = await sync.banco.operacoes(sync.escopo);
      for (final op in pendentes.where((op) => op['acao'] == 'venda')) {
        final dados = AtendimentosLocais.dados(op);
        if (dados['id_venda_origem'] != null) continue;
        final data = DateTime.fromMillisecondsSinceEpoch(op['criado'] as int);
        final dia = data.toIso8601String().substring(0, 10);
        if (dia.compareTo(dataInicio) < 0 || dia.compareTo(dataFim) > 0) continue;
        final cliente = await AtendimentosLocais(sync.banco, sync.escopo).nomeCliente(dados['cliente']?.toString() ?? '0');
        final obs = dados['obs']?.toString() ?? '';
        final nome = cliente.isEmpty ? (obs.isEmpty ? 'Sem Cliente' : obs) : cliente;
        if (pesquisa.isNotEmpty && !nome.toLowerCase().contains(pesquisa.toLowerCase())) continue;
        final resposta = AtendimentosLocais.recibo(op);
        if (vendas.any((v) => v.id == resposta['idVenda'])) continue;
        vendas.insert(0, ModeloVendasBalcao(
          id: op['atendimento'] as String, nomecliente: nome,
          numeropedido: resposta['numeroPedido']?.toString() ?? '',
          quantidadeProdutos: (dados['produtos'] as List? ?? []).length.toString(),
          pagamento: '', subtotal: dados['subTotal'].toString(),
          status: 'Aguardando envio', nomeusuariocompleto: usuarioProvedor.usuario?.nome ?? '',
          nomeusuario: usuarioProvedor.usuario?.nome ?? '', dataHora: data.toIso8601String(),
          valorTotalF: dados['subTotal'].toString(), tamanhoLista: 1,
          idtipodeentrega: dados['tipodeentrega']?.toString() ?? '', tipodeentrega: '',
          nomeEmpresa: usuarioProvedor.usuario?.nomeEmpresa ?? '', observacaoDoPedido: obs,
        ));
      }
    }
    return vendas;
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
    final sync = Sincronizador.instancia;
    if (sync != null && id.startsWith('venda-local:')) {
      final operacoes = await sync.banco.db.query('operacoes',
          where: "escopo = ? AND atendimento = ? AND acao = 'venda' AND estado <> 'arquivado'",
          whereArgs: [sync.escopo, id], orderBy: 'criado, rowid');
      final total = operacoes.fold<double>(0, (soma, op) => soma +
          (double.tryParse(AtendimentosLocais.dados(op)['valor_lancamento'].toString()) ?? 0));
      return operacoes.map((op) {
        final dados = AtendimentosLocais.dados(op);
        return ModeloHistoricoPagamentos(id: op['id'] as String,
            valor: dados['valor_lancamento'].toString(), pagamento: 'Pagamento salvo',
            somaValorHistorico: total.toStringAsFixed(2));
      }).toList();
    }
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

    var response =
        await dio.cliente.post('enderecos_clientes/listar_por_cliente.php?empresa=$idEmpresa&id_usuario=$idUsuario&pesquisa=$pesquisa&cliente=$idCliente');
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
