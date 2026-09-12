import 'dart:async';
import 'dart:developer';

import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/itens_comanda_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:flutter/material.dart';

class ProvedorCarrinho extends ChangeNotifier {
  final ServicosItensComanda _servico;

  ProvedorCarrinho(this._servico) {
    _servico.armazenamento.addListener(_aoAlterarArmazenamento);
  }

  ContextoCarrinho? _contexto;
  ContextoCarrinho? get contexto => _contexto;
  int _consulta = 0;
  bool _descartado = false;
  int _numeroAdicoes = 0;
  int get numeroAdicoes => _numeroAdicoes;
  final Map<String, double> _quantidadesPorProduto = {};

  double quantidadeDoProduto(String id) => _quantidadesPorProduto[id] ?? 0;

  var itensCarrinho = ItensModeloComandao(
      listaComandosPedidos: [], quantidadeTotal: 0, precoTotal: 0);

  Future<void> selecionarAtendimento(
      {required String tipo,
      required String idAtendimento,
      String idRecurso = ''}) async {
    final novo = ContextoCarrinho(
      empresa: _servico.usuarioProvedor.usuario?.empresa ?? '',
      tipo: tipo,
      idAtendimento: idAtendimento,
      idRecurso: idRecurso,
    );
    _contexto = novo;
    ++_consulta;
    _atualizarItens([]);
    if (novo.valido) {
      await _servico.armazenamento.alterar(novo, (_) {});
    }
    if (_contexto == novo && !_descartado) await listarComandasPedidos();
  }

  void _atualizarItens(List<Modelowordprodutos> itens) {
    if (_descartado) return;
    _quantidadesPorProduto.clear();
    num quantidadeTotal = 0;
    double precoTotal = 0;
    for (final item in itens) {
      quantidadeTotal += item.quantidade ?? 1;
      precoTotal += double.parse(item.valorVenda) * (item.quantidade ?? 1);
      final ehPizza = (item.opcoesPacotesListaFinal ?? [])
          .any((opcao) => opcao.id == 9 || opcao.id == 10);
      if (!ehPizza) {
        _quantidadesPorProduto.update(
            item.id, (quantidade) => quantidade + (item.quantidade ?? 1),
            ifAbsent: () => item.quantidade ?? 1);
      }
    }
    itensCarrinho = ItensModeloComandao(
        listaComandosPedidos: itens,
        quantidadeTotal: quantidadeTotal,
        precoTotal: precoTotal);
    notifyListeners();
  }

  Future<void> listarComandasPedidos() async {
    final contexto = _contexto;
    final consulta = ++_consulta;
    final itens = contexto == null
        ? <Modelowordprodutos>[]
        : await _servico.armazenamento.listar(contexto);
    if (!_descartado && consulta == _consulta && contexto == _contexto) {
      _atualizarItens(itens);
    }
  }

  Future<List<Modelowordprodutos>> obterItensParaFinalizar(
      ContextoCarrinho contexto) async {
    if (!contexto.valido || contexto.chave != _contexto?.chave) {
      throw StateError('O atendimento do carrinho foi alterado.');
    }
    // Aguarda gravacoes pendentes e retorna uma copia do atendimento solicitado.
    return _servico.armazenamento.listar(contexto);
  }

  void _aoAlterarArmazenamento() {
    unawaited(
        listarComandasPedidos().catchError((Object erro, StackTrace stack) {
      log('Falha ao atualizar carrinho local', error: erro, stackTrace: stack);
    }));
  }

  Future<bool> removerComandasPedidos({ContextoCarrinho? contexto}) async {
    final alvo = contexto ?? _contexto;
    if (alvo == null) return true;
    final sucesso = await _servico.armazenamento.limpar(alvo);
    if (alvo == _contexto) await listarComandasPedidos();
    return sucesso;
  }

  Future<bool> excluirItemCarrinho(String id, int index) async {
    final alvo = _contexto;
    if (alvo == null) return false;
    final sucesso = await _servico.armazenamento.alterar(alvo, (itens) {
      if (index < 0 || index >= itens.length || itens[index].id != id) {
        throw StateError('O item do carrinho foi alterado.');
      }
      itens.removeAt(index);
    });
    if (alvo == _contexto) await listarComandasPedidos();
    return sucesso;
  }

  Future<bool> inserir(
      Modelowordprodutos produto,
      tipo,
      idMesa,
      idComanda,
      valor,
      observacaoMesa,
      idProduto,
      String nomeProduto,
      quantidade,
      observacao) async {
    final alvo = _contexto;
    if (alvo == null || !alvo.valido) return false;
    if (alvo.idRecurso.isNotEmpty &&
        ((alvo.tipo == 'comanda' && idComanda.toString() != alvo.idRecurso) ||
            (alvo.tipo == 'mesa' && idMesa.toString() != alvo.idRecurso))) {
      return false;
    }
    final res = await _servico.inserir(produto, tipo, idMesa, idComanda, valor,
        observacaoMesa, idProduto, nomeProduto, quantidade, observacao,
        contexto: alvo);
    if (res && alvo == _contexto && !_descartado) {
      _numeroAdicoes++;
      await listarComandasPedidos();
    }
    return res;
  }

  Future<bool> editar(Modelowordprodutos produto, int index,
      {ContextoCarrinho? contexto, Modelowordprodutos? original}) async {
    final alvo = contexto ?? _contexto;
    if (alvo == null) return false;
    if (alvo.chave != _contexto?.chave) return false;
    final res = original == null
        ? await _servico.editar(produto, index, contexto: alvo)
        : await _servico.armazenamento
            .substituirItem(alvo, index, original, produto);
    if (res && alvo == _contexto) await listarComandasPedidos();
    return res;
  }

  Future<bool> definirConferencia(
      Modelowordprodutos item, int index, bool conferido) async {
    final alvo = _contexto;
    if (alvo == null) return false;
    final sucesso = await _servico.armazenamento
        .definirConferencia(alvo, index, item, conferido);
    if (alvo == _contexto) await listarComandasPedidos();
    return sucesso;
  }

  Future<bool> lancarPedido(
      dynamic idMesa,
      dynamic idComanda,
      String idComandaPedido,
      valorTotal,
      quantidade,
      observacao,
      listaIdProdutos) async {
    final res = await _servico.lancarPedido(
        idMesa, idComanda, valorTotal, quantidade, observacao, listaIdProdutos);
    if (res) await listarComandasPedidos();
    return res;
  }

  @override
  void dispose() {
    _descartado = true;
    _servico.armazenamento.removeListener(_aoAlterarArmazenamento);
    super.dispose();
  }
}
