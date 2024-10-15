// ignore_for_file: unnecessary_getters_setters

import 'package:app/src/modulos/cardapio/modelos/modelo_acompanhamentos_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_adicionais_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_cortesias_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_itens_retirada_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProduto extends ChangeNotifier {
  List<Modelowordadicionaisproduto> listaAdicionais = [];
  List<Modelowordtamanhosproduto> listaTamanhos = [];

  List<Modelowordcortesiasproduto> _listaCortesias = [];
  List<Modelowordcortesiasproduto> get listaCortesias => _listaCortesias;
  set listaCortesias(List<Modelowordcortesiasproduto> value) {
    _listaCortesias = value;
    notifyListeners();
  }

  List<ModeloProduto> _listaKits = [];
  List<ModeloProduto> get listaKits => _listaKits;
  set listaKits(List<ModeloProduto> value) {
    _listaKits = value;
    notifyListeners();
  }

  List<Modelowordacompanhamentosproduto> _listaAcompanhamentos = [];
  List<Modelowordacompanhamentosproduto> get listaAcompanhamentos => _listaAcompanhamentos;
  set listaAcompanhamentos(List<Modelowordacompanhamentosproduto> value) {
    _listaAcompanhamentos = value;
    notifyListeners();
  }

  List<Modeloworditensretiradaproduto> listaItensRetirada = [];

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
    listaAcompanhamentos = [];
    listaAdicionais = [];
    listaItensRetirada = [];
    listaTamanhos = [];
    quantidade = 1;
    notifyListeners();
  }

  List<Modelowordadicionaisproduto> retornarListaAdicionais(bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      if (listaKits.isEmpty) {
        return [];
      } else {
        List<Modelowordadicionaisproduto> adicionaisKIT = [];

        for (var element in listaKits) {
          for (var element2 in element.adicionais) {
            adicionaisKIT.add(element2);
          }
        }

        return adicionaisKIT;
      }
    }

    return listaAdicionais;
  }

  List<Modelowordacompanhamentosproduto> retornarListaAcompanhamentos(bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      if (listaKits.isEmpty) {
        return [];
      } else {
        List<Modelowordacompanhamentosproduto> acompanhamentosKIT = [];

        for (var element in listaKits) {
          for (var element2 in element.acompanhamentos) {
            acompanhamentosKIT.add(element2);
          }
        }

        return acompanhamentosKIT;
      }
    }

    return listaAcompanhamentos;
  }

  List<Modelowordtamanhosproduto> retornarListaTamanhos(bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      if (listaKits.isEmpty) {
        return [];
      } else {
        List<Modelowordtamanhosproduto> tamanhosKIT = [];

        for (var element in listaKits) {
          for (var element2 in element.tamanhos) {
            tamanhosKIT.add(element2);
          }
        }

        return tamanhosKIT;
      }
    }

    return listaTamanhos;
  }

  List<Modelowordcortesiasproduto> retornarListaCortesias(bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      if (listaKits.isEmpty) {
        return [];
      } else {
        List<Modelowordcortesiasproduto> cortesiasKIT = [];

        for (var element in listaKits) {
          for (var element2 in element.cortesias) {
            cortesiasKIT.add(element2);
          }
        }

        return cortesiasKIT;
      }
    }

    return listaCortesias;
  }

  void calcularValorVenda(bool kit, ModeloProduto? dadosKit) {
    var somaCortesias = double.tryParse(retornarListaCortesias(kit, dadosKit)
            .fold(
              Modelowordcortesiasproduto(
                id: '',
                nome: '',
                valor: '0',
                foto: '',
                excluir: false,
                quantimaximaselecao: '1',
                estaSelecionado: true,
              ),
              (previousValue, element) => Modelowordcortesiasproduto(
                id: '',
                nome: '',
                quantimaximaselecao: '1',
                valor: (double.parse(previousValue.valor) + double.parse(element.valor)).toString(),
                excluir: false,
                foto: '',
                estaSelecionado: true,
              ),
            )
            .valor) ??
        0;

    var somaAdicionais = double.tryParse(retornarListaAdicionais(kit, dadosKit)
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

    var somaAcompanhamentos = double.tryParse(retornarListaAcompanhamentos(kit, dadosKit)
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

    var valorTamanho = retornarListaTamanhos(kit, dadosKit).isEmpty ? 0 : double.tryParse(retornarListaTamanhos(kit, dadosKit).first.valor) ?? 0;
    var valorFinal = (retornarListaTamanhos(kit, dadosKit).isNotEmpty ? valorTamanho : valorVendaOriginal) + somaAdicionais + somaAcompanhamentos + somaCortesias;

    if (kit) {
      var valorVendaOriginal2 = double.parse(dadosKit!.valorVenda);

      var produtoKIT = listaKits.where((element) => element.id == dadosKit.id).firstOrNull;
      if (produtoKIT != null) {
        var somaCortesias2 = double.tryParse(produtoKIT.cortesias
                .fold(
                  Modelowordcortesiasproduto(
                    id: '',
                    nome: '',
                    valor: '0',
                    foto: '',
                    excluir: false,
                    quantimaximaselecao: '1',
                    estaSelecionado: true,
                  ),
                  (previousValue, element) => Modelowordcortesiasproduto(
                    id: '',
                    nome: '',
                    valor: (double.parse(previousValue.valor) + double.parse(element.valor)).toString(),
                    excluir: false,
                    foto: '',
                    quantimaximaselecao: '1',
                    estaSelecionado: true,
                  ),
                )
                .valor) ??
            0;

        var somaAdicionais2 = double.tryParse(produtoKIT.adicionais
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

        var somaAcompanhamentos2 = double.tryParse(produtoKIT.acompanhamentos
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

        var valorTamanho2 = produtoKIT.tamanhos.isEmpty ? 0 : double.tryParse(produtoKIT.tamanhos.first.valor) ?? 0;
        var valorFinal2 = (produtoKIT.tamanhos.isNotEmpty ? valorTamanho2 : valorVendaOriginal2) + somaAdicionais2 + somaAcompanhamentos2 + somaCortesias2;

        produtoKIT.valorVenda = valorFinal2.toStringAsFixed(2);
      }
    }

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

  void mudarTamanhoSelecionado(Modelowordtamanhosproduto novoDado, bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      var listaDeKits = listaKits.where((element) => element.id == dadosKit!.id).firstOrNull;
      if (listaDeKits == null) {
        dadosKit!.adicionais = [];
        dadosKit.itensRetiradas = [];
        dadosKit.acompanhamentos = [];
        dadosKit.tamanhos = [];
        dadosKit.tamanhos = [novoDado];
        listaKits.add(dadosKit);
      } else {
        listaDeKits.tamanhos = [novoDado];
      }

      calcularValorVenda(kit, dadosKit);
      notifyListeners();
      return;
    }

    listaTamanhos = [novoDado];

    calcularValorVenda(kit, dadosKit);
    notifyListeners();
  }

  bool selecionarCortesia(Modelowordcortesiasproduto novoDado, bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      var listaDeKits = listaKits.where((element) => element.id == dadosKit!.id).firstOrNull;
      if (listaDeKits == null) {
        dadosKit!.adicionais = [];
        dadosKit.itensRetiradas = [];
        dadosKit.acompanhamentos = [];
        dadosKit.tamanhos = [];
        dadosKit.cortesias = [];
        dadosKit.cortesias.add(novoDado);
        listaKits.add(dadosKit);
      } else {
        if (listaDeKits.cortesias.where((element) => element.id == novoDado.id).isNotEmpty) {
          listaDeKits.cortesias.removeWhere((element) => element.id == novoDado.id);
        } else {
          if ((num.tryParse(novoDado.quantimaximaselecao) ?? 1) == 1) {
            if (listaDeKits.cortesias.length == (num.tryParse(novoDado.quantimaximaselecao) ?? 1)) {
              listaDeKits.cortesias = [];
              listaDeKits.cortesias.add(novoDado);
            } else {
              return false;
            }
          } else if (listaDeKits.cortesias.length < (num.tryParse(novoDado.quantimaximaselecao) ?? 1)) {
            listaDeKits.cortesias.add(novoDado);
          } else {
            return false;
          }
        }
      }

      calcularValorVenda(kit, dadosKit);
      notifyListeners();
      return true;
    }

    if (listaCortesias.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaCortesias.removeWhere((element) => element.id == novoDado.id);
    } else {
      if ((num.tryParse(novoDado.quantimaximaselecao) ?? 1) == 1) {
        if (listaCortesias.length == (num.tryParse(novoDado.quantimaximaselecao) ?? 1)) {
          listaCortesias = [];
          listaCortesias.add(novoDado);
        } else {
          listaCortesias.add(novoDado);
        }
      } else {
        if (listaCortesias.length < (num.tryParse(novoDado.quantimaximaselecao) ?? 1)) {
          listaCortesias.add(novoDado);
        } else {
          return false;
        }
      }
    }

    calcularValorVenda(kit, dadosKit);
    notifyListeners();
    return true;
  }

  void selecionarAdicional(Modelowordadicionaisproduto novoDado, bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      var listaDeKits = listaKits.where((element) => element.id == dadosKit!.id).firstOrNull;
      if (listaDeKits == null) {
        dadosKit!.adicionais = [];
        dadosKit.itensRetiradas = [];
        dadosKit.acompanhamentos = [];
        dadosKit.tamanhos = [];
        dadosKit.cortesias = [];
        dadosKit.adicionais.add(novoDado);

        listaKits.add(dadosKit);
      } else {
        if (listaDeKits.adicionais.where((element) => element.id == novoDado.id).isNotEmpty) {
          listaDeKits.adicionais.removeWhere((element) => element.id == novoDado.id);
        } else {
          listaDeKits.adicionais.add(novoDado);
        }
      }

      calcularValorVenda(kit, dadosKit);
      notifyListeners();
      return;
    }

    if (listaAdicionais.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaAdicionais.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaAdicionais.add(novoDado);
    }

    calcularValorVenda(kit, dadosKit);
    notifyListeners();
  }

  void selecionarAcompanhamentos(Modelowordacompanhamentosproduto novoDado, bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      var listaDeKits = listaKits.where((element) => element.id == dadosKit!.id).firstOrNull;
      if (listaDeKits == null) {
        dadosKit!.adicionais = [];
        dadosKit.itensRetiradas = [];
        dadosKit.acompanhamentos = [];
        dadosKit.tamanhos = [];
        dadosKit.cortesias = [];
        dadosKit.acompanhamentos.add(novoDado);
        listaKits.add(dadosKit);
      } else {
        if (listaDeKits.acompanhamentos.where((element) => element.id == novoDado.id).isNotEmpty) {
          listaDeKits.acompanhamentos.removeWhere((element) => element.id == novoDado.id);
        } else {
          listaDeKits.acompanhamentos.add(novoDado);
        }
      }

      calcularValorVenda(kit, dadosKit);
      notifyListeners();
      return;
    }

    if (listaAcompanhamentos.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaAcompanhamentos.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaAcompanhamentos.add(novoDado);
    }

    calcularValorVenda(kit, dadosKit);
    notifyListeners();
  }

  void selecionarItensRetirada(Modeloworditensretiradaproduto novoDado, bool kit, ModeloProduto? dadosKit) {
    if (kit) {
      var listaDeKits = listaKits.where((element) => element.id == dadosKit!.id).firstOrNull;
      if (listaDeKits == null) {
        dadosKit!.adicionais = [];
        dadosKit.itensRetiradas = [];
        dadosKit.acompanhamentos = [];
        dadosKit.tamanhos = [];
        dadosKit.cortesias = [];
        dadosKit.itensRetiradas.add(novoDado);
        listaKits.add(dadosKit);
      } else {
        if (listaDeKits.itensRetiradas.where((element) => element.id == novoDado.id).isNotEmpty) {
          listaDeKits.itensRetiradas.removeWhere((element) => element.id == novoDado.id);
        } else {
          listaDeKits.itensRetiradas.add(novoDado);
        }
      }

      calcularValorVenda(kit, dadosKit);
      notifyListeners();
      return;
    }

    if (listaItensRetirada.where((element) => element.id == novoDado.id).isNotEmpty) {
      listaItensRetirada.removeWhere((element) => element.id == novoDado.id);
    } else {
      listaItensRetirada.add(novoDado);
    }

    calcularValorVenda(kit, dadosKit);
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
