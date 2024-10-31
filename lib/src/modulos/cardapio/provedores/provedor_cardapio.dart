import 'dart:math' as math;

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProvedorCardapio extends ChangeNotifier {
  final ServicosCategoria _categoriaService;
  final UsuarioProvedor usuarioProvedor;

  ProvedorCardapio(this._categoriaService, this.usuarioProvedor);

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
    notifyListeners();
  }

  List<ModeloProduto> _saboresPizzaSelecionados = [];
  List<ModeloProduto> get saboresPizzaSelecionados => _saboresPizzaSelecionados;
  set saboresPizzaSelecionados(List<ModeloProduto> value) {
    _saboresPizzaSelecionados = value;
    notifyListeners();
  }

  List<ModeloCategoria> _categorias = [];
  List<ModeloCategoria> get categorias => _categorias;
  set categorias(List<ModeloCategoria> value) {
    _categorias = value;
    notifyListeners();
  }

  ModeloConfigBigchef? _configBigchef;
  ModeloConfigBigchef? get configBigchef => _configBigchef;
  set configBigchef(ModeloConfigBigchef? value) {
    _configBigchef = value;
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

  Future<List<ModeloCategoria>> listarCategorias() async {
    final res = await _categoriaService.listar();
    categorias = res;
    notifyListeners();
    return res;
  }

  Future<void> listarConfigBigChef() async {
    configBigchef = await Modular.get<ServicoConfigBigchef>().listar();
    notifyListeners();
  }

  double calcularPrecoPizza() {
    var modelovalortamanhopizza = usuarioProvedor.usuario!.configuracoes!.modelovalortamanhopizza ?? '';

    if (modelovalortamanhopizza == 'media') {
      var somaDosProdutosSelecionados = double.parse(saboresPizzaSelecionados.fold(
        '0',
        (previousValue, element) {
          return (double.parse(previousValue) + double.parse(element.valorVenda)).toStringAsFixed(2);
        },
      ));

      var media = somaDosProdutosSelecionados / saboresPizzaSelecionados.length;

      return media;
    } else if (modelovalortamanhopizza == 'maior') {
      return saboresPizzaSelecionados.map((e) => double.parse(e.valorVenda)).reduce(math.max);
    }

    return 0;
  }
}
