// ignore_for_file: unnecessary_getters_setters

import 'package:app/src/modulos/cardapio/modelos/modelo_acompanhamentos_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_adicionais_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_itens_retirada_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProduto extends ChangeNotifier {
  List<Modelowordadicionaisproduto> listaAdicionais = [];
  List<Modelowordtamanhosproduto> listaTamanhos = [];

  List<Modelowordacompanhamentosproduto> _listaAcompanhamentos = [];
  List<Modelowordacompanhamentosproduto> get listaAcompanhamentos => _listaAcompanhamentos;
  set listaAcompanhamentos(List<Modelowordacompanhamentosproduto> value) {
    _listaAcompanhamentos = value;
    notifyListeners();
  }

  List<Modeloworditensretiradaproduto> listaItensRetirada = [];

  int quantidade = 1;
  double _valorVenda = 0;
  double get valorVenda => _valorVenda;
  set valorVenda(double value) {
    _valorVenda = value;
  }

  bool expandido1 = true;
  bool expandido2 = true;

  void resetarTudo() {
    listaAcompanhamentos = [];
    listaAdicionais = [];
    listaItensRetirada = [];
    listaTamanhos = [];
    quantidade = 1;
    notifyListeners();
  }

  void calcularValorVenda() {
    var somaAdicionais = double.tryParse(listaAdicionais
            .fold(
              Modelowordadicionaisproduto(
                id: '',
                nome: '',
                valor: '0',
                foto: '',
                excluir: false,
                quantidade: 1,
                estaSelecionado: true,
              ),
              (previousValue, element) => Modelowordadicionaisproduto(
                id: '',
                nome: '',
                valor: (double.parse(previousValue.valor) + (double.parse(element.valor) * element.quantidade)).toString(),
                excluir: false,
                foto: '',
                quantidade: 1,
                estaSelecionado: true,
              ),
            )
            .valor) ??
        0;

    var somaAcompanhamentos = double.tryParse(listaAcompanhamentos
            .fold(
              Modelowordacompanhamentosproduto(
                id: '',
                nome: '',
                valor: '0',
                foto: '',
                excluir: false,
                estaSelecionado: true,
              ),
              (previousValue, element) => Modelowordacompanhamentosproduto(
                id: '',
                nome: '',
                valor: (double.parse(previousValue.valor) + double.parse(element.valor)).toString(),
                excluir: false,
                foto: '',
                estaSelecionado: true,
              ),
            )
            .valor) ??
        0;

    var valorTamanho = listaTamanhos.isEmpty ? 0 : double.tryParse(listaTamanhos.first.valor) ?? 0;

    var valorFinal = (listaTamanhos.isNotEmpty ? valorTamanho : valorVenda) + somaAdicionais + somaAcompanhamentos;

    valorVenda = double.parse(valorFinal.toStringAsFixed(2));
  }

  void mudarExpandido1(bool valor) {
    expandido1 = valor;
    notifyListeners();
  }

  void mudarExpandido2(bool valor) {
    expandido2 = valor;
    notifyListeners();
  }

  void mudarTamanhoSelecionado(Modelowordtamanhosproduto novoDado) {
    listaTamanhos = [novoDado];
    calcularValorVenda();

    notifyListeners();
  }

  void selecionarAdicional(Modelowordadicionaisproduto novoDado) {
    if (listaAdicionais.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaAdicionais.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaAdicionais.add(novoDado);
    }

    calcularValorVenda();

    notifyListeners();
  }

  void selecionarAcompanhamentos(Modelowordacompanhamentosproduto novoDado) {
    if (listaAcompanhamentos.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaAcompanhamentos.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaAcompanhamentos.add(novoDado);
    }

    calcularValorVenda();

    notifyListeners();
  }

  void selecionarItensRetirada(Modeloworditensretiradaproduto novoDado) {
    if (listaItensRetirada.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaItensRetirada.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaItensRetirada.add(novoDado);
    }

    calcularValorVenda();

    notifyListeners();
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
}
