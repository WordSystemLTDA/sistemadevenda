import 'dart:convert';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/utils/numero_pedido_operacional.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';

class ImpressaoDelivery {
  static Future<void> imprimir(
      ServicoDelivery servico, Server server, PedidoDelivery pedido,
      {bool preparo = false,
      bool ambos = false,
      String? chaveRecorrente,
      ConfigDelivery? config}) async {
    final mensagens = await prepararMensagens(servico, pedido,
        preparo: preparo,
        ambos: ambos,
        chaveRecorrente: chaveRecorrente,
        config: config);
    await server.enviarImpressoes(mensagens);
  }

  /// Monta todos os destinos antes de alterar a etapa do pedido.
  static Future<List<String>> prepararMensagens(
      ServicoDelivery servico, PedidoDelivery pedido,
      {bool preparo = false,
      bool ambos = false,
      String? chaveRecorrente,
      ConfigDelivery? config}) async {
    final resultados = await Future.wait([
      servico.dadosCardapio(pedido.id),
      servico.detalhesLocais(pedido.id),
    ]);
    final dados = resultados[0] as Modeloworddadoscardapio;
    final detalhesLocais = resultados[1] as List<Modelowordprodutos>;
    final configuracao = config ?? await _configuracao(servico);
    final numeroPedido =
        numeroPedidoOperacionalConfirmado(dados.numeroPedido) ??
            exigirNumeroPedidoOperacional(pedido.numeroOperacional);
    final pedidoConfirmado = PedidoDelivery.fromMap({
      ...pedido.dados,
      'numeroPedido': numeroPedido,
    });
    final produtosBase = dados.produtos ?? <Modelowordprodutos>[];
    final produtos = produtosComDetalhesDoPedido(
      pedidoConfirmado,
      produtosBase,
      detalhesLocais: detalhesLocais,
    );
    if (produtos.isEmpty) {
      throw StateError('O pedido não tem produtos para impressão.');
    }
    final mensagens = <String>[
      if (preparo || ambos)
        ..._comCamposNumeroOperacional(
          Impressao.prepararComprovanteDePedido(
              produtos: produtos,
              tipoTela: TipoCardapio.delivery,
              tipodeentrega: pedidoConfirmado.tipoEntrega,
              nomeCliente: pedidoConfirmado.nome,
              nomeEmpresa: dados.nomeEmpresa ?? '',
              comanda: 'Delivery ${pedidoConfirmado.id}',
              numeroPedido: numeroPedido),
          configuracao,
        ),
      if (!preparo || ambos)
        ...comprovantes(servico, pedidoConfirmado.comEndereco(dados), produtos,
            config: configuracao),
    ];
    return chaveRecorrente == null
        ? mensagens
        : identificarPreparoRecorrente(mensagens, chaveRecorrente);
  }

  static Future<void> enviarPreparadas(Server server, List<String> mensagens,
      {bool preparoPersistido = false}) async {
    // A API e o socket nao podem disputar a mesma impressao em duas centrais.
    final locais = preparoPersistido
        ? mensagens
            .where((mensagem) =>
                (jsonDecode(mensagem) as Map)['tipoImpressao']?.toString() !=
                '1')
            .toList()
        : mensagens;
    if (preparoPersistido) {
      server.write(jsonEncode({'tipo': 'PreparoPendente'}));
    }
    if (locais.isNotEmpty) await server.enviarImpressoes(locais);
  }

  static List<String> identificarPreparoRecorrente(
          List<String> mensagens, String chave) =>
      [
        for (final mensagem in mensagens) _identificarPreparo(mensagem, chave),
      ];

  static String _identificarPreparo(String mensagem, String chave) {
    final dados = jsonDecode(mensagem) as Map<String, dynamic>;
    final destino = base64Url
        .encode(utf8.encode('${dados['nomedopc'] ?? ''}'.trim().toLowerCase()))
        .replaceAll('=', '');
    return jsonEncode({...dados, 'idRequisicao': '$chave-$destino'});
  }

  static Future<ConfigDelivery?> _configuracao(ServicoDelivery servico) async {
    try {
      return await servico.configuracao();
    } catch (_) {
      return null;
    }
  }

  static List<Modelowordprodutos> produtosComDetalhesDoPedido(
    PedidoDelivery pedido,
    List<Modelowordprodutos> produtosBase, {
    List<Modelowordprodutos> detalhesLocais = const [],
  }) {
    final detalhados = pedido.produtos;
    final produtosApi = _mesclarLista(produtosBase, detalhados);
    if (detalhesLocais.isEmpty) return produtosApi;
    if (produtosApi.isEmpty) return detalhesLocais;

    final usados = <int>{};
    return [
      for (var indice = 0; indice < produtosApi.length; indice++)
        _preencherDetalhesLocais(
          produtosApi[indice],
          _produtoDetalhadoCorrespondente(
            produtosApi[indice],
            detalhesLocais,
            usados,
            indice,
          ),
        ),
    ];
  }

  static List<Modelowordprodutos> _mesclarLista(
    List<Modelowordprodutos> produtosBase,
    List<Modelowordprodutos> detalhados,
  ) {
    if (detalhados.isEmpty) return produtosBase;
    if (produtosBase.isEmpty) return detalhados;

    final usados = <int>{};
    return [
      for (var indice = 0; indice < produtosBase.length; indice++)
        _mesclarProdutoDetalhado(
          produtosBase[indice],
          _produtoDetalhadoCorrespondente(
            produtosBase[indice],
            detalhados,
            usados,
            indice,
          ),
        ),
    ];
  }

  static Modelowordprodutos _preencherDetalhesLocais(
    Modelowordprodutos base,
    Modelowordprodutos? local,
  ) {
    if (local == null) return base;
    final mapa = base.toMap();
    final mapaLocal = local.toMap();
    for (final campo in [
      'opcoesPacotesListaFinal',
      'opcoesPacotes',
    ]) {
      mapa[campo] = _mesclarGruposDeOpcoes(
        mapa[campo],
        mapaLocal[campo],
      );
    }
    if (!_listaTemItens(mapa['ingredientes']) &&
        _listaTemItens(mapaLocal['ingredientes'])) {
      mapa['ingredientes'] = mapaLocal['ingredientes'];
    }
    if (_vazio(mapa['observacao']) && !_vazio(mapaLocal['observacao'])) {
      mapa['observacao'] = mapaLocal['observacao'];
    }
    if (_vazio(mapa['idCategoriaCardapio']) &&
        !_vazio(mapaLocal['idCategoriaCardapio'])) {
      mapa['idCategoriaCardapio'] = mapaLocal['idCategoriaCardapio'];
    }
    return Modelowordprodutos.fromMap(mapa);
  }

  static Modelowordprodutos _mesclarProdutoDetalhado(
    Modelowordprodutos base,
    Modelowordprodutos? detalhado,
  ) {
    if (detalhado == null) return base;
    final mapaBase = base.toMap();
    final mapaDetalhado = detalhado.toMap();
    final mapa = <String, dynamic>{...mapaBase, ...mapaDetalhado};

    if (_temDestino(base.destinoDeImpressao)) {
      mapa['destinoDeImpressao'] = base.destinoDeImpressao!.toMap();
    }
    if (_vazio(mapaDetalhado['iditensvenda']) &&
        !_vazio(mapaBase['iditensvenda'])) {
      mapa['iditensvenda'] = mapaBase['iditensvenda'];
    }
    if (_vazio(mapaDetalhado['hashprodutos']) &&
        !_vazio(mapaBase['hashprodutos'])) {
      mapa['hashprodutos'] = mapaBase['hashprodutos'];
    }
    if (_vazio(mapaDetalhado['dataLancado'])) {
      mapa['dataLancado'] = mapaBase['dataLancado'];
    }
    for (final campo in [
      'opcoesPacotesListaFinal',
      'opcoesPacotes',
    ]) {
      // A consulta de cardapio e a fonte mais atual. A lista resumida do card
      // do Delivery completa somente os grupos que nao vieram nela.
      mapa[campo] = _mesclarGruposDeOpcoes(
        mapaBase[campo],
        mapaDetalhado[campo],
      );
    }
    if (!_listaTemItens(mapaDetalhado['ingredientes']) &&
        _listaTemItens(mapaBase['ingredientes'])) {
      mapa['ingredientes'] = mapaBase['ingredientes'];
    }
    if (_vazio(mapaDetalhado['observacao']) &&
        !_vazio(mapaBase['observacao'])) {
      mapa['observacao'] = mapaBase['observacao'];
    }
    if (!_vazio(base.imprimirCodigoProdutoPreparo)) {
      mapa['imprimirCodigoProdutoPreparo'] = base.imprimirCodigoProdutoPreparo;
    }

    return Modelowordprodutos.fromMap(mapa);
  }

  static Modelowordprodutos? _produtoDetalhadoCorrespondente(
    Modelowordprodutos base,
    List<Modelowordprodutos> detalhados,
    Set<int> usados,
    int indice,
  ) {
    // Dois itens podem ter o mesmo sabor principal, mas montagens diferentes.
    if (!_vazio(base.iditensvenda)) {
      for (var i = 0; i < detalhados.length; i++) {
        if (!usados.contains(i) &&
            base.iditensvenda == detalhados[i].iditensvenda) {
          usados.add(i);
          return detalhados[i];
        }
      }
    }
    final chavesBase = _chavesProduto(base);
    for (var i = 0; i < detalhados.length; i++) {
      if (usados.contains(i)) continue;
      final chavesDetalhado = _chavesProduto(detalhados[i]);
      if (chavesBase.any(chavesDetalhado.contains)) {
        usados.add(i);
        return detalhados[i];
      }
    }
    if (indice < detalhados.length && !usados.contains(indice)) {
      usados.add(indice);
      return detalhados[indice];
    }
    return null;
  }

  static List<String> _chavesProduto(Modelowordprodutos produto) => [
        if (!_vazio(produto.iditensvenda)) 'item:${produto.iditensvenda}',
        if (!_vazio(produto.hashprodutos)) 'hash:${produto.hashprodutos}',
        if (!_vazio(produto.id)) 'produto:${produto.id}',
      ];

  static bool _temDestino(ModeloDestinoImpressao? destino) =>
      destino != null &&
      (!_vazio(destino.nomedopc) ||
          !_vazio(destino.nomeDaImpressora) ||
          !_vazio(destino.nome));

  static bool _listaTemItens(Object? valor) =>
      valor is List && valor.isNotEmpty;

  /// Une opcoes por grupo, em vez de considerar uma lista parcialmente
  /// preenchida como se ela estivesse completa. Isso impede que um adicional
  /// devolvido pela API esconda a montagem do Cardapio e tambem preserva os
  /// grupos independentes da pizza (tamanho, sabores e bordas).
  static Object? _mesclarGruposDeOpcoes(
    Object? principal,
    Object? complemento,
  ) {
    if (!_listaTemItens(principal)) {
      return _listaTemItens(complemento) ? complemento : principal;
    }
    if (!_listaTemItens(complemento)) return principal;

    final resultado = <dynamic>[];
    final indices = <String, int>{};
    for (final item in principal as List) {
      final mapa = _mapaDinamico(item);
      if (mapa == null) {
        resultado.add(item);
        continue;
      }
      final indice = resultado.length;
      resultado.add(mapa);
      indices.putIfAbsent(_chaveGrupo(mapa), () => indice);
    }

    for (final item in complemento as List) {
      final mapa = _mapaDinamico(item);
      if (mapa == null) {
        resultado.add(item);
        continue;
      }
      final chave = _chaveGrupo(mapa);
      final indice = indices[chave];
      if (indice == null) {
        indices[chave] = resultado.length;
        resultado.add(mapa);
      } else {
        resultado[indice] = _mesclarGrupo(
          Map<String, dynamic>.from(resultado[indice] as Map),
          mapa,
        );
      }
    }
    return resultado;
  }

  static Map<String, dynamic> _mesclarGrupo(
    Map<String, dynamic> principal,
    Map<String, dynamic> complemento,
  ) {
    final resultado = _mesclarMapas(principal, complemento);
    for (final campo in ['dados', 'produtos']) {
      resultado[campo] = _mesclarItensDoGrupo(
        principal[campo],
        complemento[campo],
      );
    }
    resultado['opcoesPacote'] = _mesclarGruposDeOpcoes(
      principal['opcoesPacote'],
      complemento['opcoesPacote'],
    );
    return resultado;
  }

  static Object? _mesclarItensDoGrupo(
    Object? principal,
    Object? complemento,
  ) {
    if (!_listaTemItens(principal)) {
      return _listaTemItens(complemento) ? complemento : principal;
    }
    if (!_listaTemItens(complemento)) return principal;

    final resultado = <dynamic>[];
    final indices = <String, int>{};
    for (final item in principal as List) {
      final mapa = _mapaDinamico(item);
      if (mapa == null) {
        resultado.add(item);
        continue;
      }
      final indice = resultado.length;
      resultado.add(mapa);
      indices.putIfAbsent(_chaveItemGrupo(mapa), () => indice);
    }
    for (final item in complemento as List) {
      final mapa = _mapaDinamico(item);
      if (mapa == null) {
        resultado.add(item);
        continue;
      }
      final chave = _chaveItemGrupo(mapa);
      final indice = indices[chave];
      if (indice == null) {
        indices[chave] = resultado.length;
        resultado.add(mapa);
      } else {
        resultado[indice] = _mesclarMapas(
          Map<String, dynamic>.from(resultado[indice] as Map),
          mapa,
        );
      }
    }
    return resultado;
  }

  static Map<String, dynamic> _mesclarMapas(
    Map<String, dynamic> principal,
    Map<String, dynamic> complemento,
  ) {
    final resultado = <String, dynamic>{...complemento, ...principal};
    for (final entrada in complemento.entries) {
      if (_valorAusente(principal[entrada.key]) &&
          !_valorAusente(entrada.value)) {
        resultado[entrada.key] = entrada.value;
      }
    }
    return resultado;
  }

  static Map<String, dynamic>? _mapaDinamico(Object? valor) =>
      valor is Map ? Map<String, dynamic>.from(valor) : null;

  static String _chaveGrupo(Map<String, dynamic> grupo) {
    if (_grupoCardapio(grupo)) return 'cardapio';
    final id = (grupo['id'] ?? '').toString().trim();
    final tipo = (grupo['tipo'] ?? '').toString().trim();
    final titulo = _textoNormalizado(grupo['titulo']);
    if (titulo == 'observacao' || id == '12' || (id == '11' && tipo == '7')) {
      return 'observacao';
    }
    if (id.isNotEmpty && id != '0') return 'id:$id';
    return 'tipo:$tipo|titulo:$titulo';
  }

  static String _chaveItemGrupo(Map<String, dynamic> item) {
    final id = (item['id'] ?? '').toString().trim();
    final idProduto =
        (item['idProduto'] ?? item['id_produto'] ?? '').toString().trim();
    if (id.isNotEmpty && id != '0') return 'id:$id|produto:$idProduto';
    final codigo = (item['codigo'] ?? '').toString().trim();
    return 'codigo:$codigo|nome:${_textoNormalizado(item['nome'])}';
  }

  static bool _grupoCardapio(Map<String, dynamic> grupo) {
    if ((grupo['tipo'] ?? '').toString() == '8') return true;
    final titulo = _textoNormalizado(grupo['titulo']);
    if (titulo.contains('ingredientes do cardapio') || titulo == 'cardapio') {
      return true;
    }
    for (final dado in grupo['dados'] is List
        ? grupo['dados'] as List
        : const <dynamic>[]) {
      final mapa = _mapaDinamico(dado);
      if (mapa == null) continue;
      if (mapa['montagemCardapio'] != null ||
          mapa['montagem_cardapio'] != null ||
          mapa['montagem_json'] != null ||
          !_valorAusente(mapa['idCategoriaCardapio']) ||
          !_valorAusente(mapa['id_categoria_cardapio'])) {
        return true;
      }
    }
    return false;
  }

  static String _textoNormalizado(Object? valor) => (valor ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');

  static bool _valorAusente(Object? valor) =>
      valor == null || (valor is String && valor.trim().isEmpty);

  static bool _vazio(Object? valor) => (valor?.toString().trim() ?? '').isEmpty;

  static Map<String, dynamic> _produtoSomenteResumo(
      Modelowordprodutos produto) {
    final mapa = produto.toMap();
    final opcoesFinais = mapa['opcoesPacotesListaFinal'];
    final opcoesOriginais = mapa['opcoesPacotes'];
    final opcoes = opcoesFinais is List && opcoesFinais.isNotEmpty
        ? opcoesFinais
        : opcoesOriginais is List
            ? opcoesOriginais
            : const <dynamic>[];
    final saboresPizza = opcoes.where(_grupoSaboresPizza).toList();
    mapa['ingredientes'] = <dynamic>[];
    mapa['tamanhosPizza'] = null;
    mapa['opcoesPacotes'] = null;
    mapa['opcoesPacotesListaFinal'] =
        saboresPizza.isEmpty ? null : saboresPizza;
    mapa['observacao'] = null;
    return mapa;
  }

  static bool _grupoSaboresPizza(Object? opcao) {
    if (opcao is! Map) return false;
    final id = (opcao['id'] ?? '').toString().trim();
    final titulo = _textoNormalizado(opcao['titulo']);
    final dados = opcao['dados'];
    return (id == '10' ||
            (titulo.contains('sabores') && titulo.contains('pizza'))) &&
        dados is List &&
        dados.isNotEmpty;
  }

  static List<String> comprovantes(ServicoDelivery servico,
      PedidoDelivery pedido, List<Modelowordprodutos> produtos,
      {TipoCardapio tipo = TipoCardapio.delivery, ConfigDelivery? config}) {
    final numeroPedido =
        exigirNumeroPedidoOperacional(pedido.numeroOperacional);
    final grupos = <String, List<Modelowordprodutos>>{};
    if (tipo == TipoCardapio.balcao) {
      grupos[''] = produtos;
    } else {
      for (final p in produtos) {
        final computador = p.destinoDeImpressao?.nomedopc ?? '';
        grupos.putIfAbsent(computador, () => []).add(p);
      }
    }
    final usuario = servico.usuario.usuario;
    final comanda = tipo == TipoCardapio.balcao
        ? 'Balcão ${pedido.id}'
        : 'Delivery ${pedido.id}';
    // Sem a configuração local, preserva os detalhes para o servidor de
    // impressão aplicar a opção vigente da config_bigchef.
    final somenteResumo = pedido.tipoEntrega == '1' &&
        config != null &&
        !config.imprimirPreparoNoComprovanteConsumacao;
    return [
      for (final grupo in grupos.entries)
        jsonEncode({
          'idRequisicao':
              'delivery-${pedido.id}-${DateTime.now().microsecondsSinceEpoch}-${grupo.key}',
          'tipo': tipo.nome,
          'tipoImpressao': pedido.tipoEntrega == '1' ? '3' : '2',
          'protocoloImpressao': 2,
          'nomedopc': grupo.key,
          'nomeConexao': usuario?.nome ?? '',
          'produtos': grupo.value
              .map((produto) => somenteResumo
                  ? _produtoSomenteResumo(produto)
                  : produto.toMap())
              .toList(),
          'nomelancamento': pedido.pagamentos,
          'somaValorHistorico': pedido.pago.toStringAsFixed(2),
          'comanda': comanda,
          for (final campo in [
            'celularEmpresa',
            'cnpjEmpresa',
            'enderecoEmpresa',
            'nomeEmpresa',
            'celularCliente'
          ])
            campo: pedido.texto(campo),
          ...camposEnderecoComprovante(pedido),
          'total': pedido.total.toStringAsFixed(2),
          'permanencia': '',
          'valorentrega': pedido.texto('valordaentrega', '0'),
          'numeroPedido': numeroPedido,
          'tipodeentrega': pedido.tipoEntrega,
          'nomeCliente': pedido.nome.trim(),
          'valortroco': pedido.texto('valortroco', '0'),
          'observacaoDoPedido': pedido.observacao,
          'valordesconto': pedido.texto('valorDesconto', '0'),
          'valoracrescimo': pedido.texto('valorAcrescimo', '0'),
          'nomeUsuario': usuario?.nome ?? '',
          'idEmpresa': usuario?.empresa ?? '',
          'idUsuario': usuario?.id ?? '',
          ..._camposNumeroOperacional(config),
          'enviarDeVolta': true,
        })
    ];
  }

  /// Mantém cada parte do endereço separada para o servidor ampliar somente o
  /// Número, manter Bairro no tamanho da Cidade e imprimir Cidade/Complemento
  /// na linha seguinte.
  static Map<String, String> camposEnderecoComprovante(PedidoDelivery pedido) =>
      {
        'enderecoCliente': pedido.texto('enderecoCliente').trim(),
        'numeroCliente': pedido.texto('numeroCliente').trim(),
        'bairroCliente': pedido.texto('bairroCliente').trim(),
        'cidadeCliente': pedido.texto('cidadeCliente').trim(),
        'complementoCliente': pedido.texto('complementoCliente').trim(),
      };

  static Map<String, dynamic> _camposNumeroOperacional(ConfigDelivery? config) {
    if (config == null) return const {};
    return {
      'numerodopedidodestaquecomprovante':
          config.numerodopedidodestaquecomprovante,
      'numerodopedidodestaquepreparo': config.numerodopedidodestaquepreparo,
      if (config.controlaNumeroOperacionalPedido) ...{
        'ativarnumerooperacionalpedido': config.ativarnumerooperacionalpedido,
        'imprimirnumerooperacionalentregador':
            config.imprimirnumerooperacionalentregador,
        'imprimirnumerooperacionalconsumacao':
            config.imprimirnumerooperacionalconsumacao,
        'imprimirnumerooperacionalpreparo':
            config.imprimirnumerooperacionalpreparo,
      },
    };
  }

  static List<String> _comCamposNumeroOperacional(
      List<String> mensagens, ConfigDelivery? config) {
    final campos = _camposNumeroOperacional(config);
    if (campos.isEmpty) return mensagens;
    return [
      for (final mensagem in mensagens)
        jsonEncode({...jsonDecode(mensagem) as Map<String, dynamic>, ...campos})
    ];
  }
}
