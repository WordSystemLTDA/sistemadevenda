import 'package:app/src/modulos/produto/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/modelos/tamanhos_modelo.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class ProvedorProduto extends ChangeNotifier {
  final ServicoProduto _servico;
  ProvedorProduto(this._servico);

  List<AdicionaisModelo> listaAdicionais = [];
  List<TamanhosModelo> listaTamanhos = [];
  List<AcompanhamentosModelo> listaAcompanhamentos = [];

  TamanhosModelo? tamanhoSelecionado;
  int quantidade = 1;

  bool expandido1 = true;
  bool expandido2 = true;

  void mudarExpandido1(bool valor) {
    expandido1 = valor;
    notifyListeners();
  }

  void mudarExpandido2(bool valor) {
    expandido2 = valor;
    notifyListeners();
  }

  void listarDados(String id) async {
    final res = await _servico.listarAdicionais(id);
    final res1 = await _servico.listarTamanhos(id);
    final res2 = await _servico.listarAcompanhamentos(id);
    listaAdicionais = res;
    listaTamanhos = res1;
    listaAcompanhamentos = res2;
    notifyListeners();
  }

  void mudarTamanhoSelecionado(TamanhosModelo? novoTamanho) {
    tamanhoSelecionado = novoTamanho;
    notifyListeners();
  }

  String retornarValorProduto(String preco) {
    if (listaTamanhos.isNotEmpty) {
      if (tamanhoSelecionado != null) {
        return tamanhoSelecionado!.valor;
      } else {
        return '0';
      }
    } else {
      return preco;
    }
  }

  double retornarTotalPedido(String preco) {
    var valorProduto = retornarValorProduto(preco);

    var somaValoresAdicionais = listaAdicionais.where((element) => element.estaSelecionado == true).fold(
      AdicionaisModelo(id: 'id', nome: 'nome', valor: '0', foto: 'foto', quantidade: 1, estaSelecionado: false),
      (previousValue, element) {
        return AdicionaisModelo(
          id: 'id',
          nome: 'nome',
          valor: (double.parse(previousValue.valor) + (double.parse(element.valor) * element.quantidade)).toString(),
          foto: 'foto',
          quantidade: 1,
          estaSelecionado: false,
        );
      },
    );

    var somaValoresAcompanhamentos = listaAcompanhamentos.where((element) => element.estaSelecionado == true).fold(
      AcompanhamentosModelo(id: 'id', nome: 'nome', valor: '0', foto: 'foto', estaSelecionado: false),
      (previousValue, element) {
        return AcompanhamentosModelo(
          id: 'id',
          nome: 'nome',
          valor: (double.parse(previousValue.valor) + double.parse(element.valor)).toString(),
          foto: 'foto',
          estaSelecionado: false,
        );
      },
    );

    var valorSomado = (double.parse(valorProduto) + double.parse(somaValoresAdicionais.valor) + double.parse(somaValoresAcompanhamentos.valor)) * quantidade;
    return valorSomado;
  }

  String retornarPrecoProdutoOriginal(String valorVenda) {
    if (listaTamanhos.isEmpty) {
      return double.parse(valorVenda).obterReal();
    }

    if (tamanhoSelecionado != null) {
      return double.parse(tamanhoSelecionado!.valor).obterReal();
    }

    return '${double.parse(listaTamanhos[0].valor).obterReal()} à ${double.parse(listaTamanhos[listaTamanhos.length - 1].valor).obterReal()}';
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
