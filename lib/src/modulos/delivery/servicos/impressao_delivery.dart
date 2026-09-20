import 'dart:convert';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/impressao.dart';
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
      ConfigDelivery? config}) async {
    final resultados = await Future.wait([
      servico.dadosCardapio(pedido.id),
      servico.detalhesLocais(pedido.id),
    ]);
    final dados = resultados[0] as Modeloworddadoscardapio;
    final detalhesLocais = resultados[1] as List<Modelowordprodutos>;
    final configuracao = config ?? await _configuracao(servico);
    final produtosBase = dados.produtos ?? <Modelowordprodutos>[];
    final produtos = produtosComDetalhesDoPedido(
      pedido,
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
              tipodeentrega: pedido.tipoEntrega,
              nomeCliente: pedido.nome,
              nomeEmpresa: dados.nomeEmpresa ?? '',
              comanda: 'Delivery ${pedido.id}',
              numeroPedido: pedido.numero),
          configuracao,
        ),
      if (!preparo || ambos)
        ...comprovantes(servico, pedido.comEndereco(dados), produtos,
            config: configuracao),
    ];
    await server.enviarImpressoes(mensagens);
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
      'ingredientes',
    ]) {
      if (!_listaTemItens(mapa[campo]) && _listaTemItens(mapaLocal[campo])) {
        mapa[campo] = mapaLocal[campo];
      }
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
    if (!_listaTemItens(mapaDetalhado['opcoesPacotesListaFinal']) &&
        _listaTemItens(mapaBase['opcoesPacotesListaFinal'])) {
      mapa['opcoesPacotesListaFinal'] = mapaBase['opcoesPacotesListaFinal'];
    }
    if (!_listaTemItens(mapaDetalhado['opcoesPacotes']) &&
        _listaTemItens(mapaBase['opcoesPacotes'])) {
      mapa['opcoesPacotes'] = mapaBase['opcoesPacotes'];
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

  static bool _vazio(Object? valor) => (valor?.toString().trim() ?? '').isEmpty;

  static List<String> comprovantes(ServicoDelivery servico,
      PedidoDelivery pedido, List<Modelowordprodutos> produtos,
      {TipoCardapio tipo = TipoCardapio.delivery, ConfigDelivery? config}) {
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
          'produtos': grupo.value.map((p) => p.toMap()).toList(),
          'nomelancamento': pedido.pagamentos,
          'somaValorHistorico': pedido.pago.toStringAsFixed(2),
          'comanda': comanda,
          for (final campo in [
            'celularEmpresa',
            'cnpjEmpresa',
            'enderecoEmpresa',
            'nomeEmpresa',
            'celularCliente',
            'enderecoCliente',
            'numeroCliente',
            'bairroCliente',
            'complementoCliente',
            'cidadeCliente'
          ])
            campo: pedido.texto(campo),
          'total': pedido.total.toStringAsFixed(2),
          'permanencia': '',
          'valorentrega': pedido.texto('valordaentrega', '0'),
          'numeroPedido': pedido.numero,
          'tipodeentrega': pedido.tipoEntrega,
          'nomeCliente': pedido.nome,
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
