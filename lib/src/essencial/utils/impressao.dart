import 'dart:convert';
import 'dart:async';
import 'dart:math';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/material.dart';

class Impressao {
  static int _sequencialRequisicao = 0;

  static String _gerarIdentificadorRequisicao() {
    _sequencialRequisicao++;
    final aleatorio = Random.secure().nextInt(0x7fffffff).toRadixString(16);
    return '${DateTime.now().microsecondsSinceEpoch}_${_sequencialRequisicao}_$aleatorio';
  }

  static String _normalizarNomeComputadorDestino(
      String? nomeComputadorDestino) {
    return (nomeComputadorDestino ?? '').trim();
  }

  static String _normalizarLocal(String local) {
    final localNormalizado = local.trim();
    return localNormalizado.isEmpty ? 'Sem Mesa' : localNormalizado;
  }

  static Map<String, List<Modelowordprodutos>>
      _agruparProdutosPorComputadorDestino(
    List<Modelowordprodutos> produtos,
  ) {
    final Map<String, List<Modelowordprodutos>> grupos =
        <String, List<Modelowordprodutos>>{};

    for (final Modelowordprodutos produto in produtos) {
      final String nomeComputadorDestino = _normalizarNomeComputadorDestino(
        produto.destinoDeImpressao?.nomedopc,
      );

      if (nomeComputadorDestino.isEmpty) {
        continue;
      }

      grupos
          .putIfAbsent(nomeComputadorDestino, () => <Modelowordprodutos>[])
          .add(produto);
    }

    return grupos;
  }

  static List<String> prepararComprovanteDePedido({
    List<Modelowordprodutos> produtos = const [],
    String comanda = 'Sem Comanda',
    String numeroPedido = '0',
    String nomeCliente = '',
    String nomeEmpresa = '',
    String tipodeentrega = '',
    String local = '',
    TipoCardapio tipoTela = TipoCardapio.balcao,
    bool enviarDeVolta = true,
  }) {
    if (!enviarDeVolta || produtos.isEmpty) return [];
    final usuario = Modular.get<UsuarioProvedor>();
    final localImpressao = _normalizarLocal(local);
    final grupos = <String, List<Modelowordprodutos>>{};
    void adicionar(Modelowordprodutos produto) {
      if (!_temDestinoConfigurado(produto.destinoDeImpressao)) return;
      final destino = _normalizarNomeComputadorDestino(
          produto.destinoDeImpressao?.nomedopc);
      grupos.putIfAbsent(destino, () => []).add(produto);
    }

    for (final produto in produtos) {
      final opcoes =
          produto.opcoesPacotesListaFinal ?? produto.opcoesPacotes ?? [];
      if (opcoes.isNotEmpty &&
          opcoes.every((opcao) => opcao.titulo == 'Combos')) {
        for (final componente in opcoes
            .expand((opcao) => opcao.produtos ?? <Modelowordprodutos>[])) {
          adicionar(componente);
        }
      } else {
        adicionar(produto);
      }
    }
    // Serializa todos os destinos antes de qualquer operacao assincrona ou limpeza do carrinho.
    return grupos.entries
        .map((grupo) => jsonEncode({
              'idRequisicao': _gerarIdentificadorRequisicao(),
              'tipo': tipoTela.nome,
              'tipoImpressao': '1',
              'protocoloImpressao': 2,
              if (grupo.key.isNotEmpty) 'nomedopc': grupo.key,
              'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
              'produtos': grupo.value
                  .map((produto) => DadosImpressaoPreparo.produto(
                        produto,
                        modeloValorBorda: usuario
                            .usuario?.configuracoes?.modelovaloradicionalpizza,
                      ))
                  .toList(),
              'comanda': comanda,
              'numeroPedido': numeroPedido,
              'nomeCliente': nomeCliente,
              'nomeEmpresa': nomeEmpresa,
              'tipodeentrega': tipodeentrega,
              'local': localImpressao,
              'nomeUsuario': usuario.usuario?.nome ?? '',
              'idEmpresa': usuario.usuario?.empresa ?? '0',
              'idUsuario': usuario.usuario?.id ?? '1',
              'enviarDeVolta': enviarDeVolta,
            }))
        .toList(growable: false);
  }

  static bool _temDestinoConfigurado(ModeloDestinoImpressao? destino) {
    if (destino == null) return false;
    final nome = destino.nomeDaImpressora.trim().toLowerCase();
    return nome.isNotEmpty && nome != 'sem impressora';
  }

  static List<String> prepararCancelamentoDeItem({
    required Modelowordprodutos produto,
    ModeloDestinoImpressao? destinoCaixa,
    String comanda = 'Sem Comanda',
    String numeroPedido = '0',
    String nomeCliente = '',
    String nomeEmpresa = '',
    String tipodeentrega = '',
    String local = '',
    TipoCardapio tipoTela = TipoCardapio.balcao,
  }) {
    final itemCancelado = Modelowordprodutos.fromMap(produto.toMap());
    final destinoOriginal = produto.destinoDeImpressao;
    if (!_temDestinoConfigurado(destinoOriginal) &&
        destinoOriginal?.nomeDaImpressora.trim().toLowerCase() !=
            'sem impressora') {
      itemCancelado.destinoDeImpressao = destinoCaixa;
    }
    itemCancelado.nome = 'CANCELAMENTO - ${produto.nome}';
    final observacaoOriginal = (produto.observacao ?? '').trim();
    itemCancelado.observacao = observacaoOriginal.isEmpty
        ? 'Item cancelado pelo App Garçom.'
        : 'Item cancelado pelo App Garçom. Obs. original: $observacaoOriginal';

    final mensagens = prepararComprovanteDePedido(
      produtos: [itemCancelado],
      comanda: comanda,
      numeroPedido: numeroPedido,
      nomeCliente: nomeCliente,
      nomeEmpresa: nomeEmpresa,
      tipodeentrega: tipodeentrega,
      local: local,
      tipoTela: tipoTela,
    );

    return mensagens.map((mensagem) {
      final dados = jsonDecode(mensagem) as Map<String, dynamic>;
      dados['cancelamento'] = true;
      dados['tipoComprovante'] = 'cancelamento_item';
      dados['tituloImpressao'] = 'CANCELAMENTO DE ITEM';
      return jsonEncode(dados);
    }).toList(growable: false);
  }

  static Future<void> comprovanteDePedido({
    List<Modelowordprodutos> produtos = const [],
    String comanda = 'Sem Comanda',
    String numeroPedido = '0',
    String nomeCliente = '',
    String nomeEmpresa = '',
    String tipodeentrega = '',
    String local = '',
    TipoCardapio tipoTela = TipoCardapio.balcao,
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
  }) async {
    final mensagens = prepararComprovanteDePedido(
      produtos: produtos,
      comanda: comanda,
      numeroPedido: numeroPedido,
      nomeCliente: nomeCliente,
      nomeEmpresa: nomeEmpresa,
      tipodeentrega: tipodeentrega,
      local: local,
      tipoTela: tipoTela,
      enviarDeVolta: enviarDeVolta,
    );
    if (mensagens.isNotEmpty) {
      // O pagamento ja foi salvo. A falha de impressao nao bloqueia a saida.
      unawaited(() async {
        try {
          await Modular.get<Server>().enviarImpressoes(mensagens);
        } catch (_) {
          final context = navigatorKey?.currentContext;
          if (context == null || !context.mounted) return;
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
            content: Text(
                'Pedido salvo. A impressão não foi salva; confira com a cozinha.'),
            showCloseIcon: true,
          ));
        }
      }());
    }
  }

  static Future<void> comprovanteDeCupomNaoFiscal({
    ModeloDestinoImpressao? destinoDeImpressao,
    String idVenda = '0',
    String tipo = '',
  }) async {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    if (destinoDeImpressao != null || idVenda.isNotEmpty) {
      server.write(jsonEncode({
        'idRequisicao': _gerarIdentificadorRequisicao(),
        'tipoImpressao': '4',
        'nomedopc': destinoDeImpressao?.nomedopc ?? '',
        'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
        'destinoDeImpressao': destinoDeImpressao?.toMap(),
        'nomeDaImpressora': destinoDeImpressao?.nomeDaImpressora ?? '',
        'tamanhoDoPapel': destinoDeImpressao?.tamanhoDoPapel ?? '',
        'avancoPapel': destinoDeImpressao?.avancoPapel ?? '',
        'id': idVenda,
        'tipo': tipo,
        'nomeUsuario': usuario.usuario?.nome ?? '',
        'idEmpresa': usuario.usuario?.empresa ?? '0',
        'idUsuario': usuario.usuario?.id ?? '1',
      }));
    }
  }

  static Future<void> comprovanteDeCupomFiscal({
    ModeloDestinoImpressao? destinoDeImpressao,
    String idVenda = '0',
    String tipo = '',
  }) async {
    // ComprovanteDeCupomFiscal(
    //   idVenda,
    //   destinoDeImpressao!,
    // ).call(tipo);
  }

  static Future<void> comprovanteCaixaFechamento({
    String datainicial = '',
    String datafinal = '',
    String tipodefechamentocaixa = '',
    ModeloDestinoImpressao? destinoImpressaoCaixa,
  }) async {
    // ComprovanteCaixaFechamento(
    //   datainicial,
    //   datafinal,
    //   tipodefechamentocaixa,
    //   destinoImpressaoCaixa,
    // ).call();
  }

  static Future<void> comprovanteCaixaMovimento({
    String tipomovimento = '',
    ModeloDestinoImpressao? destinoImpressaoCaixa,
  }) async {
    // ComprovanteCaixaMovimento(
    //   tipomovimento,
    //   destinoImpressaoCaixa,
    // ).call();
  }

  static void comprovanteDoEntregador({
    List<Modelowordprodutos> produtos = const [],
    List<ModeloNomeLancamento> nomelancamento = const [],
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String nomeEmpresa = '',
    String total = '',
    String permanencia = '',
    String nomeCliente = '',
    String celularCliente = '',
    String enderecoCliente = '',
    String valortroco = '0',
    String valorentrega = '0',
    String numeroPedido = '0',
    String tipodeentrega = '0',
    String numeroCliente = '',
    String bairroCliente = '',
    String complementoCliente = '',
    String cidadeCliente = '',
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
  }) {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    for (var element in produtos) {
      element.quantidadeController = null;
    }

    if (enviarDeVolta == true && produtos.isNotEmpty) {
      final Map<String, List<Modelowordprodutos>> grupos =
          _agruparProdutosPorComputadorDestino(produtos);

      if (grupos.isNotEmpty) {
        for (final MapEntry<String, List<Modelowordprodutos>> grupo
            in grupos.entries) {
          server.write(jsonEncode({
            'idRequisicao': _gerarIdentificadorRequisicao(),
            'tipo': TipoCardapio.delivery.nome,
            'tipoImpressao': '3',
            'nomedopc': grupo.key,
            'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
            'produtos': grupo.value.map((e) => e.toMap()).toList(),
            'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
            'somaValorHistorico': somaValorHistorico,
            'celularEmpresa': celularEmpresa,
            'cnpjEmpresa': cnpjEmpresa,
            'enderecoEmpresa': enderecoEmpresa,
            'nomeEmpresa': nomeEmpresa,
            'total': total,
            'permanencia': permanencia,
            'valorentrega': valorentrega,
            'numeroPedido': numeroPedido,
            'tipodeentrega': tipodeentrega,
            'nomeCliente': nomeCliente,
            'celularCliente': celularCliente,
            'enderecoCliente': enderecoCliente,
            'valortroco': valortroco,
            'numeroCliente': numeroCliente,
            'bairroCliente': bairroCliente,
            'complementoCliente': complementoCliente,
            'cidadeCliente': cidadeCliente,
            'nomeUsuario': usuario.usuario?.nome ?? '',
            'idEmpresa': usuario.usuario?.empresa ?? '0',
            'idUsuario': usuario.usuario?.id ?? '1',
            'enviarDeVolta': enviarDeVolta,
          }));
        }
        return;
      }

      server.write(jsonEncode({
        'idRequisicao': _gerarIdentificadorRequisicao(),
        'tipo': TipoCardapio.delivery.nome,
        'tipoImpressao': '3',
        'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
        'produtos': produtos.map((e) => e.toMap()).toList(),
        'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
        'somaValorHistorico': somaValorHistorico,
        'celularEmpresa': celularEmpresa,
        'cnpjEmpresa': cnpjEmpresa,
        'enderecoEmpresa': enderecoEmpresa,
        'nomeEmpresa': nomeEmpresa,
        'total': total,
        'permanencia': permanencia,
        'valorentrega': valorentrega,
        'numeroPedido': numeroPedido,
        'tipodeentrega': tipodeentrega,
        'nomeCliente': nomeCliente,
        'celularCliente': celularCliente,
        'enderecoCliente': enderecoCliente,
        'valortroco': valortroco,
        'numeroCliente': numeroCliente,
        'bairroCliente': bairroCliente,
        'complementoCliente': complementoCliente,
        'cidadeCliente': cidadeCliente,
        'nomeUsuario': usuario.usuario?.nome ?? '',
        'idEmpresa': usuario.usuario?.empresa ?? '0',
        'idUsuario': usuario.usuario?.id ?? '1',
        'enviarDeVolta': enviarDeVolta,
      }));
    }
  }

  static void comprovanteDeConsumo({
    List<Modelowordprodutos> produtos = const [],
    List<ModeloNomeLancamento> nomelancamento = const [],
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String nomeEmpresa = '',
    String numeroPedido = '',
    String total = '',
    String local = '',
    String permanencia = '',
    String valorentrega = '',
    String tipodeentrega = '',
    String nomeCliente = '',
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
    TipoCardapio tipoTela = TipoCardapio.delivery,
    bool agruparPorDestino = true,
  }) async {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    for (var element in produtos) {
      element.quantidadeController = null;
    }

    if (enviarDeVolta == true && produtos.isNotEmpty) {
      final Map<String, List<Modelowordprodutos>> grupos = agruparPorDestino
          ? _agruparProdutosPorComputadorDestino(produtos)
          : <String, List<Modelowordprodutos>>{};

      if (grupos.isNotEmpty) {
        for (final MapEntry<String, List<Modelowordprodutos>> grupo
            in grupos.entries) {
          server.write(jsonEncode({
            'idRequisicao': _gerarIdentificadorRequisicao(),
            'tipo': tipoTela.nome,
            'tipoImpressao': '2',
            'nomedopc': grupo.key,
            'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
            'produtos': grupo.value.map((e) => e.toMap()).toList(),
            'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
            'somaValorHistorico': somaValorHistorico,
            'celularEmpresa': celularEmpresa,
            'cnpjEmpresa': cnpjEmpresa,
            'enderecoEmpresa': enderecoEmpresa,
            'nomeEmpresa': nomeEmpresa,
            'numeroPedido': numeroPedido,
            'total': total,
            'local': local,
            'permanencia': permanencia,
            'valorentrega': valorentrega,
            'tipodeentrega': tipodeentrega,
            'nomeUsuario': usuario.usuario?.nome ?? '',
            'idEmpresa': usuario.usuario?.empresa ?? '0',
            'idUsuario': usuario.usuario?.id ?? '1',
            'nomeCliente': nomeCliente,
            'enviarDeVolta': enviarDeVolta,
          }));
        }
        return;
      }

      server.write(jsonEncode({
        'idRequisicao': _gerarIdentificadorRequisicao(),
        'tipo': tipoTela.nome,
        'tipoImpressao': '2',
        'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
        'produtos': produtos.map((e) => e.toMap()).toList(),
        'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
        'somaValorHistorico': somaValorHistorico,
        'celularEmpresa': celularEmpresa,
        'cnpjEmpresa': cnpjEmpresa,
        'enderecoEmpresa': enderecoEmpresa,
        'nomeEmpresa': nomeEmpresa,
        'numeroPedido': numeroPedido,
        'total': total,
        'local': local,
        'permanencia': permanencia,
        'valorentrega': valorentrega,
        'tipodeentrega': tipodeentrega,
        'nomeUsuario': usuario.usuario?.nome ?? '',
        'idEmpresa': usuario.usuario?.empresa ?? '0',
        'idUsuario': usuario.usuario?.id ?? '1',
        'nomeCliente': nomeCliente,
        'enviarDeVolta': enviarDeVolta,
      }));
    }
  }
}
