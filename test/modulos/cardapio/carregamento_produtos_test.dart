import 'dart:async';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'montagem_pizza_test.dart' show sabor;

Modelowordprodutos produto(String id) => sabor(id, 'Bebidas', '10')
  ..valorVenda = '10'
  ..tamanhosPizza = [];

class ConsultaProdutos extends Fake implements ServicoProduto {
  final categorias = <({
    String categoria,
    int pagina,
    Completer<List<Modelowordprodutos>> resposta
  })>[];
  final pesquisas =
      <({String termo, Completer<List<Modelowordprodutos>> resposta})>[];

  @override
  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) {
    final resposta = Completer<List<Modelowordprodutos>>();
    categorias.add((categoria: categoria, pagina: pagina, resposta: resposta));
    return resposta.future;
  }

  @override
  Future<List<Modelowordprodutos>> listarPorNome(
      String pesquisa, String categoria, String idcliente) {
    final resposta = Completer<List<Modelowordprodutos>>();
    pesquisas.add((termo: pesquisa, resposta: resposta));
    return resposta.future;
  }
}

void main() {
  late ConsultaProdutos servico;
  late ProvedorProdutos provedor;

  setUp(() {
    servico = ConsultaProdutos();
    provedor = ProvedorProdutos(servico);
  });

  tearDown(() => provedor.dispose());

  test('a busca mais recente vence mesmo quando a antiga termina depois',
      () async {
    final antiga = provedor.listarProdutosPorNome('co', '0', '0');
    final atual = provedor.listarProdutosPorNome('coca', '0', '0');
    servico.pesquisas.last.resposta.complete([produto('Coca Cola')]);
    await atual;
    servico.pesquisas.first.resposta.complete([produto('Coco')]);
    await antiga;
    expect(provedor.produtos.single.nome, 'Coca Cola');
    expect(provedor.carregando, isFalse);
  });

  test('digitar novamente invalida a busca antes do debounce terminar',
      () async {
    final antiga = provedor.listarProdutosPorNome('co', '0', '0');
    provedor.prepararPesquisa('coca');
    servico.pesquisas.first.resposta.complete([produto('Coco')]);
    await antiga;
    expect(provedor.produtos, isEmpty);
    expect(provedor.carregando, isTrue);
  });

  test('paginacao nao duplica chamadas, repete pagina com falha e encerra',
      () async {
    final primeira = provedor.listarProdutosPorCategoria('0');
    servico.categorias.last.resposta
        .complete(List.generate(15, (i) => produto('$i')));
    await primeira;
    final segunda =
        provedor.listarProdutosPorCategoria('0', carregarMais: true);
    await provedor.listarProdutosPorCategoria('0', carregarMais: true);
    expect(servico.categorias.map((c) => c.pagina), [1, 2]);
    servico.categorias.last.resposta.completeError(Exception('Sem conexao'));
    await segunda;
    expect(provedor.produtos, hasLength(15));
    expect(provedor.erroAoCarregarMais, isTrue);
    expect(provedor.paginas['0'], 1);

    final tentativa =
        provedor.listarProdutosPorCategoria('0', carregarMais: true);
    expect(servico.categorias.last.pagina, 2);
    servico.categorias.last.resposta.complete([produto('14'), produto('15')]);
    await tentativa;
    expect(provedor.produtos, hasLength(16));
    expect(provedor.temMais, isFalse);
    await provedor.listarProdutosPorCategoria('0', carregarMais: true);
    expect(servico.categorias, hasLength(3));
  });

  test(
      'atualizacao vazia remove produtos antigos e reinicia na primeira pagina',
      () async {
    provedor.produtos = [produto('Antigo')];
    provedor.paginas['0'] = 4;
    final atualizar = provedor.listarProdutosPorCategoria('0');
    expect(servico.categorias.last.pagina, 1);
    servico.categorias.last.resposta.complete([]);
    await atualizar;
    expect(provedor.produtos, isEmpty);
    expect(provedor.temMais, isFalse);
  });

  test('rolar durante a busca nao mistura produtos de outra pagina', () async {
    final pesquisar = provedor.listarProdutosPorNome('Coca', '0', '0');
    await provedor.listarProdutosPorCategoria('0', carregarMais: true);
    expect(servico.categorias, isEmpty);
    servico.pesquisas.last.resposta.complete([produto('Coca')]);
    await pesquisar;
    await provedor.listarProdutosPorCategoria('0', carregarMais: true);
    expect(servico.categorias, isEmpty);
  });

  test('limpar a busca impede a resposta antiga de substituir a categoria',
      () async {
    final pesquisar = provedor.listarProdutosPorNome('Coca', '0', '0');
    final atualizar = provedor.listarProdutosPorCategoria('0');
    servico.categorias.last.resposta
        .complete([produto('Agua'), produto('Coca')]);
    await atualizar;
    servico.pesquisas.last.resposta.complete([produto('Coca')]);
    await pesquisar;
    expect(provedor.produtos.map((p) => p.id), ['Agua', 'Coca']);
  });

  test('resetar ignora consultas pendentes', () async {
    final consulta = provedor.listarProdutosPorCategoria('0');
    provedor.resetarTudo();
    servico.categorias.last.resposta.complete([produto('Antigo')]);
    await consulta;
    expect(provedor.produtos, isEmpty);
    expect(provedor.paginas, isEmpty);
  });

  test('falha de busca preserva os dados e permite nova tentativa', () async {
    provedor.produtos = [produto('Agua')];
    final consulta = provedor.listarProdutosPorNome('Coca', '0', '0');
    servico.pesquisas.last.resposta.completeError(Exception('Sem conexao'));
    await consulta;
    expect(provedor.produtos.single.id, 'Agua');
    expect(provedor.carregando, isFalse);
    expect(provedor.erro, isNotNull);
    final tentativa = provedor.listarProdutosPorNome('Coca', '0', '0');
    servico.pesquisas.last.resposta.complete([produto('Coca')]);
    await tentativa;
    expect(provedor.produtos.single.id, 'Coca');
    expect(provedor.erro, isNull);
  });
}
