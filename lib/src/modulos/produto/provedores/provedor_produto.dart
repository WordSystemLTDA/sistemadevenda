// ignore_for_file: unnecessary_getters_setters

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';

class ProvedorProduto extends ChangeNotifier {
  final ProvedorCardapio provedorCardapio;
  final UsuarioProvedor usuarioProvedor;

  ProvedorProduto(this.provedorCardapio, this.usuarioProvedor);

  List<ModeloOpcoesPacotes> _opcoesPacotesListaFinal = [];
  final Map<String, bool> _preferenciaMeiaBorda = {};

  List<ModeloOpcoesPacotes> get opcoesPacotesListaFinal =>
      _opcoesPacotesListaFinal;
  set opcoesPacotesListaFinal(List<ModeloOpcoesPacotes> value) {
    definirOpcoesPacotesListaFinal(value);
  }

  void definirOpcoesPacotesListaFinal(
    List<ModeloOpcoesPacotes> value, {
    bool notificar = true,
  }) {
    _opcoesPacotesListaFinal = value;
    _resetarPreferenciaBordaSemSelecao(value);
    if (notificar) notifyListeners();
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
    _preferenciaMeiaBorda.clear();
    quantidade = 1;
    notifyListeners();
  }

  void calcularValorVenda(
    bool kit,
    String idProduto, {
    bool notificar = true,
  }) {
    double soma = 0;

    if (opcoesPacotesListaFinal.isNotEmpty) {
      for (var element in opcoesPacotesListaFinal) {
        if (element.id != 4) {
          if (element.id == 2) {
            element.produtos!.map((e1) {
              e1.opcoesPacotes?.map((e2) {
                for (var element22 in e2.dados!) {
                  if (element22.quantidade != null) {
                    soma += double.parse(element22.valor ?? '0') *
                        (element22.quantidade ?? 0);
                  } else {
                    soma += double.parse(element22.valor ?? '0');
                  }
                }

                return e2;
              }).toList();

              return e1;
            }).toList();
          } else if (element.id == 6) {
            soma += calcularPrecoBorda();
          } else if (element.dados != null) {
            for (var element2 in element.dados!) {
              if (element2.quantidade != null) {
                soma += double.parse(element2.valor ?? '0') *
                    (element2.quantidade ?? 0);
              } else {
                soma += double.parse(element2.valor ?? '0');
              }
            }
          }
        }
      }
    }

    var valorTamanho = retornarDadosPorID([4], kit, idProduto).firstOrNull ==
            null
        ? 0
        : double.tryParse(
                retornarDadosPorID([4], kit, idProduto).firstOrNull?.valor ??
                    '0') ??
            0;
    var valorFinal =
        (retornarDadosPorID([4], kit, idProduto).firstOrNull != null
                ? valorTamanho
                : valorVendaOriginal) +
            soma;

    valorVenda = double.parse(valorFinal.toStringAsFixed(2));
    if (notificar) notifyListeners();
  }

  void mudarExpandido1(bool valor) {
    expandido1 = valor;
    notifyListeners();
  }

  void mudarExpandido2(bool valor) {
    expandido2 = valor;
    notifyListeners();
  }

  List<ModeloDadosOpcoesPacotes> retornarDadosPorID(
      List<int> ids, bool kit, String idProduto) {
    if (kit) {
      var listaOpcoesPacote = opcoesPacotesListaFinal
          .where((element) => element.id == 2)
          .firstOrNull;
      List<ModeloDadosOpcoesPacotes> dadosF = [];

      if (listaOpcoesPacote != null) {
        for (var element in listaOpcoesPacote.produtos!) {
          if (element.id == idProduto) {
            dadosF = element.opcoesPacotes
                    ?.where((element) =>
                        ids.every((element2) => element2 == element.id))
                    .firstOrNull
                    ?.dados ??
                [];
          }
        }
      }

      return dadosF;
    }

    return opcoesPacotesListaFinal
            .where((element) => ids.every((element2) => element2 == element.id))
            .firstOrNull
            ?.dados ??
        [];
  }

  bool bordaPrecisaSelecionarQuantidade(ModeloOpcoesPacotes opcoesPacote) {
    final limiteConfigurado = int.tryParse(
            provedorCardapio.configBigchef?.saborlimitedeborda ?? '0') ??
        0;

    return limiteConfigurado > 0 &&
        opcoesPacote.id == 6 &&
        provedorCardapio.limiteSaborBordaSelecionado <= 0;
  }

  String _chavePreferenciaMeiaBorda(bool kit, String idProduto) =>
      kit ? 'kit:$idProduto' : 'produto';

  void _definirPreferenciaMeiaBorda(
      bool somenteMetade, bool kit, String idProduto) {
    final chave = _chavePreferenciaMeiaBorda(kit, idProduto);
    if (somenteMetade) {
      _preferenciaMeiaBorda[chave] = true;
    } else {
      _preferenciaMeiaBorda.remove(chave);
    }
  }

  void _resetarPreferenciaBordaSemSelecao(List<ModeloOpcoesPacotes> opcoes) {
    final temBordaSelecionada = opcoes
            .where((element) => element.id == 6)
            .firstOrNull
            ?.dados
            ?.isNotEmpty ??
        false;
    if (!temBordaSelecionada) {
      _preferenciaMeiaBorda.remove(_chavePreferenciaMeiaBorda(false, '0'));
    }
  }

  void _resetarPreferenciaBordaSeVazia(
      List<ModeloDadosOpcoesPacotes> dados, bool kit, String idProduto) {
    if (dados.isEmpty) {
      _preferenciaMeiaBorda.remove(_chavePreferenciaMeiaBorda(kit, idProduto));
    }
  }

  bool bordaSomenteMetadeSelecionada(bool kit, String idProduto) {
    final bordasSelecionadas = retornarDadosPorID([6], kit, idProduto);
    if (bordasSelecionadas.isEmpty) {
      return _preferenciaMeiaBorda[
              _chavePreferenciaMeiaBorda(kit, idProduto)] ??
          false;
    }
    return ValoresPizza.bordaSomenteMetade(bordasSelecionadas);
  }

  bool get bordaSomenteMetade => bordaSomenteMetadeSelecionada(false, '0');

  void definirBordaSomenteMetade(
      bool somenteMetade, bool kit, String idProduto) {
    _definirPreferenciaMeiaBorda(somenteMetade, kit, idProduto);
    final bordasSelecionadas = retornarDadosPorID([6], kit, idProduto);
    for (final borda in bordasSelecionadas) {
      borda.somenteMetadeBorda = somenteMetade;
    }
    calcularValorVenda(kit, idProduto);
  }

  ModeloDadosOpcoesPacotes _adicionalParaNovaSelecao(
    ModeloDadosOpcoesPacotes item,
  ) {
    return ModeloDadosOpcoesPacotes.fromMap(item.toMap())
      ..quantidade = 1
      ..estaSelecionado = true;
  }

  void selecionarItem(ModeloDadosOpcoesPacotes item,
      ModeloOpcoesPacotes opcoesPacote, bool kit, String idProduto) {
    var dadosID = retornarDadosPorID([opcoesPacote.id], kit, idProduto);

    if (bordaPrecisaSelecionarQuantidade(opcoesPacote)) {
      return;
    }

    if (opcoesPacote.id != 7) {
      item.estaSelecionado = true;
    }

    // CORTESIA
    if (opcoesPacote.tipo == 6) {
      if (dadosID.where((element) => element.id == item.id).isNotEmpty) {
        dadosID.removeWhere((element) => element.id == item.id);
      } else {
        if (num.parse(item.quantimaximaselecao ?? '1') == 1) {
          if (dadosID.length == num.parse(item.quantimaximaselecao ?? '1')) {
            opcoesPacotesListaFinal
                .where((element) => element.tipo == 6)
                .firstOrNull
                ?.dados = [];
            dadosID.add(item);
          } else {
            dadosID.add(item);
          }
        } else {
          if (dadosID.length < num.parse(item.quantimaximaselecao ?? '1')) {
            dadosID.add(item);
          } else {
            // ScaffoldMessenger.of(context).removeCurrentSnackBar();
            // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            //   content: Text('Máximo de produtos cortesia já escolhidos.'),
            //   backgroundColor: Colors.red,
            // ));
          }
        }
      }

      calcularValorVenda(kit, idProduto);

      return;
    }

    // TAMANHO
    if (opcoesPacote.tipo == 1) {
      opcoesPacotesListaFinal
          .where((element) => element.id == opcoesPacote.id)
          .firstOrNull
          ?.dados = [item];

      calcularValorVenda(kit, idProduto);

      return;
    }

    // SABOR BORDA
    final limiteSaboresBorda = int.tryParse(
            provedorCardapio.configBigchef?.saborlimitedeborda ?? '0') ??
        0;
    if (limiteSaboresBorda > 0 && opcoesPacote.id == 6) {
      final somenteMetadeBorda = bordaSomenteMetadeSelecionada(kit, idProduto);
      if (dadosID.length == provedorCardapio.limiteSaborBordaSelecionado) {
        if (dadosID.where((element) => element.id == item.id).isNotEmpty) {
          dadosID.removeWhere((element) => element.id == item.id);
          _resetarPreferenciaBordaSeVazia(dadosID, kit, idProduto);
        }

        calcularValorVenda(kit, idProduto);
        return;
      }
      item.somenteMetadeBorda = somenteMetadeBorda;
    }

    if (dadosID.where((element) => element.id == item.id).isNotEmpty) {
      dadosID.removeWhere((element) => element.id == item.id);
      if (opcoesPacote.id == 6) {
        _resetarPreferenciaBordaSeVazia(dadosID, kit, idProduto);
      }
    } else {
      if (opcoesPacote.id == 6) {
        item.somenteMetadeBorda = bordaSomenteMetadeSelecionada(kit, idProduto);
      }
      dadosID.add(opcoesPacote.id == 7 ? _adicionalParaNovaSelecao(item) : item);
    }

    calcularValorVenda(kit, idProduto);
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
    final bordasSelecionadas = opcoesPacotesListaFinal
            .where((element) => element.id == 6)
            .firstOrNull
            ?.dados ??
        [];
    return ValoresPizza.calcular(bordasSelecionadas, modeloValorBorda);
  }

  String get modeloValorBorda =>
      provedorCardapio.configBigchef?.modeloValorAdicionalPizza ??
      usuarioProvedor.usuario?.configuracoes?.modelovaloradicionalpizza ??
      'media';

  List<ModeloOpcoesPacotes> opcoesParaCarrinho() =>
      opcoesPacotesListaFinal.map((opcao) {
        final copia = ModeloOpcoesPacotes.fromMap(opcao.toMap());
        if (copia.id == 6) {
          copia.dados =
              ValoresPizza.ratear(copia.dados ?? [], modeloValorBorda);
        }
        return copia;
      }).toList();
}
