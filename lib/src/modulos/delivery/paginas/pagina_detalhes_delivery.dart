import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';

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
        widget.servico.dadosCardapio(widget.id)
      ]);
      if (mounted) {
        setState(() {
          _dados = resultados[1] as Modeloworddadoscardapio;
          _pedido = (resultados[0] as PedidoDelivery).comEndereco(_dados!);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível atualizar o pedido.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _imprimir(bool preparo) async {
    if (_ocupado || _pedido == null) return;
    setState(() => _ocupado = true);
    try {
      await ImpressaoDelivery.imprimir(
          widget.servico, Modular.get<Server>(), _pedido!,
          preparo: preparo);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível preparar a impressão.')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _contato() async {
    final telefone =
        _pedido?.texto('celularCliente').replaceAll(RegExp(r'\D'), '') ?? '';
    if (telefone.isEmpty) return;
    try {
      final abriu = await launchUrl(Uri(scheme: 'tel', path: telefone));
      if (!abriu) throw StateError('Telefone indisponível');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Telefone do cliente: $telefone')));
      }
    }
  }

  Future<void> _editarProduto(Modelowordprodutos produto) async {
    if (_ocupado || _pedido == null) return;
    setState(() => _ocupado = true);
    try {
      final pedido = await widget.servico.pedido(widget.id);
      if (!mounted) return;
      final edicao = EdicaoProdutoCarrinho(
        item: Modelowordprodutos.fromMap(produto.toMap()),
        servico: Modular.get<ServicoProduto>(),
        categorias: Modular.get<ServicosCategoria>(),
        usuario: widget.servico.usuario,
      );
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaEditarProdutoCarrinho(
                  edicao: edicao,
                  mostrarControleQuantidade: true,
                  carregarConfiguracao: () =>
                      Modular.get<ServicoConfigBigchef>().listar(),
                  aoSalvar: (item) async {
                    await widget.servico.acao('editarProduto', pedido, {
                      'produto': normalizarProdutoParaEnvio(item.toMap()),
                      'valorOriginal': produto.valorVenda,
                      'quantidadeOriginal': produto.quantidade,
                    });
                    return true;
                  })));
      if (mounted) await _listar();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is StateError
                ? e.message.toString()
                : 'Não foi possível editar o produto.')));
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pedido = _pedido;
    return Scaffold(
      appBar: AppBar(
          title: Text(pedido == null
              ? 'Detalhes do Delivery'
              : 'Pedido #${pedido.numero}'),
          backgroundColor: cs.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar pedido',
                onPressed: _carregando ? null : _listar,
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
      bottomNavigationBar: pedido == null || pedido.encerrado
          ? null
          : SafeArea(
              top: false,
              minimum: const EdgeInsets.all(12),
              child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
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
                                            tipodeentrega: pedido.tipoEntrega,
                                            nomeAtendimento:
                                                'Delivery #${pedido.numero}')));
                                if (mounted) _listar();
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
                                  if (mounted) _listar();
                                },
                          icon: const Icon(Icons.payments_outlined),
                          label: const Text('Receber pagamento')),
                  ])),
      body: RefreshIndicator(
          onRefresh: _listar,
          child: ListView(
              padding: const EdgeInsets.all(16),
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
                if (pedido != null) ...[
                  ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(pedido.tipoEntrega == '1'
                          ? Icons.delivery_dining
                          : Icons.shopping_bag_outlined),
                      title: Text(pedido.nome,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                          '${pedido.nomeEntrega} · ${pedido.texto('status')}'),
                      trailing: pedido.texto('celularCliente').isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Ligar para cliente',
                              onPressed: _contato,
                              icon: const Icon(Icons.phone_outlined))),
                  if (pedido.tipoEntrega == '1' && pedido.endereco.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(pedido.endereco)),
                  if (pedido.observacao.isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Observação: ${pedido.observacao}')),
                  const Divider(),
                  _linha('Total', pedido.total.obterReal()),
                  if (pedido.tipoEntrega == '1')
                    _linha('Taxa de entrega', pedido.taxaEntrega.obterReal()),
                  _linha('Recebido', pedido.pago.obterReal()),
                  _linha('A receber', pedido.restante.obterReal()),
                  if (pedido.pagamentos.isNotEmpty)
                    ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: const Text('Pagamentos'),
                        children: [
                          for (final p in pedido.pagamentos)
                            ListTile(
                                title: Text('${p['nome']}'),
                                trailing:
                                    Text(valorDelivery(p['valor']).obterReal()))
                        ]),
                  const SizedBox(height: 16),
                  Text('Itens do pedido',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (_dados?.produtos?.isEmpty ?? true)
                    const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('Nenhum produto adicionado')),
                  for (final produto in _dados?.produtos ?? [])
                    CardProdutoAcompanhar(
                        item: produto,
                        podeEditar:
                            widget.editar && !_ocupado && !pedido.cancelado,
                        onEditar: () => _editarProduto(produto),
                        dados: _dados,
                        idComanda: '0',
                        idComandaPedido: pedido.id,
                        idMesa: '0',
                        value: null,
                        setarQuantidade: (_) {},
                        tipo: TipoCardapio.delivery),
                ],
              ])),
    );
  }

  Widget _linha(String nome, String valor) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Expanded(child: Text(nome)),
        Text(valor, style: const TextStyle(fontWeight: FontWeight.w700))
      ]));
}
