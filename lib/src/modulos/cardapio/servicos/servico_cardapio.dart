import 'dart:convert';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'dart:developer';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoCardapio {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoCardapio(this.dio, this.usuarioProvedor);

  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode}) async {
    if (tipo == TipoCardapio.delivery) {
      return ServicoDelivery(dio, usuarioProvedor).dadosCardapio(id);
    }
    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;

    final sync = Sincronizador.instancia;
    if (sync != null && AtendimentosLocais.local(id)) {
      final locais = AtendimentosLocais(sync.banco, sync.escopo);
      final abertura = await locais.abertura(id);
      final detalhe = await locais.detalhe(id);
      final real = abertura == null
          ? null
          : AtendimentosLocais.recibo(abertura)['id_comanda_pedido'];
      if (real != null &&
          !['conflito', 'arquivado'].contains(abertura!['estado'])) {
        try {
          final remoto = await listarPorId(real.toString(), tipo, mostraritens);
          if (remoto.id == real.toString()) {
            remoto.id = id;
            await ArmazenamentoCarrinhos.instancia
                .atualizarStatus(empresa ?? '', id, remoto.status);
            return remoto;
          }
        } on DioException catch (e) {
          if (!CacheConsultas.falhaDeConexao(e)) rethrow;
        }
      }
      return Modeloworddadoscardapio.fromMap(detalhe);
    }
    if (sync != null &&
        tipo == TipoCardapio.balcao &&
        (id == '0' || id.isEmpty)) {
      return Modeloworddadoscardapio(
          id: '0',
          nome: 'Balcão',
          status: 'Andamento',
          nomeEmpresa: usuarioProvedor.usuario?.nomeEmpresa ?? '',
          produtos: [],
          valorTotal: '0');
    }

    final response = await dio.cliente.get(
        'cardapio/listar_por_id.php?id=$id&codigoQrcode=$codigoQrcode&empresa=$empresa&id_usuario=$idUsuario&tipo=${tipo.nome}&mostrar_itens=$mostraritens');

    if (response.statusCode == 200) {
      final dados = Modeloworddadoscardapio.fromMap(response.data);
      if (tipo == TipoCardapio.comanda || tipo == TipoCardapio.mesa) {
        await ArmazenamentoCarrinhos.instancia
            .atualizarStatus(empresa ?? '', id, dados.status);
      }
      return dados;
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }

  Future<
      ({
        String id,
        String codigo,
        String nome,
        String idComandaPedido,
        bool ocupado,
        bool sucesso,
        String idCliente,
        bool fechamento
      })> listarIdCodigoQrcode(TipoCardapio tipo, String? codigoQrcode) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.get(
        'cardapio/listar_id_por_codigo.php?codigoQrcode=$codigoQrcode&empresa=$empresa&id_usuario=$idUsuario&tipo=${tipo.nome}');

    var jsonData = response.data;
    bool ocupado = jsonData['ocupado'];
    bool sucesso = jsonData['sucesso'];
    String id = jsonData['id'];
    String codigo = jsonData['codigo'];
    String nome = jsonData['nome'];
    String idComandaPedido = jsonData['idComandaPedido'];
    String idCliente = jsonData['idCliente'];
    bool fechamento = jsonData['fechamento'];

    if (sucesso &&
        (tipo == TipoCardapio.comanda || tipo == TipoCardapio.mesa)) {
      await ArmazenamentoCarrinhos.instancia.sincronizarRecurso(
        empresa: empresa ?? '',
        tipo: tipo.name,
        idRecurso: id,
        idAtendimento: idComandaPedido,
        aberto: ocupado,
        bloqueado: fechamento,
      );
    }

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

  Future<(bool, String)> inserirProdutosComanda(
      List<Modelowordprodutos> produtos,
      String idMesa,
      String idComandaPedido,
      String idComanda,
      String idcliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    try {
      final atendimento =
          await listarPorId(idComandaPedido, TipoCardapio.comanda, 'Não');
      if (atendimento.id != idComandaPedido ||
          atendimento.status != 'Andamento') {
        return (false, 'Esta comanda nao esta aberta para receber produtos.');
      }
      var campos = {
        'produtos': produtos,
        "id_comanda_pedido": idComandaPedido,
        "id_comanda": idComanda,
        "id_mesa": idMesa,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'id_cliente': idcliente,
      };

      var response = await dio.cliente
          .post('comandas/inserir_produtos.php', data: jsonEncode(campos));

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

      rethrow;
    }
  }

  Future<(bool, String)> inserirProdutosMesa(List<Modelowordprodutos> produtos,
      String idMesa, String idComandaPedido, String idcliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    try {
      final atendimento =
          await listarPorId(idComandaPedido, TipoCardapio.mesa, 'Não');
      if (atendimento.id != idComandaPedido ||
          atendimento.status != 'Andamento') {
        return (false, 'Esta mesa nao esta aberta para receber produtos.');
      }
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

      var response = await dio.cliente
          .post('mesas/inserir_produtos.php', data: jsonEncode(campos));

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

      rethrow;
    }
  }

  Future<(bool, String)> editarProdutoFinalizado({
    required TipoCardapio tipo,
    required Modeloworddadoscardapio atendimento,
    required Modelowordprodutos produto,
    required String idMesa,
    required String idComanda,
    required String idCliente,
    required List<String> impressoes,
  }) async {
    final idEmpresa = usuarioProvedor.usuario?.empresa ?? '';
    final idUsuario = usuarioProvedor.usuario?.id ?? '';
    final idAtendimento = atendimento.id ?? '';
    final idItemVenda = produto.iditensvenda ?? '';
    final versao = atendimento.versaoAtendimento ?? '';

    if (idEmpresa.isEmpty || idUsuario.isEmpty) {
      return (false, 'Entre novamente para editar o produto.');
    }
    if (idAtendimento.isEmpty || idItemVenda.isEmpty) {
      return (false, 'Produto sem identificador para edição.');
    }
    if (atendimento.status != 'Andamento') {
      return (false, 'Este atendimento nao esta aberto para edicao.');
    }

    final sync = Sincronizador.instancia;
    if (sync != null) {
      await sync.guardarEdicaoProdutoFinalizado(
        tipo: tipo.name,
        idAtendimento: idAtendimento,
        versaoAtendimento: versao,
        idItemVenda: idItemVenda,
        produto: produto,
        idMesa: idMesa,
        idComanda: idComanda,
        idCliente: idCliente,
        impressoes: impressoes,
      );
      return (
        true,
        'Alteracao salva. O app vai reenviar ate confirmar no servidor.'
      );
    }

    try {
      final campos = {
        'produto': normalizarProdutoParaEnvio(produto.toMap()),
        'id_itens_venda': idItemVenda,
        'id_comanda_pedido': idAtendimento,
        'versao_atendimento': versao,
        'id_comanda': idComanda.isEmpty ? '0' : idComanda,
        'id_mesa': idMesa.isEmpty ? '0' : idMesa,
        'tipo': tipo.name,
        'id_cliente': idCliente.isEmpty ? '0' : idCliente,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
      };

      final response = await dio.cliente.post(
          'comandas/editar_produto_finalizado.php',
          data: jsonEncode(campos));
      final jsonData = response.data;
      if (jsonData is! Map) return (false, 'Resposta invalida do servidor.');
      return (
        jsonData['sucesso'] == true,
        jsonData['mensagem']?.toString() ?? 'Produto atualizado.'
      );
    } on DioException catch (e) {
      if (e.response == null && kDebugMode) {
        log('ERRO API', error: e.error);
      }
      rethrow;
    }
  }

  Future<
      ({
        bool sucesso,
        String mensagem,
        ModeloDestinoImpressao? destinoCaixa
      })> cancelarItemFinalizado({
    required TipoCardapio tipo,
    required Modeloworddadoscardapio atendimento,
    required Modelowordprodutos produto,
    required String idMesa,
    required String idComanda,
    required String senhaAdmin,
  }) async {
    final idEmpresa = usuarioProvedor.usuario?.empresa ?? '';
    final idUsuario = usuarioProvedor.usuario?.id ?? '';
    final idAtendimento = atendimento.id ?? '';
    final idItemVenda = produto.iditensvenda ?? '';
    final versao = atendimento.versaoAtendimento ?? '';

    if (idEmpresa.isEmpty || idUsuario.isEmpty) {
      return (
        sucesso: false,
        mensagem: 'Entre novamente para cancelar o item.',
        destinoCaixa: null,
      );
    }
    if (idAtendimento.isEmpty || idItemVenda.isEmpty) {
      return (
        sucesso: false,
        mensagem: 'Item sem identificador para cancelamento.',
        destinoCaixa: null,
      );
    }
    if (atendimento.status != 'Andamento') {
      return (
        sucesso: false,
        mensagem: 'Este atendimento nao esta aberto para cancelamento.',
        destinoCaixa: null,
      );
    }
    if (senhaAdmin.trim().isEmpty) {
      return (
        sucesso: false,
        mensagem: 'Informe a senha Admin de cancelamento.',
        destinoCaixa: null,
      );
    }
    if (Sincronizador.instancia != null) {
      return (
        sucesso: false,
        mensagem:
            'Conecte ao servidor para cancelar item finalizado com senha Admin.',
        destinoCaixa: null,
      );
    }

    try {
      final campos = {
        'id_itens_venda': idItemVenda,
        'id_comanda_pedido': idAtendimento,
        'versao_atendimento': versao,
        'id_comanda': idComanda.isEmpty ? '0' : idComanda,
        'id_mesa': idMesa.isEmpty ? '0' : idMesa,
        'tipo': tipo.name,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'senha_admin_cancelar': senhaAdmin.trim(),
      };

      final response = await dio.cliente.post(
        'comandas/cancelar_item_finalizado.php',
        data: jsonEncode(campos),
      );
      final jsonData = response.data;
      if (jsonData is! Map) {
        return (
          sucesso: false,
          mensagem: 'Resposta invalida do servidor.',
          destinoCaixa: null,
        );
      }
      final destino = jsonData['destino_impressao_caixa'];
      return (
        sucesso: jsonData['sucesso'] == true,
        mensagem: jsonData['mensagem']?.toString() ?? 'Item cancelado.',
        destinoCaixa: destino is Map
            ? ModeloDestinoImpressao.fromMap(Map<String, dynamic>.from(destino))
            : null,
      );
    } on DioException catch (e) {
      if (e.response == null && kDebugMode) {
        log('ERRO API', error: e.error);
      }
      rethrow;
    }
  }

  Future<({bool sucesso, String mensagem})> fecharAbrirComanda(
      String idComandaPedido, String status) async {
    final sincronizador = Sincronizador.instancia;
    if (status != 'Andamento' && sincronizador != null) {
      final pendencias =
          await sincronizador.banco.operacoes(sincronizador.escopo);
      if (pendencias.any((op) => op['atendimento'] == idComandaPedido)) {
        return (
          sucesso: false,
          mensagem:
              'Este atendimento tem pedidos aguardando envio ou conferencia. Resolva as pendencias antes de fechar.'
        );
      }
    }
    if (sincronizador != null && AtendimentosLocais.local(idComandaPedido)) {
      final abertura =
          await AtendimentosLocais(sincronizador.banco, sincronizador.escopo)
              .abertura(idComandaPedido);
      final real = abertura == null
          ? null
          : AtendimentosLocais.recibo(abertura)['id_comanda_pedido'];
      if (real == null) {
        return (
          sucesso: false,
          mensagem: 'Aguarde o envio da abertura antes de fechar.'
        );
      }
      idComandaPedido = real.toString();
    }
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    try {
      var campos = {
        "id_comanda_pedido": idComandaPedido,
        'empresa': idEmpresa,
        'id_usuario': idUsuario,
        'status': status,
      };

      var response = await dio.cliente
          .post('comandas/fechar_abrir_comanda.php', data: jsonEncode(campos));

      var jsonData = response.data;
      bool sucesso = jsonData['sucesso'];
      String mensagem = jsonData['mensagem'];

      if (sucesso) {
        await ArmazenamentoCarrinhos.instancia
            .atualizarStatus(idEmpresa ?? '', idComandaPedido, status);
      }

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
