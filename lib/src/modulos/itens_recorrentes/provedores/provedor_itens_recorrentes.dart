import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/itens_recorrentes/modelos/modelo_itens_recorrentes.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProvedorItensRecorrentes extends ChangeNotifier {
  final ServicosItensComanda servico;
  // final ServicoCardapio _servicoCardapio;

  ProvedorItensRecorrentes(this.servico);

  // var itensCarrinho = ItensModeloComandao(listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);
  List<Modelowordprodutos> itensCarrinho = [];
  double precoTotal = 0;

  Future<dynamic> listarComandasPedidos(String idComandaPedido) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // await prefs.remove('itens_recorrentes');

    var itensRecorrentesString = prefs.getString('itens_recorrentes');

    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<Modelowordprodutos> produtos = [];
    double preco = 0;
    for (int index = 0; index < itensRecorrentes.length; index++) {
      final item = jsonDecode(itensRecorrentes[index]);

      if (item['idComandaPedido'] == idComandaPedido) {
        var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);
        itemF.produtos.map((e) {
          produtos.add(e);
          preco += double.parse(e.valorVenda) * (e.quantidade ?? 1);
        }).toList();

        break;
      }
    }

    itensCarrinho = produtos;
    precoTotal = preco;
    notifyListeners();
  }

  Future<bool> removerComandasPedidos(String idComandaPedido) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    var itensRecorrentesString = prefs.getString('itens_recorrentes');

    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<ModeloItensRecorrentes> novosItensRecorrentes = [];

    for (int index = 0; index < itensRecorrentes.length; index++) {
      final item = jsonDecode(itensRecorrentes[index]);

      if (item['idComandaPedido'] != idComandaPedido) {
        novosItensRecorrentes.add(item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item));
      }
    }

    final res = await prefs.setString('itens_recorrentes', json.encode(novosItensRecorrentes));
    return res;
  }

  Future<bool> excluirItemCarrinho(String idComandaPedido, int index) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    var itensRecorrentesString = prefs.getString('itens_recorrentes');

    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<ModeloItensRecorrentes> novosItensRecorrentes = [];

    for (int i = 0; i < itensRecorrentes.length; i++) {
      final item = itensRecorrentes[i];
      var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);

      if (itemF.idComandaPedido != idComandaPedido) {
        novosItensRecorrentes.add(itemF);
        continue;
      }

      novosItensRecorrentes.add(
        ModeloItensRecorrentes(
          idComandaPedido: itemF.idComandaPedido,
          produtos: itemF.produtos.asMap().entries.where((e) => e.key != index).map((e) => e.value).toList(),
        ),
      );
    }

    final res = await prefs.setString('itens_recorrentes', json.encode(novosItensRecorrentes));

    return res;
  }

  Future<bool> setarItemCarrinho(String idComandaPedido, int index, double quantidade) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    var itensRecorrentesString = prefs.getString('itens_recorrentes');

    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<ModeloItensRecorrentes> novosItensRecorrentes = [];

    for (int i = 0; i < itensRecorrentes.length; i++) {
      final item = itensRecorrentes[i];
      var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);

      if (itemF.idComandaPedido != idComandaPedido) {
        novosItensRecorrentes.add(itemF);
        continue;
      }

      novosItensRecorrentes.add(
        ModeloItensRecorrentes(
          idComandaPedido: itemF.idComandaPedido,
          produtos: itemF.produtos.asMap().entries.map((e) {
            if (e.key != index) return e.value;

            return Modelowordprodutos(
              id: e.value.id,
              hashprodutos: e.value.hashprodutos,
              iditensvenda: e.value.iditensvenda,
              nome: e.value.nome,
              codigo: e.value.codigo,
              estoque: e.value.estoque,
              tamanho: e.value.tamanho,
              foto: e.value.foto,
              ativo: e.value.ativo,
              descricao: e.value.descricao,
              valorVenda: e.value.valorVenda,
              categoria: e.value.categoria,
              nomeCategoria: e.value.nomeCategoria,
              dataLancado: e.value.dataLancado,
              ativarEdQtd: e.value.ativarEdQtd,
              ativarCustoDeProducao: e.value.ativarCustoDeProducao,
              novo: e.value.novo,
              destinoDeImpressao: e.value.destinoDeImpressao,
              habilTipo: e.value.habilTipo,
              habilItensRetirada: e.value.habilItensRetirada,
              ativoLoja: e.value.ativoLoja,
              tamanhosPizza: e.value.tamanhosPizza,
              ingredientes: e.value.ingredientes,
              quantidade: quantidade,
              quantidadePessoa: e.value.quantidadePessoa,
              tamanhoLista: e.value.tamanhoLista,
              valorTotalVendas: e.value.valorTotalVendas,
              observacao: e.value.observacao,
              quantidadeController: e.value.quantidadeController,
              acoes: e.value.acoes,
              valorRestoDivisao: e.value.valorRestoDivisao,
              opcoesPacotes: e.value.opcoesPacotes,
              opcoesPacotesListaFinal: e.value.opcoesPacotesListaFinal,
              descontoProduto: e.value.descontoProduto,
              habilsepardelivery: e.value.habilsepardelivery,
            );
          }).toList(),
        ),
      );
    }

    final res = await prefs.setString('itens_recorrentes', json.encode(novosItensRecorrentes));

    return res;
  }

  Future<bool> inserir(
    String idComandaPedido,
    Modelowordprodutos produto,
    // Modelowordprodutos produto,
    // tipo,
    // idMesa,
    // idComanda,
    // valor,
    // observacaoMesa,
    // idProduto,
    // String nomeProduto,
    // quantidade,
    // observacao,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var itensRecorrentesString = prefs.getString('itens_recorrentes');
    List<dynamic> itensRecorrentes = itensRecorrentesString != null ? jsonDecode(itensRecorrentesString) : [];

    List<ModeloItensRecorrentes> novosItensRecorrentes = [];

    for (int index = 0; index < itensRecorrentes.length; index++) {
      final item = itensRecorrentes[index];
      var itemF = item is String ? ModeloItensRecorrentes.fromJson(item) : ModeloItensRecorrentes.fromMap(item);

      if (itemF.idComandaPedido != idComandaPedido) {
        novosItensRecorrentes.add(itemF);
        continue;
      }

      novosItensRecorrentes.add(
        ModeloItensRecorrentes(
          idComandaPedido: itemF.idComandaPedido,
          produtos: [
            ...itemF.produtos,
            Modelowordprodutos(
              id: produto.id,
              hashprodutos: produto.hashprodutos,
              iditensvenda: produto.iditensvenda,
              nome: produto.nome,
              codigo: produto.codigo,
              estoque: produto.estoque,
              tamanho: produto.tamanho,
              foto: produto.foto,
              ativo: produto.ativo,
              descricao: produto.descricao,
              valorVenda: produto.valorVenda,
              categoria: produto.categoria,
              nomeCategoria: produto.nomeCategoria,
              dataLancado: produto.dataLancado,
              ativarEdQtd: produto.ativarEdQtd,
              ativarCustoDeProducao: produto.ativarCustoDeProducao,
              novo: produto.novo,
              destinoDeImpressao: produto.destinoDeImpressao,
              habilTipo: produto.habilTipo,
              habilItensRetirada: produto.habilItensRetirada,
              ativoLoja: produto.ativoLoja,
              tamanhosPizza: produto.tamanhosPizza,
              ingredientes: produto.ingredientes,
              quantidade: 1,
              quantidadePessoa: produto.quantidadePessoa,
              tamanhoLista: produto.tamanhoLista,
              valorTotalVendas: produto.valorTotalVendas,
              observacao: produto.observacao,
              quantidadeController: produto.quantidadeController,
              acoes: produto.acoes,
              valorRestoDivisao: produto.valorRestoDivisao,
              opcoesPacotes: produto.opcoesPacotes,
              opcoesPacotesListaFinal: produto.opcoesPacotesListaFinal,
              descontoProduto: produto.descontoProduto,
              habilsepardelivery: produto.habilsepardelivery,
            ),
          ],
        ),
      );
    }

    if (novosItensRecorrentes
        .firstWhere((e) => e.idComandaPedido == idComandaPedido, orElse: () => ModeloItensRecorrentes(idComandaPedido: '', produtos: []))
        .idComandaPedido
        .isEmpty) {
      novosItensRecorrentes.add(ModeloItensRecorrentes(idComandaPedido: idComandaPedido, produtos: [
        Modelowordprodutos(
          id: produto.id,
          hashprodutos: produto.hashprodutos,
          iditensvenda: produto.iditensvenda,
          nome: produto.nome,
          codigo: produto.codigo,
          estoque: produto.estoque,
          tamanho: produto.tamanho,
          foto: produto.foto,
          ativo: produto.ativo,
          descricao: produto.descricao,
          valorVenda: produto.valorVenda,
          categoria: produto.categoria,
          nomeCategoria: produto.nomeCategoria,
          dataLancado: produto.dataLancado,
          ativarEdQtd: produto.ativarEdQtd,
          ativarCustoDeProducao: produto.ativarCustoDeProducao,
          novo: produto.novo,
          destinoDeImpressao: produto.destinoDeImpressao,
          habilTipo: produto.habilTipo,
          habilItensRetirada: produto.habilItensRetirada,
          ativoLoja: produto.ativoLoja,
          tamanhosPizza: produto.tamanhosPizza,
          ingredientes: produto.ingredientes,
          quantidade: 1,
          quantidadePessoa: produto.quantidadePessoa,
          tamanhoLista: produto.tamanhoLista,
          valorTotalVendas: produto.valorTotalVendas,
          observacao: produto.observacao,
          quantidadeController: produto.quantidadeController,
          acoes: produto.acoes,
          valorRestoDivisao: produto.valorRestoDivisao,
          opcoesPacotes: produto.opcoesPacotes,
          opcoesPacotesListaFinal: produto.opcoesPacotesListaFinal,
          descontoProduto: produto.descontoProduto,
          habilsepardelivery: produto.habilsepardelivery,
        ),
      ]));
    }

    final res = await prefs.setString('itens_recorrentes', json.encode(novosItensRecorrentes));

    return res;
  }

  // Future<bool> lancarPedido(idMesa, idComanda, String idComandaPedido, valorTotal, quantidade, observacao, listaIdProdutos) async {
  //   final res = await _servico.lancarPedido(idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos);

  //   if (res) {
  //     await listarComandasPedidos();
  //   }

  //   notifyListeners();
  //   return res;
  // }
}
