import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/foundation.dart';

class EdicaoProdutoCarrinho extends ChangeNotifier {
  final Modelowordprodutos original;
  final ServicoProduto servico;
  final ServicosCategoria categorias;
  final ProvedorCardapio cardapio;
  late final ProvedorProduto produto;
  late final ProvedorProdutos pesquisa;
  List<ModeloOpcoesPacotes> opcoes = [];
  Modelowordprodutos? _catalogo;
  String observacao;
  bool carregando = true;
  String? erro;
  bool _descartado = false;
  double _composicaoInicial = 0;
  String _assinaturaInicial = '';
  late final _saboresOriginais = _dadosOriginais(10);

  EdicaoProdutoCarrinho({
    required Modelowordprodutos item,
    required this.servico,
    required this.categorias,
    required UsuarioProvedor usuario,
  })  : original = Modelowordprodutos.fromMap(item.toMap()),
        observacao = item.observacao ?? '',
        cardapio = ProvedorCardapio(categorias, usuario) {
    produto = ProvedorProduto(cardapio, usuario);
    pesquisa = ProvedorProdutos(servico);
    if (observacao.isEmpty) {
      observacao = (original.opcoesPacotesListaFinal ?? [])
              .where(_ehObservacao)
              .firstOrNull
              ?.dados
              ?.firstOrNull
              ?.nome ??
          '';
    }
  }

  static bool _ehObservacao(ModeloOpcoesPacotes opcao) =>
      opcao.tipo == 7 || opcao.titulo.toLowerCase() == 'observação';

  List<ModeloDadosOpcoesPacotes> _dadosOriginais(int id) =>
      (original.opcoesPacotesListaFinal ?? [])
          .where((opcao) => opcao.id == id)
          .firstOrNull
          ?.dados ??
      [];

  bool get pizza => _saboresOriginais.isNotEmpty;
  String get _idTamanhoOriginal => _dadosOriginais(9).firstOrNull?.id ?? '0';
  String get idTamanho => cardapio.tamanhosPizza?.id ?? _idTamanhoOriginal;
  bool get tamanhoAlterado => idTamanho != _idTamanhoOriginal;
  double get valorUnitario => carregando || erro != null
      ? double.parse(original.valorVenda)
      : double.parse((double.parse(original.valorVenda) +
              produto.valorVenda -
              _composicaoInicial)
          .toStringAsFixed(2));
  double get total => valorUnitario * (original.quantidade ?? 1);
  int get limiteBordas => math.max(
      int.tryParse(cardapio.configBigchef?.saborlimitedeborda ?? '0') ?? 0,
      math.max(1, original.limiteSaboresBorda ?? _dadosOriginais(6).length));
  bool get saboresAlterados =>
      tamanhoAlterado ||
      !listEquals(cardapio.saboresPizzaSelecionados.map((s) => s.id).toList(),
          _saboresOriginais.map((s) => s.id).toList());
  bool get alterado =>
      !carregando && erro == null && _assinatura() != _assinaturaInicial;

  String _assinatura() => jsonEncode({
        'opcoes':
            produto.opcoesPacotesListaFinal.map((o) => o.toMap()).toList(),
        'tamanho': idTamanho,
        'sabores': cardapio.saboresPizzaSelecionados.map((s) => s.id).toList(),
        'borda': cardapio.limiteSaborBordaSelecionado,
        'observacao': observacao,
      });

  EdicaoProdutoCarrinho criarRascunho() {
    final rascunho = EdicaoProdutoCarrinho(
      item: original,
      servico: servico,
      categorias: categorias,
      usuario: cardapio.usuarioProvedor,
    );
    rascunho
      .._catalogo = _catalogo
      ..opcoes =
          opcoes.map((o) => ModeloOpcoesPacotes.fromMap(o.toMap())).toList()
      ..observacao = observacao
      .._composicaoInicial = _composicaoInicial
      ..carregando = false;
    rascunho.cardapio
      ..configBigchef = cardapio.configBigchef
      ..categorias = cardapio.categorias
      ..tamanhosPizza = cardapio.tamanhosPizza == null
          ? null
          : ModeloTamanhosPizza.fromMap(cardapio.tamanhosPizza!.toMap());
    rascunho.aplicarRascunho(this);
    rascunho._assinaturaInicial = rascunho._assinatura();
    return rascunho;
  }

  void aplicarRascunho(EdicaoProdutoCarrinho rascunho) {
    // Copias independentes: salvar uma etapa ainda nao grava no carrinho.
    cardapio
      ..tamanhosPizza = rascunho.cardapio.tamanhosPizza == null
          ? null
          : ModeloTamanhosPizza.fromMap(
              rascunho.cardapio.tamanhosPizza!.toMap())
      ..saboresPizzaSelecionados = rascunho.cardapio.saboresPizzaSelecionados
          .map((s) => Modelowordprodutos.fromMap(s.toMap()))
          .toList()
      ..limiteSaborBordaSelecionado =
          rascunho.cardapio.limiteSaborBordaSelecionado;
    produto
      ..opcoesPacotesListaFinal = rascunho.produto.opcoesPacotesListaFinal
          .map((o) => ModeloOpcoesPacotes.fromMap(o.toMap()))
          .toList()
      ..quantidade = rascunho.produto.quantidade
      ..valorVendaOriginal = rascunho.produto.valorVendaOriginal;
    produto.calcularValorVenda(false, '0');
    notifyListeners();
  }

  Future<List<Modelowordprodutos>> _carregarSabores() async {
    final catalogoPorId = <String, Modelowordprodutos>{};
    final categoriasCarregadas = <String>{};
    final sabores = <Modelowordprodutos>[];
    for (final selecionado in _saboresOriginais) {
      if (!catalogoPorId.containsKey(selecionado.id)) {
        final detalhes = selecionado.id == original.id
            ? _catalogo
            : await servico.listarPorId(selecionado.id, idTamanho);
        if (_descartado) return [];
        if (detalhes == null) {
          throw StateError('Sabor indisponível: ${selecionado.id}.');
        }
        // A consulta por ID traz opcoes, mas o nome real e os precos por tamanho
        // da pizza pertencem ao catalogo paginado do cardapio.
        if (categoriasCarregadas.add(detalhes.categoria)) {
          for (var pagina = 1;; pagina++) {
            final lista =
                await servico.listarPorCategoria(detalhes.categoria, pagina);
            if (_descartado) return [];
            final quantidadeAnterior = catalogoPorId.length;
            for (final item in lista) {
              catalogoPorId[item.id] = item;
            }
            if (lista.length < 15) break;
            if (catalogoPorId.length == quantidadeAnterior) {
              throw StateError('Paginação de sabores sem novos produtos.');
            }
          }
        }
      }
      final sabor = catalogoPorId[selecionado.id];
      if (sabor == null || cardapio.tamanhoPizzaDoProduto(sabor) == null) {
        throw StateError(
            'Sabor ${selecionado.id} indisponível no tamanho $idTamanho.');
      }
      sabores.add(Modelowordprodutos.fromMap(sabor.toMap()));
    }
    return sabores;
  }

  Future<void> carregar({ModeloConfigBigchef? configuracao}) async {
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      _catalogo = await servico.listarPorId(original.id, idTamanho);
      if (_descartado) return;
      if (_catalogo == null) throw StateError('Produto indisponível.');
      cardapio.configBigchef = configuracao;
      if (pizza) {
        final listaCategorias = await categorias.listar();
        if (_descartado) return;
        cardapio.categorias = listaCategorias;
        final tamanho = listaCategorias
            .expand((c) => c.tamanhosPizza ?? [])
            .where((t) => t.id == idTamanho)
            .firstOrNull;
        if (tamanho == null) throw StateError('Tamanho indisponível.');
        cardapio.tamanhosPizza = tamanho;
        final sabores = await _carregarSabores();
        if (_descartado) return;
        cardapio.saboresPizzaSelecionados = sabores;
      }
      final selecionadas = (original.opcoesPacotesListaFinal ?? [])
          .where((o) => o.id != 9 && o.id != 10 && !_ehObservacao(o))
          .map((o) => ModeloOpcoesPacotes.fromMap(o.toMap()))
          .toList();
      opcoes = (_catalogo!.opcoesPacotes ?? [])
          .where((o) => o.id != 9 && o.id != 10 && !_ehObservacao(o))
          .map((o) => ModeloOpcoesPacotes.fromMap(o.toMap()))
          .toList();
      // Conserva escolhas anteriores mesmo quando deixaram de aparecer no catalogo.
      for (final selecionada in selecionadas) {
        final disponivel =
            opcoes.where((o) => o.id == selecionada.id).firstOrNull;
        if (disponivel == null) {
          opcoes.add(ModeloOpcoesPacotes.fromMap(selecionada.toMap()));
        } else if (selecionada.dados != null) {
          disponivel.dados ??= [];
          for (final dado in selecionada.dados!) {
            if (!disponivel.dados!.any((d) => d.id == dado.id)) {
              disponivel.dados!
                  .add(ModeloDadosOpcoesPacotes.fromMap(dado.toMap()));
            }
          }
        }
      }
      for (final opcao in opcoes) {
        if (!selecionadas.any((o) => o.id == opcao.id)) {
          selecionadas
              .add(ModeloOpcoesPacotes.fromMap(opcao.toMap())..dados = []);
        }
      }
      produto.opcoesPacotesListaFinal = selecionadas;
      for (final adicional in produto.retornarDadosPorID([7], false, '0')) {
        adicional.quantidade ??= 1;
      }
      cardapio.limiteSaborBordaSelecionado =
          math.max(1, original.limiteSaboresBorda ?? _dadosOriginais(6).length);
      produto.quantidade = (original.quantidade ?? 1).toInt();
      produto.valorVendaOriginal = pizza
          ? double.parse(_dadosOriginais(9).first.valor ?? '0')
          : double.parse(_catalogo!.valorVenda);
      produto.calcularValorVenda(false, '0');
      // Aplica apenas a diferenca da edicao, sem cobrar a montagem duas vezes.
      _composicaoInicial = produto.valorVenda;
      final bordasOriginais = (original.opcoesPacotesListaFinal ?? [])
          .where((o) => o.id == 6)
          .firstOrNull;
      if (pizza && bordasOriginais != null) {
        _composicaoInicial += ValoresPizza.subtotal(original, bordasOriginais) -
            produto.calcularPrecoBorda();
      }
      _assinaturaInicial = _assinatura();
    } catch (error, stackTrace) {
      developer.log('Falha ao carregar produto ${original.id} para edição.',
          name: 'EdicaoProdutoCarrinho', error: error, stackTrace: stackTrace);
      erro = 'Não foi possível carregar as opções do produto. Tente novamente.';
    } finally {
      if (!_descartado) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  String? selecionarSabor(Modelowordprodutos sabor) {
    final selecionado =
        cardapio.saboresPizzaSelecionados.any((s) => s.id == sabor.id);
    if (!selecionado &&
        cardapio.saboresPizzaSelecionados.length >=
            int.parse(cardapio.tamanhosPizza!.saboreslimite)) {
      return 'Limite de sabores atingido. Desmarque um sabor para trocar.';
    }
    cardapio.selecionarSaborPizza(sabor);
    produto.valorVendaOriginal = saboresAlterados
        ? cardapio.calcularPrecoPizza()
        : double.parse(_dadosOriginais(9).first.valor ?? '0');
    produto.calcularValorVenda(false, '0');
    notifyListeners();
    return null;
  }

  bool selecionarTamanhoPizza(ModeloTamanhosPizza tamanho) {
    if (cardapio.tamanhosPizza?.id == tamanho.id) return false;
    cardapio.tamanhosPizza = tamanho;
    produto.valorVendaOriginal = cardapio.saboresPizzaSelecionados.isEmpty
        ? 0
        : cardapio.calcularPrecoPizza();
    produto.calcularValorVenda(false, '0');
    notifyListeners();
    return true;
  }

  void selecionarLimiteBorda(int limite) {
    if (limite < produto.retornarDadosPorID([6], false, '0').length) return;
    cardapio.limiteSaborBordaSelecionado = limite;
    produto.calcularValorVenda(false, '0');
    notifyListeners();
  }

  String? validar() {
    if (pizza && cardapio.saboresPizzaSelecionados.isEmpty) {
      return 'Selecione pelo menos um sabor de pizza.';
    }
    for (final opcao in opcoes) {
      if ((opcao.obrigatorio || opcao.id == 4 || opcao.id == 11) &&
          (opcao.dados?.isNotEmpty ?? false) &&
          produto.retornarDadosPorID([opcao.id], false, '0').isEmpty) {
        return 'Confira a seleção: ${opcao.titulo}.';
      }
    }
    return null;
  }

  Future<Modelowordprodutos> concluir() async {
    if (carregando || erro != null) {
      throw StateError('As opções do produto ainda não foram carregadas.');
    }
    final erroValidacao = validar();
    if (erroValidacao != null) throw StateError(erroValidacao);
    final resultado = Modelowordprodutos.fromMap(original.toMap());
    final montagem = <ModeloOpcoesPacotes>[];
    if (pizza) {
      if (saboresAlterados) {
        final saborPrincipal = Modelowordprodutos.fromMap(
            cardapio.saboresPizzaSelecionados.first.toMap());
        final primeiro =
            await servico.listarPorId(saborPrincipal.id, idTamanho);
        if (primeiro == null) throw StateError('Produto indisponível.');
        resultado
          ..id = primeiro.id
          ..hashprodutos = primeiro.hashprodutos
          ..nome = primeiro.nome
          ..codigo = primeiro.codigo
          ..categoria = primeiro.categoria
          ..nomeCategoria = primeiro.nomeCategoria
          ..imprimirCodigoProdutoPreparo = primeiro.imprimirCodigoProdutoPreparo
          ..destinoDeImpressao = primeiro.destinoDeImpressao
          ..habilsepardelivery = primeiro.habilsepardelivery
          ..habilItensRetirada = primeiro.habilItensRetirada
          ..ingredientes = primeiro.ingredientes
          ..tamanhosPizza = saborPrincipal.tamanhosPizza
          ..foto = primeiro.foto;
      }
      montagem.add(ModeloOpcoesPacotes(
        id: 9,
        titulo: 'Tamanho Pizza',
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: idTamanho,
            nome: cardapio.tamanhosPizza!.nomedotamanho,
            valor: produto.valorVendaOriginal.toStringAsFixed(2),
          )
        ],
      ));
      final sabores = cardapio.saboresPizzaSelecionados;
      montagem.add(ModeloOpcoesPacotes(
        id: 10,
        titulo: 'Sabores Pizza (${sabores.length})',
        obrigatorio: false,
        dados: saboresAlterados
            ? cardapio.saboresParaCarrinho()
            : _saboresOriginais,
      ));
    }
    montagem.addAll(produto.opcoesParaCarrinho());
    if (observacao.trim().isNotEmpty) {
      montagem.add(ModeloOpcoesPacotes(
        id: 11,
        titulo: 'Observação',
        tipo: 7,
        obrigatorio: false,
        dados: [ModeloDadosOpcoesPacotes(id: '0', nome: observacao.trim())],
      ));
    }
    resultado
      ..opcoesPacotes =
          opcoes.map((o) => ModeloOpcoesPacotes.fromMap(o.toMap())).toList()
      ..opcoesPacotesListaFinal =
          montagem.map((o) => ModeloOpcoesPacotes.fromMap(o.toMap())).toList()
      ..observacao = observacao.trim()
      ..valorVenda = valorUnitario.toStringAsFixed(2)
      ..limiteSaboresBorda = cardapio.limiteSaborBordaSelecionado;
    return resultado;
  }

  @override
  void dispose() {
    _descartado = true;
    produto.dispose();
    cardapio.dispose();
    pesquisa.dispose();
    super.dispose();
  }
}
