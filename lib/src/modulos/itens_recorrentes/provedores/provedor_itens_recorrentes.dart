import 'dart:async';
import 'dart:developer';

import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:flutter/material.dart';

class ProvedorItensRecorrentes extends ChangeNotifier {
  final ServicosItensComanda _servico;
  ProvedorItensRecorrentes(this._servico) {
    _servico.armazenamento.addListener(_aoAlterarArmazenamento);
  }

  final _contextos = <String, ContextoCarrinho>{};
  ContextoCarrinho? _contexto;
  ContextoCarrinho? get contexto => _contexto;
  int _consulta = 0;
  bool _descartado = false;
  List<Modelowordprodutos> itensCarrinho = [];
  double precoTotal = 0;
  final Map<String, double> _quantidadesPorItemRecorrente = {};

  String chaveDoItemRecorrente(Modelowordprodutos item) {
    final idItemVenda = item.iditensvenda?.trim() ?? '';
    if (idItemVenda.isNotEmpty) return 'item:$idItemVenda';

    final hashProduto = item.hashprodutos?.trim() ?? '';
    if (hashProduto.isNotEmpty) return 'hash:$hashProduto';

    return 'produto:${item.id}';
  }

  double quantidadeDoItemRecorrente(Modelowordprodutos item) =>
      _quantidadesPorItemRecorrente[chaveDoItemRecorrente(item)] ?? 0;

  void selecionarAtendimento(
      {required String idAtendimento,
      required String tipo,
      required String idRecurso}) {
    _contextos[idAtendimento] = ContextoCarrinho(
        empresa: _servico.usuarioProvedor.usuario?.empresa ?? '',
        tipo: tipo,
        idAtendimento: idAtendimento,
        idRecurso: idRecurso);
    _contexto = _contextos[idAtendimento];
    ++_consulta;
    _atualizarItens([]);
  }

  ContextoCarrinho _contextoPorId(String id) {
    final empresa = _servico.usuarioProvedor.usuario?.empresa ?? '';
    final salvo = _contextos[id];
    if (salvo != null && salvo.empresa == empresa) return salvo;
    return ContextoCarrinho(
        empresa: empresa, tipo: 'comanda', idAtendimento: id);
  }

  Future<void> listarComandasPedidos(String idComandaPedido) async {
    final contexto = _contextoPorId(idComandaPedido);
    if (_contexto?.chave != contexto.chave) {
      _atualizarItens([]);
    }
    _contexto = contexto;
    final consulta = ++_consulta;
    final itens =
        await _servico.armazenamento.listar(contexto, recorrentes: true);
    if (_descartado || consulta != _consulta || _contexto != contexto) return;
    _atualizarItens(itens);
  }

  void _atualizarItens(List<Modelowordprodutos> itens) {
    if (_descartado) return;
    _quantidadesPorItemRecorrente.clear();
    double total = 0;
    for (final item in itens) {
      final quantidade = item.quantidade ?? 1;
      total += double.parse(item.valorVenda) * quantidade;
      _quantidadesPorItemRecorrente.update(
        chaveDoItemRecorrente(item),
        (valorAtual) => valorAtual + quantidade,
        ifAbsent: () => quantidade,
      );
    }
    itensCarrinho = itens;
    precoTotal = total;
    notifyListeners();
  }

  void _aoAlterarArmazenamento() {
    final contexto = _contexto;
    if (contexto == null) return;
    unawaited(listarComandasPedidos(contexto.idAtendimento)
        .catchError((Object erro, StackTrace stack) {
      log('Falha ao atualizar carrinho recorrente',
          error: erro, stackTrace: stack);
    }));
  }

  Future<bool> removerComandasPedidos(String idComandaPedido) =>
      _servico.armazenamento
          .limpar(_contextoPorId(idComandaPedido), recorrentes: true);

  Future<List<Modelowordprodutos>> obterItensParaFinalizar(
          String idComandaPedido) =>
      _servico.armazenamento
          .listar(_contextoPorId(idComandaPedido), recorrentes: true);

  Future<bool> editar(
      String idComandaPedido, Modelowordprodutos produto, int index,
      {ContextoCarrinho? contexto, Modelowordprodutos? original}) async {
    if (original != null) {
      final alvo = contexto ?? _contextoPorId(idComandaPedido);
      if (alvo.chave != _contexto?.chave) return false;
      final sucesso = await _servico.armazenamento
          .substituirItem(alvo, index, original, produto, recorrentes: true);
      if (sucesso && alvo == _contexto) {
        await listarComandasPedidos(idComandaPedido);
      }
      return sucesso;
    }
    final copia = Modelowordprodutos.fromMap(produto.toMap())
      ..conferidoNoCarrinho = false;
    return _servico.armazenamento.alterar(_contextoPorId(idComandaPedido),
        (itens) {
      if (index < 0 || index >= itens.length || itens[index].id != copia.id) {
        throw StateError('O item do carrinho foi alterado.');
      }
      itens[index] = copia;
    }, recorrentes: true);
  }

  Future<bool> excluirItemCarrinho(String idComandaPedido, int index) =>
      _servico.armazenamento.alterar(
          _contextoPorId(idComandaPedido), (itens) => itens.removeAt(index),
          recorrentes: true);

  Future<bool> setarItemCarrinho(
          String idComandaPedido, int index, double quantidade) =>
      _servico.armazenamento.alterar(
          _contextoPorId(idComandaPedido),
          (itens) => itens[index]
            ..quantidade = quantidade
            ..conferidoNoCarrinho = false,
          recorrentes: true);

  Future<bool> inserir(String idComandaPedido, Modelowordprodutos produto) {
    final copia = Modelowordprodutos.fromMap(produto.toMap())
      ..quantidade = 1
      ..conferidoNoCarrinho = false;
    return _servico.armazenamento.alterar(
        _contextoPorId(idComandaPedido), (itens) => itens.add(copia),
        recorrentes: true);
  }

  Future<bool> definirConferencia(
      Modelowordprodutos item, int index, bool conferido) async {
    final alvo = _contexto;
    if (alvo == null) return false;
    final sucesso = await _servico.armazenamento
        .definirConferencia(alvo, index, item, conferido, recorrentes: true);
    if (alvo == _contexto) await listarComandasPedidos(alvo.idAtendimento);
    return sucesso;
  }

  @override
  void dispose() {
    _descartado = true;
    _servico.armazenamento.removeListener(_aoAlterarArmazenamento);
    super.dispose();
  }
}
