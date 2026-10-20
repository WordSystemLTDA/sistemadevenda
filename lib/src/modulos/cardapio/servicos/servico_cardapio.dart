import 'dart:convert';
import 'package:app/src/essencial/sincronizacao/recebimentos_atendimento.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'dart:developer';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';

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

  Future<Modeloworddadoscardapio?> _detalheSalvo({
    required Sincronizador sync,
    required String id,
    required TipoCardapio tipo,
    required String empresa,
    required String idUsuario,
    required String mostrarItens,
    String? codigoQrcode,
  }) async {
    for (final itens in <String>{mostrarItens, 'Não', 'Sim'}) {
      try {
        final chave = CacheConsultas.chave(RequestOptions(
          path: 'cardapio/listar_por_id.php',
          queryParameters: {
            'id': id,
            'codigoQrcode': '$codigoQrcode',
            'empresa': empresa,
            'id_usuario': idUsuario,
            'tipo': tipo.nome,
            'mostrar_itens': itens,
          },
        ));
        final registro = await sync.banco.consulta(sync.escopo, chave);
        if (registro == null) continue;
        final salvo = jsonDecode(registro['valor'] as String);
        if (salvo is! Map || '${salvo['id']}' != id) continue;
        final projetado = await AtendimentosLocais(sync.banco, sync.escopo)
            .projetarDetalhe(Map<String, dynamic>.from(salvo),
                tipo == TipoCardapio.mesa ? 'mesa' : 'comanda');
        return Modeloworddadoscardapio.fromMap(projetado);
      } catch (_) {
        // Tenta o outro retrato e, por ultimo, o estado compacto sincronizado.
      }
    }

    try {
      final texto = await sync.banco.ler('estado:${sync.escopo}');
      if (texto == null) return null;
      final estado = jsonDecode(texto) as Map;
      final atendimento = (estado['atendimentos'] as Map?)?[id] as Map?;
      if (atendimento == null) return null;
      final campoRecurso = tipo == TipoCardapio.mesa ? 'id_mesa' : 'id_comanda';
      final idRecurso = '${atendimento[campoRecurso] ?? '0'}';
      if (idRecurso.isEmpty || idRecurso == '0') return null;
      final recurso =
          (estado['recursos'] as Map?)?['${tipo.name}:$idRecurso'] as Map?;
      return Modeloworddadoscardapio(
        id: id,
        codigo: recurso?['codigo']?.toString() ?? '',
        nome: recurso?['nome']?.toString() ?? tipo.nome,
        status: atendimento['status']?.toString() ?? 'Andamento',
        versaoAtendimento: atendimento['versao']?.toString(),
        idComanda: tipo == TipoCardapio.comanda ? idRecurso : '0',
        idMesa: tipo == TipoCardapio.mesa ? idRecurso : '0',
        idCliente: '0',
        nomeCliente: '',
        produtos: const [],
        valorTotal: '0',
        numeroPedido: '',
        nomeEmpresa: usuarioProvedor.usuario?.nomeEmpresa ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode, bool semCache = false}) async {
    if (tipo == TipoCardapio.delivery) {
      return ServicoDelivery(dio, usuarioProvedor).dadosCardapio(id);
    }
    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;

    final sync = Sincronizador.instancia;
    if (sync != null &&
        !semCache &&
        [TipoCardapio.mesa, TipoCardapio.comanda].contains(tipo)) {
      final recebimento = await RecebimentosAtendimento(sync.banco, sync.escopo)
          .detalhePendente(id);
      if (recebimento != null) return recebimento;
    }
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
          final remoto = await listarPorId(real.toString(), tipo, mostraritens,
              semCache: semCache);
          if (remoto.id == real.toString()) {
            remoto.id = id;
            await ArmazenamentoCarrinhos.instancia
                .atualizarStatus(empresa ?? '', id, remoto.status);
            return remoto;
          }
        } catch (erro, stack) {
          // A abertura ja foi salva no aparelho e pode ter recebido o numero
          // definitivo poucos milissegundos antes desta consulta. A API de
          // detalhes pode ainda nao enxergar esse registro, ou pode ficar
          // indisponivel enquanto o canal local esta fora da rede. Nesse
          // intervalo o retrato local continua sendo a fonte segura para o
          // carrinho; o envio duravel abaixo sera validado pela API.
          log('Falha ao atualizar atendimento confirmado; usando dados locais',
              name: 'ServicoCardapio', error: erro, stackTrace: stack);
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

    try {
      final response = await dio.cliente.get(
          'cardapio/listar_por_id.php?id=$id&codigoQrcode=$codigoQrcode&empresa=$empresa&id_usuario=$idUsuario&tipo=${tipo.nome}&mostrar_itens=$mostraritens',
          options: semCache ? Options(extra: {'semCache': true}) : null);
      if (response.statusCode != 200 || response.data is! Map) {
        throw StateError('O servidor nao retornou os dados do atendimento.');
      }
      final projetado = sync != null &&
              [TipoCardapio.comanda, TipoCardapio.mesa].contains(tipo)
          ? await AtendimentosLocais(sync.banco, sync.escopo).projetarDetalhe(
              Map<String, dynamic>.from(response.data),
              tipo == TipoCardapio.mesa ? 'mesa' : 'comanda')
          : response.data;
      final dados = Modeloworddadoscardapio.fromMap(projetado);
      if (tipo == TipoCardapio.comanda || tipo == TipoCardapio.mesa) {
        if (dados.id != id) {
          throw StateError('O servidor retornou outro atendimento.');
        }
        await ArmazenamentoCarrinhos.instancia
            .atualizarStatus(empresa ?? '', id, dados.status);
      }
      return dados;
    } catch (erro, stack) {
      if (!semCache &&
          sync != null &&
          [TipoCardapio.comanda, TipoCardapio.mesa].contains(tipo)) {
        final salvo = await _detalheSalvo(
          sync: sync,
          id: id,
          tipo: tipo,
          empresa: empresa ?? '',
          idUsuario: idUsuario ?? '',
          mostrarItens: mostraritens,
          codigoQrcode: codigoQrcode,
        );
        if (salvo != null) {
          log('Consulta online indisponivel; usando atendimento sincronizado',
              name: 'ServicoCardapio', error: erro, stackTrace: stack);
          await ArmazenamentoCarrinhos.instancia
              .atualizarStatus(empresa ?? '', id, salvo.status);
          return salvo;
        }
      }
      rethrow;
    }
  }

  Future<Modeloworddadoscardapio> listarFinalizadoParaImpressao(
      String id, TipoCardapio tipo) async {
    if (tipo != TipoCardapio.comanda &&
        tipo != TipoCardapio.mesa &&
        tipo != TipoCardapio.balcao) {
      throw StateError(
          'A impressão final não está disponível para este atendimento.');
    }

    final empresa = usuarioProvedor.usuario!.empresa;
    final idUsuario = usuarioProvedor.usuario!.id;
    final response = await dio.cliente.get(
      'cardapio/listar_por_id.php',
      queryParameters: {
        'id': id,
        'codigoQrcode': 'null',
        'empresa': empresa,
        'id_usuario': idUsuario,
        'tipo': tipo.nome,
        'mostrar_itens': 'Sim',
        'imprimir': 'true',
      },
    );

    if (response.statusCode != 200 || response.data is! Map) {
      throw StateError(
          'Não foi possível carregar o comprovante da conta finalizada.');
    }

    final atendimento = Modeloworddadoscardapio.fromMap(
        Map<String, dynamic>.from(response.data as Map));
    if (atendimento.id != id ||
        !['Finalizada', 'Concluída'].contains(atendimento.status)) {
      throw StateError('A conta finalizada não foi localizada para impressão.');
    }
    return atendimento;
  }

  Future<
      ({
        bool sucesso,
        String mensagem,
        String idVenda,
        String numeroPedido,
      })> prepararFinalizacaoBalcao({
    required String idVenda,
    required String cliente,
    required String observacao,
    required String tipoDeEntrega,
    required List<Modelowordprodutos> produtos,
  }) async {
    final campos = <String, dynamic>{
      'id_operacao': BancoLocal.novoId(),
      'id': idVenda.isEmpty ? '0' : idVenda,
      'empresa': usuarioProvedor.usuario?.empresa ?? '',
      'id_usuario': usuarioProvedor.usuario?.id ?? '',
      'cliente': cliente.isEmpty ? '0' : cliente,
      'obs': observacao,
      'tipodeentrega': tipoDeEntrega,
      'produtos': produtos,
    };

    ({
      bool sucesso,
      String mensagem,
      String idVenda,
      String numeroPedido,
    }) interpretar(Object? resposta) {
      if (resposta is! Map) {
        return (
          sucesso: false,
          mensagem: 'O servidor retornou uma resposta inválida.',
          idVenda: idVenda,
          numeroPedido: '',
        );
      }
      final dados = Map<String, dynamic>.from(resposta);
      return (
        sucesso: dados['sucesso'] == true,
        mensagem: dados['mensagem']?.toString() ?? 'Pedido não registrado.',
        idVenda: dados['idVenda']?.toString() ?? idVenda,
        numeroPedido: dados['numeroPedido']?.toString() ?? '',
      );
    }

    Future<
        ({
          bool sucesso,
          String mensagem,
          String idVenda,
          String numeroPedido,
        })> enviar() async {
      final resposta = await dio.cliente.post(
        'balcao/preparar_finalizacao.php',
        data: jsonEncode(campos),
      );
      return interpretar(resposta.data);
    }

    try {
      return await enviar();
    } on DioException catch (primeiroErro) {
      if (primeiroErro.response == null) {
        try {
          return await enviar();
        } on DioException catch (segundoErro) {
          final dados = segundoErro.response?.data;
          return (
            sucesso: false,
            mensagem: dados is Map
                ? dados['mensagem']?.toString() ??
                    'Não foi possível preparar a venda.'
                : 'Não foi possível preparar a venda.',
            idVenda: idVenda,
            numeroPedido: '',
          );
        }
      }
      final dados = primeiroErro.response?.data;
      return (
        sucesso: false,
        mensagem: dados is Map
            ? dados['mensagem']?.toString() ??
                'Não foi possível preparar a venda.'
            : 'Não foi possível preparar a venda.',
        idVenda: idVenda,
        numeroPedido: '',
      );
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
    var idAtendimentoServidor = idAtendimento;
    final sync = Sincronizador.instancia;
    if (sync != null && AtendimentosLocais.local(idAtendimento)) {
      await sync.configurar();
      final abertura =
          await AtendimentosLocais(sync.banco, sync.escopo).abertura(
        idAtendimento,
      );
      final real = abertura == null
          ? null
          : AtendimentosLocais.recibo(abertura)['id_comanda_pedido'];
      if (real == null) {
        return (
          sucesso: false,
          mensagem: 'Aguarde o envio da abertura antes de cancelar o item.',
          destinoCaixa: null,
        );
      }
      idAtendimentoServidor = real.toString();
    }

    try {
      final campos = {
        'id_itens_venda': idItemVenda,
        'id_comanda_pedido': idAtendimentoServidor,
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
      if (CacheConsultas.falhaDeConexao(e)) {
        return (
          sucesso: false,
          mensagem:
              'Conecte ao servidor para cancelar item finalizado com senha Admin.',
          destinoCaixa: null,
        );
      }
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
