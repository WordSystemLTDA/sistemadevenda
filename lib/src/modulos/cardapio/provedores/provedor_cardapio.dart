import 'dart:convert';
import 'dart:math' as math;

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProvedorCardapio extends ChangeNotifier {
  final ServicosCategoria _categoriaService;
  final UsuarioProvedor usuarioProvedor;

  ProvedorCardapio(this._categoriaService, this.usuarioProvedor) {
    _configBigchef = usuarioProvedor.configbigchef;
  }

  TipoCardapio _tipo = TipoCardapio.comanda;
  TipoCardapio get tipo => _tipo;
  set tipo(TipoCardapio value) {
    _tipo = value;
    notifyListeners();
  }

  String _idComanda = '';
  String get idComanda => _idComanda;
  set idComanda(String value) {
    _idComanda = value;
    notifyListeners();
  }

  String _idMesa = '';
  String get idMesa => _idMesa;
  set idMesa(String value) {
    _idMesa = value;
    notifyListeners();
  }

  String _idCliente = '';
  String get idCliente => _idCliente;
  set idCliente(String value) {
    _idCliente = value;
    notifyListeners();
  }

  String _id = '';
  String get id => _id;
  set id(String value) {
    _id = value;
    notifyListeners();
  }

  String _tipodeentrega = '';
  String get tipodeentrega => _tipodeentrega;
  set tipodeentrega(String value) {
    _tipodeentrega = value;
    notifyListeners();
  }

  ModeloTamanhosPizza? _tamanhosPizza;
  ModeloTamanhosPizza? get tamanhosPizza => _tamanhosPizza;
  set tamanhosPizza(ModeloTamanhosPizza? value) {
    _tamanhosPizza = value;
    if (value == null) {
      _saboresPizzaSelecionados = [];
    } else {
      _saboresPizzaSelecionados = _saboresPizzaSelecionados
          .where((produto) => tamanhoPizzaDoProduto(produto) != null)
          .toList();
      if (_saboresPizzaSelecionados.length > int.parse(value.saboreslimite)) {
        _saboresPizzaSelecionados = [];
      }
    }
    notifyListeners();
  }

  List<Modelowordprodutos> _saboresPizzaSelecionados = [];
  List<Modelowordprodutos> get saboresPizzaSelecionados =>
      _saboresPizzaSelecionados;
  set saboresPizzaSelecionados(List<Modelowordprodutos> value) {
    _saboresPizzaSelecionados = value;
    notifyListeners();
  }

  List<ModeloCategoria> _categorias = [];
  String _assinaturaCategorias = '[]';
  List<ModeloCategoria> get categorias => _categorias;
  set categorias(List<ModeloCategoria> value) {
    final assinatura =
        jsonEncode(value.map((categoria) => categoria.toMap()).toList());
    final alterou = assinatura != _assinaturaCategorias;
    _categorias = value;
    _assinaturaCategorias = assinatura;
    if (alterou) notifyListeners();
  }

  ModeloConfigBigchef? _configBigchef;
  Future<void>? _carregamentoConfigBigChef;
  ModeloConfigBigchef? get configBigchef => _configBigchef;
  set configBigchef(ModeloConfigBigchef? value) {
    _configBigchef = value;
    usuarioProvedor.setConfigBigChef(value);
    notifyListeners();
  }

  int _limiteSaborBordaSelecionado = -1;
  int get limiteSaborBordaSelecionado => _limiteSaborBordaSelecionado;
  set limiteSaborBordaSelecionado(int value) {
    _limiteSaborBordaSelecionado = value;
    notifyListeners();
  }

  void resetarTudo() {
    saboresPizzaSelecionados = [];
    tamanhosPizza = null;
    categorias = [];

    notifyListeners();
  }

  Future<List<ModeloCategoria>> listarCategorias(
      {bool cachePrimeiro = false}) async {
    final res = await _categoriaService.listar(cachePrimeiro: cachePrimeiro);
    final todos = res.where((categoria) => categoria.id == '0').firstOrNull;
    if (todos != null) {
      final tamanhos = <String, ModeloTamanhosPizza>{};
      for (final categoria in res) {
        if (categoria.id == '0' ||
            (int.tryParse(categoria.quantidadeProdutos) ?? 0) == 0) {
          continue;
        }
        for (final tamanho
            in categoria.tamanhosPizza ?? <ModeloTamanhosPizza>[]) {
          tamanhos.putIfAbsent(tamanho.id, () => tamanho);
        }
      }
      todos.tamanhosPizza = tamanhos.values.toList();
    }
    categorias = res;
    return res;
  }

  Future<void> listarConfigBigChef() {
    return _carregamentoConfigBigChef ??= _carregarConfigBigChef();
  }

  Future<void> _carregarConfigBigChef() async {
    try {
      configBigchef = await Modular.get<ServicoConfigBigchef>()
          .listar(forcarAtualizacao: true);
    } finally {
      _carregamentoConfigBigChef = null;
    }
  }

  Future<void> garantirConfigBigChef({bool forcarAtualizacao = false}) {
    final carregamentoAtual = _carregamentoConfigBigChef;
    if (carregamentoAtual != null) return carregamentoAtual;
    if (!forcarAtualizacao && configBigchef != null) return Future.value();
    return listarConfigBigChef();
  }

  Modelowordtamanhosproduto? tamanhoPizzaDoProduto(Modelowordprodutos produto) {
    return produto.tamanhosPizza
        ?.where((tamanho) => tamanho.id == _tamanhosPizza?.id)
        .firstOrNull;
  }

  String valorSaborPizza(Modelowordprodutos produto) {
    return tamanhoPizzaDoProduto(produto)?.valor ?? produto.valorVenda;
  }

  void selecionarSaborPizza(Modelowordprodutos produto) {
    if (_saboresPizzaSelecionados.any((sabor) => sabor.id == produto.id)) {
      saboresPizzaSelecionados = _saboresPizzaSelecionados
          .where((sabor) => sabor.id != produto.id)
          .toList();
      return;
    }

    if (tamanhoPizzaDoProduto(produto) == null ||
        _saboresPizzaSelecionados.length >=
            int.parse(_tamanhosPizza!.saboreslimite)) {
      return;
    }

    saboresPizzaSelecionados = [..._saboresPizzaSelecionados, produto];
  }

  void atualizarSaboresDoCatalogo(List<Modelowordprodutos> produtos) {
    if (_saboresPizzaSelecionados.isEmpty) return;
    final atuais = {for (final produto in produtos) produto.id: produto};
    final atualizados = _saboresPizzaSelecionados.map((selecionado) {
      final atual = atuais[selecionado.id];
      // Respostas legadas de pesquisa podem vir sem os tamanhos. Nao troca
      // uma montagem completa por esse resumo nem altera itens ja no carrinho.
      return atual != null && (atual.tamanhosPizza?.isNotEmpty ?? false)
          ? atual
          : selecionado;
    }).toList();
    if (jsonEncode(atualizados.map((produto) => produto.toMap()).toList()) !=
        jsonEncode(_saboresPizzaSelecionados
            .map((produto) => produto.toMap())
            .toList())) {
      saboresPizzaSelecionados = atualizados;
    }
  }

  double calcularPrecoPizza() {
    if (tamanhosPizza == null || saboresPizzaSelecionados.isEmpty) {
      return 0;
    }

    var modelovalortamanhopizza =
        usuarioProvedor.usuario!.configuracoes!.modelovalortamanhopizza ?? '';

    final valores = saboresPizzaSelecionados
        .map((produto) => double.parse(valorSaborPizza(produto)));

    if (modelovalortamanhopizza == 'media') {
      final soma = valores.fold(0.0, (total, valor) => total + valor);
      return soma / saboresPizzaSelecionados.length;
    } else if (modelovalortamanhopizza == 'maior') {
      return valores.reduce(math.max);
    }

    return 0;
  }

  List<ModeloDadosOpcoesPacotes> saboresParaCarrinho() => ValoresPizza.ratear(
      saboresPizzaSelecionados
          .map((sabor) => ModeloDadosOpcoesPacotes(
                id: sabor.id,
                nome: sabor.nome,
                codigo: sabor.codigo,
                imprimirCodigoProdutoPreparo:
                    sabor.imprimirCodigoProdutoPreparo,
                valor: valorSaborPizza(sabor),
                quantimaximaselecao: '1/${saboresPizzaSelecionados.length}',
              ))
          .toList(),
      usuarioProvedor.usuario?.configuracoes?.modelovalortamanhopizza);
}
