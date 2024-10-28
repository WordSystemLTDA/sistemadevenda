import 'dart:math' as math;

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProvedorCardapio extends ChangeNotifier {
  final ServicosCategoria _categoriaService;
  final UsuarioProvedor usuarioProvedor;

  ProvedorCardapio(this._categoriaService, this.usuarioProvedor);

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

  Future<void> listarCategorias() async {
    final res = await _categoriaService.listar();
    categorias = res;
    notifyListeners();
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
