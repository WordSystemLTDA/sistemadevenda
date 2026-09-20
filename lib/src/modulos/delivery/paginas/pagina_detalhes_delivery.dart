import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/detalhes_pedido_venda.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_edicao_pedido.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaDetalhesDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  final String id;
  final bool editar;
  const PaginaDetalhesDelivery(
      {super.key,
      required this.servico,
      required this.id,
      this.editar = false});
  @override
  State<PaginaDetalhesDelivery> createState() => _PaginaDetalhesDeliveryState();
}

class _PaginaDetalhesDeliveryState extends State<PaginaDetalhesDelivery> {
  PedidoDelivery? _pedido;
  Modeloworddadoscardapio? _dados;
  bool _carregando = false, _ocupado = false;
  String? _erro;
  ServicoEdicaoPedido get _edicao => ServicoEdicaoPedido(widget.servico);
  bool get _podeEditar =>
      _pedido != null && !_pedido!.cancelado && !_ocupado && !_carregando;

  @override
  void initState() {
    super.initState();
    _listar();
  }

  Future<void> _listar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resultados = await Future.wait([
        widget.servico.pedido(widget.id),
        widget.servico.dadosCardapio(widget.id),
        widget.servico.detalhesLocais(widget.id),
      ]);
      if (!mounted) return;
      final dados = resultados[1] as Modeloworddadoscardapio;
      final pedido = resultados[0] as PedidoDelivery;
      final produtos = ImpressaoDelivery.produtosComDetalhesDoPedido(
        pedido,
        dados.produtos ?? [],
        detalhesLocais: resultados[2] as List<Modelowordprodutos>,
      );
      dados.produtos = produtos;
      final atualizado = PedidoDelivery.fromMap({
        ...pedido.dados,
        'produtos': produtos.map((p) => p.toMap()).toList()
      }).comEndereco(dados);
      setState(() {
        _dados = dados;
        _pedido = atualizado;
      });
      widget.servico.notificarPedidoAtualizado(atualizado);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível atualizar o pedido.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _avisar(String mensagem) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  Future<void> _imprimir(bool preparo) async {
    if (_ocupado || _pedido == null) return;
    setState(() => _ocupado = true);
    try {
      final atual = await widget.servico.pedido(widget.id);
      await ImpressaoDelivery.imprimir(
          widget.servico, Modular.get<Server>(), atual,
          preparo: preparo);
    } catch (_) {
      _avisar('Não foi possível preparar a impressão.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aposEditar() async {
    if (mounted) await _listar();
    try {
      final atual = await widget.servico.pedido(widget.id);
      await ImpressaoDelivery.imprimir(
          widget.servico, Modular.get<Server>(), atual,
          ambos: true);
    } catch (_) {
      _avisar(
          'Alteração salva. Não foi possível reenviar a impressão. Use o botão de imprimir.');
    }
  }

  Future<void> _editarPedido() async {
    if (!_podeEditar) return;
    final original = _pedido!;
    setState(() => _ocupado = true);
    try {
      final salvo = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaNovoDelivery(
                  servico: widget.servico,
                  editarPedido: original,
                  aoSalvarEdicao: (dados) => _edicao.salvarDados(
                      TipoCardapio.delivery, original, dados))));
      if (salvo == true) await _aposEditar();
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editarProduto(Modelowordprodutos original) async {
    if (!_podeEditar) return;
    setState(() => _ocupado = true);
    try {
      final edicao = EdicaoProdutoCarrinho(
          item: Modelowordprodutos.fromMap(original.toMap()),
          servico: Modular.get<ServicoProduto>(),
          categorias: Modular.get<ServicosCategoria>(),
          usuario: widget.servico.usuario);
      final salvo = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaEditarProdutoCarrinho(
                  edicao: edicao,
                  mostrarControleQuantidade: true,
                  carregarConfiguracao: () =>
                      Modular.get<ServicoConfigBigchef>().listar(),
                  aoSalvar: (produto) async {
                    await _edicao.salvarProduto(
                        TipoCardapio.delivery, widget.id, original, produto);
                    return true;
                  })));
      if (salvo == true) await _aposEditar();
    } catch (e) {
      _avisar(e is StateError
          ? e.message.toString()
          : 'Não foi possível editar o produto.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Detalhes do Delivery'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar pedido',
                onPressed: _ocupado || _carregando ? null : _listar,
                icon: const Icon(Icons.refresh)),
            PopupMenuButton<bool>(
                enabled: pedido != null && !_ocupado,
                tooltip: 'Imprimir',
                icon: const Icon(Icons.print_outlined),
                onSelected: _imprimir,
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: true, child: Text('Imprimir preparo')),
                      PopupMenuItem(
                          value: false, child: Text('Imprimir comprovante'))
                    ]),
          ]),
      bottomNavigationBar: pedido == null
          ? null
          : SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                RodapeTotalPedidoVenda(total: pedido.total),
                if (!pedido.encerrado)
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton.icon(
                            onPressed: _ocupado
                                ? null
                                : () async {
                                    await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) => PaginaCardapio(
                                                tipo: TipoCardapio.delivery,
                                                id: pedido.id,
                                                idCliente: pedido.cliente,
                                                tipodeentrega:
                                                    pedido.tipoEntrega,
                                                nomeAtendimento:
                                                    'Delivery #${pedido.numero}')));
                                    if (mounted) await _listar();
                                  },
                            icon: const Icon(Icons.add_shopping_cart),
                            label: const Text('Adicionar produtos')),
                        if (pedido.restante > .009)
                          FilledButton.icon(
                              onPressed: _ocupado
                                  ? null
                                  : () async {
                                      await receberDelivery(
                                          context, widget.servico, pedido.id);
                                      if (mounted) await _listar();
                                    },
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Receber pagamento')),
                      ])),
              ])),
      body: RefreshIndicator(
          onRefresh: _listar,
          child: ListView(
              padding: const EdgeInsets.all(12),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_carregando || _ocupado) const LinearProgressIndicator(),
                if (_erro != null)
                  ListTile(
                      title: Text(_erro!),
                      trailing: IconButton(
                          tooltip: 'Tentar novamente',
                          onPressed: _listar,
                          icon: const Icon(Icons.refresh))),
                if (pedido != null)
                  DetalhesPedidoVenda(
                    tipo: TipoCardapio.delivery,
                    numero: pedido.numero,
                    cliente: pedido.nome,
                    telefone: pedido.texto('celularCliente'),
                    modalidade: pedido.nomeEntrega,
                    endereco: pedido.tipoEntrega == '1' ? pedido.endereco : '',
                    observacao: pedido.observacao,
                    produtos: _dados?.produtos ?? [],
                    total: pedido.total,
                    recebido: pedido.pago,
                    entrega: pedido.taxaEntrega,
                    desconto: valorDelivery(pedido.dados['valorDesconto']),
                    acrescimo: valorDelivery(pedido.dados['valorAcrescimo']),
                    editarPedido: _podeEditar ? _editarPedido : null,
                    editarProduto: _podeEditar ? _editarProduto : null,
                    pagamentos: Column(children: [
                      for (final p in pedido.pagamentos)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${p['nome']}'),
                            trailing:
                                Text(valorDelivery(p['valor']).obterReal()))
                    ]),
                  ),
              ])),
    );
  }
}
