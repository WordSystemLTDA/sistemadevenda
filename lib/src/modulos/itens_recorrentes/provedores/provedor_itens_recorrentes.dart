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
  int _consulta = 0;
  bool _descartado = false;
  List<Modelowordprodutos> itensCarrinho = [];
  double precoTotal = 0;

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
    itensCarrinho = [];
    precoTotal = 0;
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
      itensCarrinho = [];
      precoTotal = 0;
    }
    _contexto = contexto;
    final consulta = ++_consulta;
    final itens =
        await _servico.armazenamento.listar(contexto, recorrentes: true);
    if (_descartado || consulta != _consulta || _contexto != contexto) return;
    itensCarrinho = itens;
    precoTotal = itens.fold(
        0.0,
        (total, item) =>
            total + double.parse(item.valorVenda) * (item.quantidade ?? 1));
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

  Future<bool> excluirItemCarrinho(String idComandaPedido, int index) =>
      _servico.armazenamento.alterar(
          _contextoPorId(idComandaPedido), (itens) => itens.removeAt(index),
          recorrentes: true);

  Future<bool> setarItemCarrinho(
          String idComandaPedido, int index, double quantidade) =>
      _servico.armazenamento.alterar(_contextoPorId(idComandaPedido),
          (itens) => itens[index].quantidade = quantidade,
          recorrentes: true);

  Future<bool> inserir(String idComandaPedido, Modelowordprodutos produto) {
    final copia = Modelowordprodutos.fromMap(produto.toMap())..quantidade = 1;
    return _servico.armazenamento.alterar(
        _contextoPorId(idComandaPedido), (itens) => itens.add(copia),
        recorrentes: true);
  }

  @override
  void dispose() {
    _descartado = true;
    _servico.armazenamento.removeListener(_aoAlterarArmazenamento);
    super.dispose();
  }
}
