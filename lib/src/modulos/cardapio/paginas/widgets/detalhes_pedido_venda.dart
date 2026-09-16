import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

Modelowordprodutos produtoParaDetalhesPedido(Modelowordprodutos produto) {
  final exibicao =
      Modelowordprodutos.fromMap(DadosImpressaoPreparo.produto(produto));
  final pizza = (produto.opcoesPacotesListaFinal ?? []).any((o) => o.id == 10);
  if (pizza) {
    exibicao.nome = produto.nomeCategoria.isNotEmpty &&
            produto.nomeCategoria != 'Sem Categoria'
        ? produto.nomeCategoria
        : 'Pizza';
  }
  return exibicao;
}

class DetalhesPedidoVenda extends StatelessWidget {
  final TipoCardapio tipo;
  final String numero, cliente, telefone, modalidade, endereco, observacao;
  final List<Modelowordprodutos> produtos;
  final double total, recebido, entrega, desconto, acrescimo;
  final Widget? pagamentos;
  final VoidCallback? editarPedido;
  final ValueChanged<Modelowordprodutos>? editarProduto;

  const DetalhesPedidoVenda({
    super.key,
    required this.tipo,
    required this.numero,
    required this.cliente,
    required this.produtos,
    required this.total,
    required this.recebido,
    this.telefone = '',
    this.modalidade = '',
    this.endereco = '',
    this.observacao = '',
    this.entrega = 0,
    this.desconto = 0,
    this.acrescimo = 0,
    this.pagamentos,
    this.editarPedido,
    this.editarProduto,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final quantidade = produtos.fold(0.0, (n, p) => n + (p.quantidade ?? 1));
    final quantidadeTexto = quantidade == quantidade.roundToDouble()
        ? quantidade.toInt().toString()
        : quantidade.toString();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.primaryContainer.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(
              tipo == TipoCardapio.delivery
                  ? Icons.delivery_dining
                  : Icons.point_of_sale,
              color: cs.primary,
              size: 28),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('${tipo.nome} #$numero',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(cliente, style: Theme.of(context).textTheme.titleMedium),
                if (telefone.isNotEmpty) Text(telefone),
                if (modalidade.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(modalidade)),
                if (endereco.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(endereco)),
              ])),
          if (editarPedido != null)
            IconButton(
                tooltip: 'Editar pedido',
                onPressed: editarPedido,
                icon: const Icon(Icons.edit_outlined)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(
            child: _resumo(context, 'Itens', quantidadeTexto,
                Icons.shopping_bag_outlined)),
        const SizedBox(width: 10),
        Expanded(
            flex: 2,
            child: _resumo(context, 'Total do pedido', total.obterReal(),
                Icons.payments_outlined)),
      ]),
      if (observacao.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text('Observação: $observacao')),
      if ((total - recebido).abs() > .009)
        _valor(recebido > total ? 'A devolver' : 'A receber',
            (total - recebido).abs()),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: const Text('Valores e pagamentos'),
        children: [
          _valor(
              'Produtos',
              produtos.fold(
                  0.0,
                  (n, p) =>
                      n +
                      (double.tryParse(p.valorVenda) ?? 0) *
                          (p.quantidade ?? 1))),
          if (entrega != 0) _valor('Taxa de entrega', entrega),
          if (acrescimo != 0) _valor('Acréscimo', acrescimo),
          if (desconto != 0) _valor('Desconto', -desconto),
          _valor('Total', total),
          _valor('Recebido', recebido),
          _valor(recebido > total + .009 ? 'A devolver' : 'A receber',
              (total - recebido).abs()),
          if (pagamentos != null) pagamentos!,
        ],
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Icon(Icons.list_alt_rounded, size: 20),
          SizedBox(width: 8),
          Text('ITENS DO PEDIDO',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))
        ]),
      ),
      if (produtos.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Nenhum produto adicionado')),
      for (final produto in produtos)
        CardProdutoAcompanhar(
          key: ValueKey(
              'item-pedido-${produto.iditensvenda ?? produto.hashprodutos ?? produto.id}'),
          item: produtoParaDetalhesPedido(produto),
          cabecalhoAdaptavel: true,
          dados: null,
          idComanda: '0',
          idComandaPedido: '0',
          idMesa: '0',
          value: null,
          setarQuantidade: (_) {},
          tipo: tipo,
          podeEditar: editarProduto != null,
          onEditar:
              editarProduto == null ? null : () => editarProduto!(produto),
        ),
    ]);
  }

  Widget _resumo(
      BuildContext context, String titulo, String valor, IconData icone) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Icon(icone, size: 22),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo, style: Theme.of(context).textTheme.labelMedium),
          Text(valor,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]))
      ]),
    );
  }

  Widget _valor(String nome, double valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
          children: [Expanded(child: Text(nome)), Text(valor.obterReal())]));
}

class RodapeTotalPedidoVenda extends StatelessWidget {
  final double total;
  const RodapeTotalPedidoVenda({super.key, required this.total});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        const Expanded(child: Text('Total do pedido')),
        Text(total.obterReal(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700)),
      ]));
}
