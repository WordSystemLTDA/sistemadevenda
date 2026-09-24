import 'dart:convert';
import 'dart:async';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/notificador_atualizacao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'fila_delivery_offline.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MensagemClienteDelivery {
  confirmarEndereco('endereco'),
  formaPagamento('forma'),
  perguntarTroco('troco'),
  oferecerBebida('bebida'),
  algoMais('mais');

  final String codigo;
  const MensagemClienteDelivery(this.codigo);
}

class ServicoDelivery {
  static const _chaveDetalhesDelivery = 'detalhes_delivery_v1';
  static const _retencaoDetalhesDelivery = Duration(days: 30);

  final DioCliente dio;
  final UsuarioProvedor usuario;
  ServicoDelivery(this.dio, this.usuario);

  Future<PagamentoRecorrente?> pagamentoRecorrente(String id) =>
      FilaDeliveryOffline.local(id)
          ? Future.value(null)
          : ServicosRecorrentes(dio, usuario).pagamento(id);

  Future<FilaDeliveryOffline?> _filaLocal() async {
    final sync = Sincronizador.instancia;
    if (sync == null) return null;
    await sync.configurar();
    final conta = usuario.usuario;
    if (conta == null ||
        sync.escopo.isEmpty ||
        conta.empresa != sync.usuario.usuario?.empresa ||
        conta.id != sync.usuario.usuario?.id) {
      return null;
    }
    return FilaDeliveryOffline(sync.banco,
        escopo: sync.escopo,
        empresa: conta.empresa!,
        usuario: conta.id!,
        destino: sync.destino);
  }

  Future<FilaDeliveryOffline> _exigirFilaLocal() async =>
      await _filaLocal() ??
      (throw StateError(
          'Entre na conta original para recuperar este Delivery salvo no aparelho.'));

  Future<List<PedidoDelivery>> pedidosLocais() async =>
      await (await _filaLocal())?.listar() ?? [];

  Future<void> definirAjustesLocais(String id,
          {required double desconto, required double acrescimo}) async =>
      (await _exigirFilaLocal())
          .definirAjustes(id, desconto: desconto, acrescimo: acrescimo);

  // O Delivery usa a mesma API de venda configurada no aplicativo.
  static Uri enderecoApi(String servidor) => Uri.parse(servidor);
  static final _pedidosAtualizados =
      StreamController<PedidoDelivery>.broadcast();
  static Stream<PedidoDelivery> get pedidosAtualizados =>
      _pedidosAtualizados.stream;

  void notificarPedidoAtualizado(PedidoDelivery pedido) {
    if (!_pedidosAtualizados.isClosed) _pedidosAtualizados.add(pedido);
  }

  Future<dynamic> consultar(String rota,
          [Map<String, dynamic> campos = const {}]) =>
      _requisicao(rota, campos, false);

  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final id = '${campos['id_delivery'] ?? campos['id'] ?? ''}';
    if (FilaDeliveryOffline.local(id)) {
      if (rota == 'cardapio/editar_tipo_de_entrega_cliente.php') {
        await (await _exigirFilaLocal()).definirTaxa(
            id,
            '${campos['tipo_de_entrega']}',
            valorDelivery(campos['novo_valor_entrega']));
        return {'sucesso': true, 'salvo_no_aparelho': true};
      }
      throw StateError(
          'Este Delivery está salvo no aparelho. Conclua sua sincronização antes desta ação.');
    }
    final resposta = await _requisicao(rota, campos, true);
    if (resposta is! Map || resposta['sucesso'] != true) {
      throw StateError(resposta is Map
          ? (resposta['mensagem'] ?? 'Não foi possível salvar.').toString()
          : 'Resposta inválida do servidor.');
    }
    final tipo = _tipoAtualizacao(rota, campos);
    if (tipo != null) NotificadorAtualizacao.atendimento(tipo);
    return Map<String, dynamic>.from(resposta);
  }

  String? _tipoAtualizacao(String rota, Map<String, dynamic> campos) {
    final tipo = campos['tipo']?.toString();
    if (tipo == 'Delivery' || tipo == 'Balcão') return tipo;
    if (rota.startsWith('delivery/') || campos.containsKey('id_delivery')) {
      return 'Delivery';
    }
    return null;
  }

  Future<dynamic> _requisicao(
      String rota, Map<String, dynamic> campos, bool post) async {
    final empresa = usuario.usuario?.empresa;
    final idUsuario = usuario.usuario?.id;
    if (empresa == null || idUsuario == null) {
      throw StateError('Entre novamente no aplicativo.');
    }
    final servidor =
        enderecoApi((await Apis().getConexao()).servidor).toString();
    final dados = {
      ...campos,
      'empresa': empresa,
      'id_usuario': idUsuario,
      if (!post) '_atualizacao': DateTime.now().microsecondsSinceEpoch,
    };
    final consultaOffline = !post &&
        {
          'delivery/listar_opcoes.php',
          'permissoes_bigchef/listar_permissoes_bigchef.php',
          'config_bigchef/listar.php',
          'enderecos_clientes/listar_por_cliente.php',
        }.contains(rota);
    final opcoes = Options(extra: {
      'servidorFixo': servidor,
      'semCache': !consultaOffline,
    });
    final resposta = post
        ? await dio.cliente.post(rota, data: jsonEncode(dados), options: opcoes)
        : await dio.cliente.get(rota, queryParameters: dados, options: opcoes);
    final json = resposta.data is String
        ? jsonDecode(resposta.data as String)
        : resposta.data;
    if (json is! Map && json is! List) {
      throw StateError('Resposta inválida do Delivery.');
    }
    return json;
  }

  Future<List<EtapaDelivery>> listar(
      {required DateTime inicio,
      required DateTime fim,
      required String horaInicio,
      required String horaFim,
      String pesquisa = '',
      String tipo = '0'}) async {
    dynamic json;
    try {
      json = await consultar('delivery/listar_opcoes.php', {
        'dataInicio': DateFormat('yyyy-MM-dd').format(inicio),
        'dataFim': DateFormat('yyyy-MM-dd').format(fim),
        'horaSelecionada': horaInicio,
        'horaFimSelecionada': horaFim,
        'pesquisa': pesquisa,
        'tipoentrega': tipo,
      });
    } on DioException catch (erro) {
      if (!CacheConsultas.falhaDeConexao(erro)) rethrow;
      final locais = await pedidosLocais();
      if (locais.isEmpty) rethrow;
      json = {'sucesso': true, 'dados': []};
    }
    if (json is! Map) throw StateError('Resposta inválida do Delivery.');
    if (json['sucesso'] != true && json['mensagem'] != null) {
      throw StateError(json['mensagem'].toString());
    }
    final periodo = periodoOperacionalDelivery(
        inicio: inicio, fim: fim, horaInicio: horaInicio, horaFim: horaFim);
    final locais = (await pedidosLocais()).where((p) {
      final data = p.abertura;
      if (data == null) return false;
      final de = periodo.inicio;
      final ate = periodo.fim;
      final termo = pesquisa.toLowerCase().trim();
      return !data.isBefore(de) &&
          !data.isAfter(ate) &&
          (tipo == '0' || tipo == p.tipoEntrega) &&
          (termo.isEmpty ||
              '${p.nome} ${p.numero} ${p.texto('celularCliente')}'
                  .toLowerCase()
                  .contains(termo));
    }).toList();
    return [
      if (locais.isNotEmpty)
        EtapaDelivery.fromMap({
          'id': 'local',
          'nomeOpcao': 'No aparelho',
          'nomeBotao': 'Continuar pedido',
          'tipodeimpressao': '0',
          'vendas': locais.map((p) => p.dados).toList(),
        }),
      for (final e in json['dados'] as List? ?? [])
        EtapaDelivery.fromMap(Map<String, dynamic>.from(e as Map))
    ];
  }

  Future<ConfigDelivery> configuracao() async =>
      ConfigDelivery.fromMap(Map<String, dynamic>.from(
          await consultar('permissoes_bigchef/listar_permissoes_bigchef.php')
              as Map));

  Future<PedidoDelivery> pedido(String id) async {
    if (FilaDeliveryOffline.local(id)) {
      return (await _exigirFilaLocal()).pedido(id);
    }
    final json = await consultar(
        'delivery/listar_opcoes_por_id.php', {'id': id, 'nomedopcLocal': ''});
    if (json is! Map || json['sucesso'] != true || json['dados'] is! Map) {
      throw StateError('Não foi possível consultar o pedido.');
    }
    final pedido =
        PedidoDelivery.fromMap(Map<String, dynamic>.from(json['dados'] as Map));
    if (pedido.id != id) throw StateError('Pedido não encontrado.');
    return pedido;
  }

  Future<Modeloworddadoscardapio> dadosCardapio(String id) async {
    if (FilaDeliveryOffline.local(id)) {
      final local = await pedido(id);
      return Modeloworddadoscardapio.fromMap({
        ...local.dados,
        'nomeEmpresa': usuario.usuario?.nomeEmpresa ?? '',
        'idDelivery': id,
      });
    }
    final json = await consultar('cardapio/listar_por_id.php', {
      'id': id,
      'codigoQrcode': '',
      'tipo': 'Delivery',
      'imprimir': 'false',
      'mostrar_itens': 'true',
      'nomedopcLocal': '',
    });
    final dados =
        Modeloworddadoscardapio.fromMap(Map<String, dynamic>.from(json as Map));
    if (dados.id != id) throw StateError('Pedido não encontrado.');
    return dados;
  }

  Future<String> criar(
      {required String cliente,
      required String endereco,
      required String tipo,
      required String observacao,
      double taxa = 0,
      Map<String, dynamic> exibicao = const {}}) async {
    if (!['1', '2', '3'].contains(tipo)) {
      throw StateError('Selecione um tipo de entrega válido.');
    }
    if (tipo == '1' &&
        ((int.tryParse(cliente) ?? 0) <= 0 ||
            (int.tryParse(endereco) ?? 0) <= 0)) {
      throw StateError('Selecione o cliente e o endereço da entrega.');
    }
    final fila = await _filaLocal();
    if (fila != null && await fila.habilitada()) {
      return fila.criar(
          cliente: cliente,
          endereco: tipo == '1' ? endereco : '0',
          tipo: tipo,
          observacao: observacao,
          taxa: taxa,
          exibicao: exibicao);
    }
    // Nunca criar um pedido local em resposta a timeout desta API antiga:
    // o servidor pode ter inserido o pedido e perdido somente a resposta.
    final res = await salvar('delivery/inserir.php', {
      'cliente': cliente,
      'endereco': tipo == '1' ? endereco : '0',
      'tipoentrega': tipo,
      'obs': observacao,
      'idDeliveryEmEspera': '0',
    });
    final id = (res['dados'] as Map?)?['idDelivery']?.toString();
    if (id == null || id.isEmpty || id == '0') {
      throw StateError('Pedido sem identificação. Atualize o Delivery.');
    }
    return id;
  }

  Future<void> inserirProdutos(
      String id, List<Modelowordprodutos> produtos) async {
    if (produtos.isEmpty) throw StateError('Adicione produtos ao carrinho.');
    if (FilaDeliveryOffline.local(id)) {
      await (await _exigirFilaLocal()).inserirProdutos(id, produtos);
      return;
    }
    final atual = await pedido(id);
    if (atual.encerrado) throw StateError('Este pedido já está encerrado.');
    await salvar('delivery/inserir_produtos.php', {
      'id_delivery': id,
      'id_cliente': atual.cliente,
      'idCardDeFluxos': '0',
      'produtos':
          produtos.map((p) => normalizarProdutoParaEnvio(p.toMap())).toList(),
    });
    try {
      await registrarDetalhesLocais(id, produtos);
    } catch (erro, pilha) {
      // O servidor ja confirmou a inclusao. Nao induza um segundo envio caso
      // apenas a copia local usada como protecao da impressao tenha falhado.
      debugPrint(
          '[Delivery] Falha ao preservar detalhes locais do pedido $id: $erro\n$pilha');
    }
  }

  Future<void> registrarDetalhesLocais(
      String id, List<Modelowordprodutos> produtos) async {
    if (produtos.isEmpty) return;
    final registros = await _lerDetalhesLocais();
    _removerDetalhesExpirados(registros);
    final anterior = registros[id] is Map
        ? Map<String, dynamic>.from(registros[id] as Map)
        : <String, dynamic>{};
    final produtosAnteriores = anterior['produtos'] is List
        ? List<dynamic>.from(anterior['produtos'] as List)
        : <dynamic>[];
    registros[id] = {
      'salvoEm': DateTime.now().millisecondsSinceEpoch,
      'produtos': [
        ...produtosAnteriores,
        for (final produto in produtos)
          normalizarProdutoParaEnvio(produto.toMap()),
      ],
    };
    await _gravarDetalhesLocais(registros);
  }

  Future<List<Modelowordprodutos>> detalhesLocais(String id) async {
    final registros = await _lerDetalhesLocais();
    final alterou = _removerDetalhesExpirados(registros);
    if (alterou) await _gravarDetalhesLocais(registros);
    final registro = registros[id];
    if (registro is! Map || registro['produtos'] is! List) return [];
    return [
      for (final produto in registro['produtos'] as List)
        if (produto is Map)
          Modelowordprodutos.fromMap(Map<String, dynamic>.from(produto)),
    ];
  }

  Future<void> atualizarDetalheLocal(String id, Modelowordprodutos original,
      Modelowordprodutos editado) async {
    final produtos = await detalhesLocais(id);
    final indice = _indiceProdutoLocal(produtos, original);
    if (indice < 0) {
      await registrarDetalhesLocais(id, [editado]);
      return;
    }
    produtos[indice] =
        Modelowordprodutos.fromMap(normalizarProdutoParaEnvio(editado.toMap()));
    final registros = await _lerDetalhesLocais();
    _removerDetalhesExpirados(registros);
    registros[id] = {
      'salvoEm': DateTime.now().millisecondsSinceEpoch,
      'produtos': produtos
          .map((produto) => normalizarProdutoParaEnvio(produto.toMap()))
          .toList(),
    };
    await _gravarDetalhesLocais(registros);
  }

  int _indiceProdutoLocal(
      List<Modelowordprodutos> produtos, Modelowordprodutos original) {
    bool preenchido(Object? valor) =>
        (valor?.toString().trim() ?? '').isNotEmpty;
    if (preenchido(original.iditensvenda)) {
      final indice = produtos.indexWhere(
          (produto) => produto.iditensvenda == original.iditensvenda);
      if (indice >= 0) return indice;
    }
    if (preenchido(original.hashprodutos)) {
      final indice = produtos.indexWhere(
          (produto) => produto.hashprodutos == original.hashprodutos);
      if (indice >= 0) return indice;
    }
    return produtos.indexWhere((produto) => produto.id == original.id);
  }

  Future<String> _chaveArmazenamentoDetalhes() async {
    final empresa = usuario.usuario?.empresa ?? '0';
    final servidor = BancoLocal.instancia?.servidor.isNotEmpty == true
        ? BancoLocal.instancia!.servidor
        : (await Apis().getConexao()).servidor;
    return '$_chaveDetalhesDelivery:$servidor:$empresa';
  }

  Future<Map<String, dynamic>> _lerDetalhesLocais() async {
    final chave = await _chaveArmazenamentoDetalhes();
    final banco = BancoLocal.instancia;
    final valor = banco == null
        ? (await SharedPreferences.getInstance()).getString(chave)
        : await banco.ler(chave);
    if (valor == null || valor.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(valor) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> _gravarDetalhesLocais(Map<String, dynamic> registros) async {
    final chave = await _chaveArmazenamentoDetalhes();
    final valor = jsonEncode(registros);
    final banco = BancoLocal.instancia;
    if (banco != null) {
      await banco.gravar(chave, valor);
      return;
    }
    if (!await (await SharedPreferences.getInstance())
        .setString(chave, valor)) {
      throw StateError(
          'Não foi possível preservar os detalhes deste Delivery.');
    }
  }

  bool _removerDetalhesExpirados(Map<String, dynamic> registros) {
    final limite = DateTime.now()
        .subtract(_retencaoDetalhesDelivery)
        .millisecondsSinceEpoch;
    final quantidadeAntes = registros.length;
    registros.removeWhere((_, registro) {
      if (registro is! Map) return true;
      final salvoEm = int.tryParse('${registro['salvoEm'] ?? ''}') ?? 0;
      return salvoEm < limite;
    });
    return quantidadeAntes != registros.length;
  }

  Future<Map<String, dynamic>> avancar(
          PedidoDelivery pedido, EtapaDelivery destino,
          {String entregador = '',
          String valorEntrega = '0',
          List<String> impressoes = const []}) =>
      salvar('delivery/mudar_status_delivery.php', {
        'id': pedido.id,
        'status': destino.id,
        'statusOrigem': pedido.etapa,
        'tipoImpressaoEsperado': destino.impressao,
        'valorOriginal': pedido.total,
        if (impressoes.isNotEmpty) 'impressoes': impressoes,
        'irParaProximo': false,
        'idEntregador': entregador,
        'valor_da_entrega': valorEntrega,
      });

  Future<void> concluir(PedidoDelivery pedido) async {
    if (FilaDeliveryOffline.local(pedido.id)) {
      await (await _exigirFilaLocal()).concluir(pedido.id);
      return;
    }
    await salvar('delivery/finalizar_pedido_delivery.php',
        {'id_delivery': pedido.id, 'cliente': pedido.cliente});
  }

  Future<void> confirmar(String id) async {
    if (FilaDeliveryOffline.local(id)) {
      await (await _exigirFilaLocal()).confirmar(id);
      Sincronizador.instancia?.solicitar();
      NotificadorAtualizacao.atendimento('Delivery');
      return;
    }
    if ((int.tryParse(id) ?? 0) <= 0) {
      throw StateError('Pedido invÃ¡lido para confirmaÃ§Ã£o.');
    }
    await salvar('delivery/confirmar_pedido.php', {'id': id});
  }

  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
          [Map<String, dynamic> campos = const {}]) =>
      salvar('delivery/acoes_pedido.php', {
        ...campos,
        'acao': acao,
        'id': pedido.id,
        'statusOrigem': pedido.etapa,
      });

  Future<Map<String, dynamic>> notificarConfirmacaoPedido(
    PedidoDelivery pedido, {
    String? formaPagamento,
  }) async {
    var produtos = pedido.produtos;
    if (produtos.isEmpty && !pedido.salvoNoAparelho) {
      final cardapio = await dadosCardapio(pedido.id);
      produtos = cardapio.produtos ?? const [];
    }
    if (produtos.isEmpty) {
      throw StateError('Pedido sem produtos para enviar pelo WhatsApp.');
    }
    final produtosConfirmacao = produtos
        .map((produto) => _produtoConfirmacao(produto.toMap()))
        .toList();
    final pagamentoConfirmacao =
        _formaPagamentoConfirmacao(pedido, formaPagamento);

    if (pedido.salvoNoAparelho) {
      if (!pedido.possuiCelularCliente) {
        throw StateError('Cliente sem celular cadastrado.');
      }
      final resposta = await _requisicao(
        'delivery/notificar_cliente.php',
        {
          'acao': 'confirmar',
          'cliente': pedido.cliente,
          'endereco': pedido.texto('idendereco', '0'),
          'id_delivery': '0',
          'pedidoLocal': true,
          'tipo': 'Delivery',
          'tipoEntrega': pedido.tipoEntrega,
          'produtos': produtosConfirmacao,
          'valorPedido': (pedido.total - pedido.taxaEntrega).toStringAsFixed(2),
          'valorEntrega': pedido.taxaEntrega.toStringAsFixed(2),
          'valorTotalPedido': pedido.total.toStringAsFixed(2),
          'formaPagamento': pagamentoConfirmacao,
        },
        true,
      );
      if (resposta is! Map || resposta['sucesso'] != true) {
        throw StateError(resposta is Map
            ? (resposta['mensagem'] ??
                    'Não foi possível enviar a confirmação do pedido.')
                .toString()
            : 'Resposta inválida do servidor.');
      }
      return Map<String, dynamic>.from(resposta);
    }

    return acao('confirmar', pedido, {
      'id_empresa': usuario.usuario?.empresa,
      'id_cliente': pedido.cliente,
      'idEndereco': pedido.texto('idendereco', '0'),
      'tipo': 'Delivery',
      'produtos': produtosConfirmacao,
      'valorPedido': (pedido.total - pedido.taxaEntrega).toStringAsFixed(2),
      'valorEntrega': pedido.taxaEntrega.toStringAsFixed(2),
      'valorTotalPedido': pedido.total.toStringAsFixed(2),
      'formaPagamento': pagamentoConfirmacao,
    });
  }

  String _formaPagamentoConfirmacao(
      PedidoDelivery pedido, String? formaInformada) {
    final formas = <String>[];
    final nomes = [
      for (final pagamento in pedido.pagamentos)
        pagamento['nome'] ??
            pagamento['nomePagamento'] ??
            pagamento['documento'] ??
            '',
      formaInformada ?? '',
    ];
    for (final valor in nomes) {
      final nome = valor.toString().trim();
      if (nome.isEmpty ||
          formas.any((item) => item.toLowerCase() == nome.toLowerCase())) {
        continue;
      }
      formas.add(nome);
    }
    return formas.isEmpty ? 'A definir' : formas.join(' + ');
  }

  Map<String, dynamic> _produtoConfirmacao(Map<String, dynamic> produto) {
    final resultado = Map<String, dynamic>.from(produto);
    final opcoes = produto['opcoesPacotesListaFinal'];
    if (opcoes is List) {
      resultado['opcoesPacotesListaFinal'] = _opcoesConfirmacao(opcoes);
    }
    return resultado;
  }

  List<Map<String, dynamic>> _opcoesConfirmacao(List opcoes) {
    final resultado = <Map<String, dynamic>>[];
    for (final valor in opcoes) {
      if (valor is! Map) continue;
      final grupo = Map<String, dynamic>.from(valor);
      final dadosOriginais =
          grupo['dados'] is List ? grupo['dados'] as List : const <dynamic>[];
      final titulo = grupo['titulo']?.toString().trim().toLowerCase() ?? '';
      final grupoCardapio = grupo['tipo']?.toString() == '8' ||
          tituloIngredientesCardapio(grupo['titulo']) ||
          titulo == 'cardápio' ||
          titulo == 'cardapio' ||
          dadosOriginais.any((dado) {
            if (dado is! Map) return false;
            final idCategoria = (dado['idCategoriaCardapio'] ??
                    dado['categoriaCardapio'] ??
                    dado['id_categoria_cardapio'] ??
                    dado['categoria_cardapio'] ??
                    '')
                .toString()
                .trim()
                .toLowerCase();
            return dado['montagemCardapio'] is Map ||
                dado['montagem_cardapio'] is Map ||
                (idCategoria.isNotEmpty &&
                    idCategoria != '0' &&
                    idCategoria != 'null');
          });

      if (grupoCardapio) {
        grupo['dados'] = [
          for (final dado in dadosOriginais)
            if (dado is Map)
              if (_ingredienteAlterado(dado) case final alterado?) alterado,
        ];
      }

      final produtos = grupo['produtos'];
      if (produtos is List) {
        grupo['produtos'] = [
          for (final produto in produtos)
            if (produto is Map)
              _produtoConfirmacao(Map<String, dynamic>.from(produto)),
        ];
      }

      final dados = grupo['dados'];
      final produtosDoGrupo = grupo['produtos'];
      final semDados = dados is! List || dados.isEmpty;
      final semProdutos = produtosDoGrupo is! List || produtosDoGrupo.isEmpty;
      if (grupoCardapio && semDados && semProdutos) continue;
      resultado.add(grupo);
    }
    return resultado;
  }

  Map<String, dynamic>? _ingredienteAlterado(Map dado) {
    final mapaMontagem = dado['montagemCardapio'] ??
        dado['montagem_cardapio'] ??
        dado['montagem_json'];
    final montagem = mapaMontagem is Map
        ? MontagemIngredienteCardapio.fromMap(
            Map<String, dynamic>.from(mapaMontagem),
          )
        : MontagemIngredienteCardapio.inferirAlteracao(
            dado['nome']?.toString() ?? '',
          );
    if (montagem == null || !montagem.possuiAlteracao) return null;
    return {
      ...Map<String, dynamic>.from(dado),
      'nome': montagem.descricao,
      'montagemCardapio': montagem.toMap(),
    };
  }

  Future<String> notificarCliente(
    MensagemClienteDelivery mensagem, {
    String cliente = '0',
    String endereco = '0',
    String idDelivery = '0',
    String valorPedido = '',
  }) async {
    if (FilaDeliveryOffline.local(idDelivery)) {
      final rascunho = await pedido(idDelivery);
      cliente = rascunho.cliente;
      endereco = rascunho.texto('idendereco', '0');
      idDelivery = '0';
    }
    if ((int.tryParse(cliente) ?? 0) <= 0 &&
        (int.tryParse(idDelivery) ?? 0) <= 0) {
      throw StateError('Selecione um cliente para enviar a mensagem.');
    }
    if (mensagem == MensagemClienteDelivery.confirmarEndereco &&
        (int.tryParse(endereco) ?? 0) <= 0 &&
        (int.tryParse(idDelivery) ?? 0) <= 0) {
      throw StateError('Selecione um endereço para confirmar com o cliente.');
    }

    final resposta = await _requisicao(
      'delivery/notificar_cliente.php',
      {
        'acao': mensagem.codigo,
        'cliente': cliente,
        'endereco': endereco,
        'id_delivery': idDelivery,
        if (mensagem == MensagemClienteDelivery.perguntarTroco)
          'valor_pedido': valorPedido,
      },
      true,
    );
    if (resposta is! Map || resposta['sucesso'] != true) {
      throw StateError(resposta is Map
          ? (resposta['mensagem'] ?? 'Não foi possível enviar a mensagem.')
              .toString()
          : 'Resposta inválida do servidor.');
    }
    return (resposta['mensagem'] ?? 'Mensagem enviada com sucesso.').toString();
  }

  Future<Uri> documentoFiscal(PedidoDelivery pedido, {bool xml = false}) async {
    final chave = pedido.texto('cp15');
    final documento = pedido.texto('docempresa');
    final data = DateTime.tryParse(pedido.texto('dataEmissao'));
    if (!RegExp(r'^\d{44}$').hasMatch(chave) ||
        !RegExp(r'^\d{11,14}$').hasMatch(documento) ||
        data == null) {
      throw StateError(
          'Documento fiscal indisponível. Confira a venda no módulo fiscal.');
    }
    final servidor =
        enderecoApi((await Apis().getConexao()).servidor).resolve('../../../');
    final modelo = pedido.texto('cp16') == '55' ? 'NF-e' : 'NFCe';
    return servidor.resolve(
        'fiscal/Arquivos_XML/$modelo/$documento/producao/enviadas/aprovadas/${DateFormat('yy/MM').format(data)}/$chave-${xml ? 'nfe.xml' : 'pdf.pdf'}');
  }

  Future<void> prepararClone(
      String id, List<Modelowordprodutos> produtos) async {
    final contexto = ContextoCarrinho(
        empresa: usuario.usuario!.empresa!,
        tipo: 'delivery',
        idAtendimento: id);
    final copias = produtos
        .map((p) => Modelowordprodutos.fromMap(_limparClone(p.toMap())))
        .toList();
    final salvo =
        await ArmazenamentoCarrinhos.instancia.alterar(contexto, (itens) {
      if (itens.isNotEmpty) {
        throw StateError('Este pedido já possui um rascunho.');
      }
      itens.addAll(copias);
    });
    if (!salvo) {
      throw StateError('Não foi possível preparar os produtos do clone.');
    }
  }

  static Map<String, dynamic> _limparClone(Map<String, dynamic> mapa) => {
        for (final e in mapa.entries)
          e.key: switch (e.value) {
            Map valor => _limparClone(Map<String, dynamic>.from(valor)),
            List valor => [
                for (final v in valor)
                  v is Map ? _limparClone(Map<String, dynamic>.from(v)) : v
              ],
            _ => e.value,
          },
        if (mapa.containsKey('valorVenda')) ...{
          'iditensvenda': null,
          'hashprodutos': null,
          'novo': true,
          'conferidoNoCarrinho': false,
        },
      };

  Future<Map<String, dynamic>> pagar(
      PedidoDelivery pedido, int forma, double recebido,
      {double? valorOriginal,
      double? valorAPagar,
      double? desconto,
      double? acrescimo,
      String? chavePagamento,
      bool confirmarRecorrente = false,
      String? nomePagamento,
      String? dataLancamento,
      List<ParcelasModelo> parcelasLista = const []}) async {
    final totalOriginal = valorOriginal ?? pedido.total;
    final totalAPagar = valorAPagar ?? pedido.restante;
    if (forma < 1 ||
        forma > 9 ||
        pedido.encerrado ||
        totalAPagar <= 0.009 ||
        recebido <= 0 ||
        !recebido.isFinite) {
      throw StateError('Confira o valor do pagamento.');
    }
    if (forma != 1 && recebido > totalAPagar + 0.009) {
      throw StateError('Valor maior que o saldo do pedido.');
    }
    if (forma == 2 && (int.tryParse(pedido.cliente) ?? 0) <= 0) {
      throw StateError(
          'Selecione um cliente para lançar o pagamento em conta.');
    }
    final vencimento =
        dataLancamento ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    final parcelasParaEnvio = forma == 2
        ? [
            for (final parcela in parcelasLista)
              jsonEncode({
                'parcela': parcela.parcela,
                'valor': parcela.valorController?.text ?? parcela.valor,
                'vencimento': parcela.vencimento,
              }),
          ]
        : const <String>[];
    final troco =
        forma == 1 && recebido > totalAPagar ? recebido - totalAPagar : 0.0;
    final dados = <String, dynamic>{
      'id': pedido.id,
      if (chavePagamento != null) 'chavePagamento': chavePagamento,
      if (confirmarRecorrente) 'confirmarRecorrente': true,
      'id_comanda': '0',
      'id_mesa': '0',
      'cliente': pedido.cliente,
      'editar_movimentacao': '0',
      'limpar_pagamentos_anteriores': '0',
      'valor_original': totalOriginal.toStringAsFixed(2),
      'valor_lancamento': recebido.toStringAsFixed(2),
      'pagamentoSelecionado': forma,
      if (nomePagamento?.trim().isNotEmpty == true)
        'nomePagamento': nomePagamento!.trim(),
      'quantidadePessoas': 1,
      'subTotal': totalOriginal.toStringAsFixed(2),
      'dataLancamento': vencimento,
      'parcelas': forma == 2 ? parcelasParaEnvio.length.toString() : '1',
      'parcelasLista': parcelasParaEnvio,
      'tipo': 'Delivery',
      'valortroco': troco.toStringAsFixed(2),
      'valor_da_entrega': pedido.texto('valordaentrega', '0'),
      'valoresProduto': '0',
      'novo': false,
      'tipodeentrega': pedido.tipoEntrega,
      'valorAPagarOriginal': totalOriginal.toStringAsFixed(2),
      'valorAPagar': totalAPagar.toStringAsFixed(2),
      'valordataxadeservico': '0',
      'valordesconto':
          (desconto ?? valorDelivery(pedido.dados['valorDesconto']))
              .toStringAsFixed(2),
      'valoracrescimo':
          (acrescimo ?? valorDelivery(pedido.dados['valorAcrescimo']))
              .toStringAsFixed(2),
      'produtosParaFinalizar': [],
    };
    if (FilaDeliveryOffline.local(pedido.id)) {
      return (await _exigirFilaLocal()).pagar(pedido.id, dados);
    }
    return salvar('delivery/pagar_pedido.php', dados);
  }
}
