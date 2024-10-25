// ignore_for_file: unnecessary_getters_setters

import 'dart:math' as math;

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';

class ProvedorProduto extends ChangeNotifier {
  final ProvedorCardapio provedorCardapio;
  final UsuarioProvedor usuarioProvedor;

  ProvedorProduto(this.provedorCardapio, this.usuarioProvedor);

  List<ModeloOpcoesPacotes> _opcoesPacotesListaFinal = [];
  List<ModeloOpcoesPacotes> get opcoesPacotesListaFinal => _opcoesPacotesListaFinal;
  set opcoesPacotesListaFinal(List<ModeloOpcoesPacotes> value) {
    _opcoesPacotesListaFinal = value;
    notifyListeners();
  }

  int quantidade = 1;

  double _valorVendaOriginal = 0;
  double get valorVendaOriginal => _valorVendaOriginal;
  set valorVendaOriginal(double value) {
    _valorVendaOriginal = value;
  }

  double _valorVenda = 0;
  double get valorVenda => _valorVenda;
  set valorVenda(double value) {
    _valorVenda = value;
  }

  bool expandido1 = true;
  bool expandido2 = true;

  void resetarTudo() {
    opcoesPacotesListaFinal = [];
    quantidade = 1;
    notifyListeners();
  }

  void calcularValorVenda() {
    double soma = 0;

    if (opcoesPacotesListaFinal.isNotEmpty) {
      for (var element in opcoesPacotesListaFinal) {
        if (element.id != 4) {
          if (element.id == 6) {
            soma += calcularPrecoBorda();
          } else {
            for (var element2 in element.dados!) {
              if (element2.quantidade != null) {
                soma += double.parse(element2.valor ?? '0') * (element2.quantidade ?? 0);
              } else {
                soma += double.parse(element2.valor ?? '0');
              }
            }
          }
        }
      }
    }

    var valorTamanho = retornarDadosPorID([4]).firstOrNull == null ? 0 : double.tryParse(retornarDadosPorID([4]).firstOrNull?.valor ?? '0') ?? 0;
    var valorFinal = (retornarDadosPorID([4]).firstOrNull != null ? valorTamanho : valorVendaOriginal) + soma;

    valorVenda = double.parse(valorFinal.toStringAsFixed(2));
    notifyListeners();
  }

  void mudarExpandido1(bool valor) {
    expandido1 = valor;
    notifyListeners();
  }

  void mudarExpandido2(bool valor) {
    expandido2 = valor;
    notifyListeners();
  }

  List<ModeloDadosOpcoesPacotes> retornarDadosPorID(List<int> ids) {
    return opcoesPacotesListaFinal.where((element) => ids.every((element2) => element2 == element.id)).firstOrNull?.dados ?? [];
  }

  void selecionarItem(ModeloDadosOpcoesPacotes item, ModeloOpcoesPacotes opcoesPacote) {
    // CORTESIA
    if (opcoesPacote.tipo == 6) {
      if (retornarDadosPorID([opcoesPacote.id]).where((element) => element.id == item.id).isNotEmpty) {
        retornarDadosPorID([opcoesPacote.id]).removeWhere((element) => element.id == item.id);
      } else {
        if (num.parse(item.quantimaximaselecao ?? '1') == 1) {
          if (retornarDadosPorID([opcoesPacote.id]).length == num.parse(item.quantimaximaselecao ?? '1')) {
            opcoesPacotesListaFinal.where((element) => element.tipo == 6).firstOrNull?.dados = [];
            retornarDadosPorID([opcoesPacote.id]).add(item);
          } else {
            retornarDadosPorID([opcoesPacote.id]).add(item);
          }
        } else {
          if (retornarDadosPorID([opcoesPacote.id]).length < num.parse(item.quantimaximaselecao ?? '1')) {
            retornarDadosPorID([opcoesPacote.id]).add(item);
          } else {
            // ScaffoldMessenger.of(context).removeCurrentSnackBar();
            // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            //   content: Text('Máximo de produtos cortesia já escolhidos.'),
            //   backgroundColor: Colors.red,
            // ));
          }
        }
      }

      calcularValorVenda();

      return;
    }

    // TAMANHO
    if (opcoesPacote.tipo == 1) {
      opcoesPacotesListaFinal.where((element) => element.id == opcoesPacote.id).firstOrNull?.dados = [item];

      calcularValorVenda();

      return;
    }

    // SABOR BORDA
    if (int.parse(provedorCardapio.configBigchef!.saborlimitedeborda) > 0 && opcoesPacote.id == 6) {
      if (retornarDadosPorID([opcoesPacote.id]).length == provedorCardapio.limiteSaborBordaSelecionado) {
        if (retornarDadosPorID([opcoesPacote.id]).where((element) => element.id == item.id).isNotEmpty) {
          retornarDadosPorID([opcoesPacote.id]).removeWhere((element) => element.id == item.id);
        }

        calcularValorVenda();
        return;
      }
    }

    if (retornarDadosPorID([opcoesPacote.id]).where((element) => element.id == item.id).isNotEmpty) {
      retornarDadosPorID([opcoesPacote.id]).removeWhere((element) => element.id == item.id);
    } else {
      retornarDadosPorID([opcoesPacote.id]).add(item);
    }

    calcularValorVenda();
  }

  void aoDiminuirQuantidade() {
    if (quantidade == 1) return;

    quantidade--;
    notifyListeners();
  }

  void aoAumentarQuantidade() {
    quantidade++;
    notifyListeners();
  }

  double calcularPrecoBorda() {
    var modelovalortamanhopizza = usuarioProvedor.usuario!.configuracoes!.modelovalortamanhopizza ?? '';

    if (modelovalortamanhopizza == 'media') {
      var somaDosProdutosSelecionados = double.parse((opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados ?? []).fold(
        '0',
        (previousValue, element) {
          return (double.parse(previousValue) + double.parse(element.valor ?? '0')).toStringAsFixed(2);
        },
      ));

      var media = somaDosProdutosSelecionados / int.parse(provedorCardapio.configBigchef?.saborlimitedeborda ?? '0');

      return media;
    } else if (modelovalortamanhopizza == 'maior') {
      return (opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados ?? []).map((e) => double.parse(e.valor ?? '0')).reduce(math.max);
    }

    return 0;
  }
}
