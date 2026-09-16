import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_lista_financeiro_venda.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/modal_cancelar_venda.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/detalhes_pedido_venda.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_edicao_pedido.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaDetalhesDaVendaBalcao extends StatefulWidget {
  final String idVenda;
  const PaginaDetalhesDaVendaBalcao({super.key, required this.idVenda});
  @override
  State<PaginaDetalhesDaVendaBalcao> createState() =>
      _PaginaDetalhesDaVendaBalcaoState();
}

class _PaginaDetalhesDaVendaBalcaoState
    extends State<PaginaDetalhesDaVendaBalcao> {
  final servico = Modular.get<ServicoBalcao>();
  final _delivery = Modular.get<ServicoDelivery>();
  RetornoListarPorIdBalcao? _dados;
  List<Modelolistafinanceirovenda> _parcelas = [];
  bool _carregando = false, _ocupado = false;
  String? _erro;
  ServicoEdicaoPedido get _edicao => ServicoEdicaoPedido(_delivery);
  bool get _podeEditar =>
      !_ocupado &&
      !_carregando &&
      _dados != null &&
      !_dados!.informacoes.status.startsWith('Cancelad');

  PedidoDelivery get _pedido => PedidoDelivery.fromMap({
        ...ServicoEdicaoPedido.pedidoBalcao(widget.idVenda, _dados!).dados,
        'lancamentos': [
          for (final p in _parcelas)
            {
              'nome': p.entradaMov,
              'valor': valorDelivery(p.valorMovF.replaceAll('R\$', '').trim())
                  .toStringAsFixed(2)
            }
        ],
      });

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
      final dados = await servico.listarPorId(widget.idVenda);
      final parcelas = await servico.listarFinanceiroVenda(widget.idVenda);
      if (mounted) {
        setState(() {
          _dados = dados;
          _parcelas = parcelas;
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

  void _avisar(String mensagem) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
    }
  }

  Future<void> _imprimir(String opcao) async {
    if (_ocupado || _dados == null) return;
    setState(() => _ocupado = true);
    try {
      await _listar();
      if (_erro != null) throw StateError(_erro!);
      await _edicao.reimprimirBalcao(Modular.get<Server>(), _pedido,
          preparo: opcao != 'comprovante', comprovante: opcao != 'preparo');
    } catch (_) {
      _avisar('Não foi possível preparar a impressão.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _aposEditar() async {
    await _listar();
    Modular.get<ProvedorBalcao>().listar();
    try {
      if (_erro != null) throw StateError(_erro!);
      await _edicao.reimprimirBalcao(Modular.get<Server>(), _pedido);
    } catch (_) {
      _avisar(
          'Alteração salva. Não foi possível reenviar a impressão. Use o botão de imprimir.');
    }
  }

  Future<void> _editarPedido() async {
    if (!_podeEditar) return;
    final original = _pedido;
    setState(() => _ocupado = true);
    try {
      final salvo = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaNovoDelivery(
                  servico: _delivery,
                  editarPedido: original,
                  permitirEntrega: false,
                  aoSalvarEdicao: (dados) => _edicao.salvarDados(
                      TipoCardapio.balcao, original, dados))));
      if (salvo == true && mounted) await _aposEditar();
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
          usuario: servico.usuarioProvedor);
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
                        TipoCardapio.balcao, widget.idVenda, original, produto);
                    return true;
                  })));
      if (salvo == true && mounted) await _aposEditar();
    } catch (e) {
      _avisar(e is StateError
          ? e.message.toString()
          : 'Não foi possível editar o produto.');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _cancelar() async {
    await showDialog<void>(
        context: context,
        builder: (_) => ModalCancelarVenda(aoSalvar: (justificativa) async {
              final resposta =
                  await servico.excluir(widget.idVenda, justificativa);
              if (!mounted) return;
              if (!resposta.sucesso) {
                _avisar(resposta.mensagem);
                return;
              }
              Modular.get<ProvedorBalcao>().listar();
              await _listar();
            }));
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _dados == null ? null : _pedido;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Detalhes Balcão'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar pedido',
                onPressed: _ocupado || _carregando ? null : _listar,
                icon: const Icon(Icons.refresh)),
            PopupMenuButton<String>(
                enabled: pedido != null && !_ocupado,
                tooltip: 'Imprimir',
                icon: const Icon(Icons.print_outlined),
                onSelected: _imprimir,
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'preparo', child: Text('Imprimir preparo')),
                      PopupMenuItem(
                          value: 'comprovante',
                          child: Text('Imprimir comprovante')),
                      PopupMenuItem(
                          value: 'ambos', child: Text('Imprimir ambos'))
                    ]),
            PopupMenuButton<String>(
                enabled: _podeEditar,
                tooltip: 'Opções do pedido',
                onSelected: (_) => _cancelar(),
                itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: 'cancelar', child: Text('Cancelar pedido'))
                    ]),
          ]),
      bottomNavigationBar: pedido == null
          ? null
          : SafeArea(
              top: false, child: RodapeTotalPedidoVenda(total: pedido.total)),
      body: RefreshIndicator(
          onRefresh: _listar,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
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
                      tipo: TipoCardapio.balcao,
                      numero: pedido.numero,
                      cliente: pedido.nome,
                      telefone: pedido.texto('celularCliente'),
                      modalidade: pedido.nomeEntrega,
                      observacao: pedido.observacao,
                      produtos: _dados!.produtos,
                      total: pedido.total,
                      recebido: pedido.pago,
                      desconto: valorDelivery(pedido.dados['valorDesconto']),
                      acrescimo: valorDelivery(pedido.dados['valorAcrescimo']),
                      editarPedido: _podeEditar ? _editarPedido : null,
                      editarProduto: _podeEditar ? _editarProduto : null,
                      pagamentos: Column(children: [
                        for (final p in _parcelas)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(p.entradaMov),
                              subtitle:
                                  Text('${p.vencimentoMovF} · ${p.statusMov}'),
                              trailing: Text(p.valorMovF))
                      ])),
              ])),
    );
  }
}
