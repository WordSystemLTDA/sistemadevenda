import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaSaborBordas extends StatefulWidget {
  final Modelowordprodutos produto;
  final double? valorVenda;

  const PaginaSaborBordas({
    super.key,
    required this.produto,
    this.valorVenda,
  });

  @override
  State<PaginaSaborBordas> createState() => _PaginaSaborBordasState();
}

class _PaginaSaborBordasState extends State<PaginaSaborBordas> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  Modelowordprodutos? itemProduto;
  bool carregando = false;
  TextEditingController obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _prepararProdutoParaExibicao(widget.produto);
    listar();
  }

  void _prepararProdutoParaExibicao(Modelowordprodutos produto) {
    itemProduto = produto;
    _provedorProduto.definirOpcoesPacotesListaFinal(
      _opcoesIniciais(produto.opcoesPacotes ?? []),
      notificar: false,
    );
    final valor = widget.valorVenda ?? double.tryParse(produto.valorVenda) ?? 0;
    _provedorProduto.valorVenda = valor;
    _provedorProduto.valorVendaOriginal = valor;
    _provedorProduto.calcularValorVenda(false, '0', notificar: false);
  }

  List<ModeloOpcoesPacotes> _opcoesIniciais(
    List<ModeloOpcoesPacotes> opcoes,
  ) {
    return [for (var elm in opcoes) ModeloOpcoesPacotes.fromMap(elm.toMap())]
        .map((e) {
      // se for acompanhamentos retorna todos
      if (e.id == 5) {
        return e;
      }

      // se for cortesia
      if (e.id == 1) {
        e.dados = e.dados!
            .where((element) => element.estaSelecionado == true)
            .toList();
        return e;
      }

      e.dados = [];

      return e;
    }).toList();
  }

  ModeloOpcoesPacotes? _grupoBordasSelecionadas() {
    final bordas = _provedorProduto.opcoesPacotesListaFinal
        .where((opcao) => opcao.id == 6)
        .firstOrNull;
    if (bordas == null || (bordas.dados?.isNotEmpty ?? false) == false) {
      return null;
    }
    return ModeloOpcoesPacotes.fromMap(bordas.toMap());
  }

  void _preservarBordasSelecionadas(
    List<ModeloOpcoesPacotes> opcoes,
    ModeloOpcoesPacotes? bordasSelecionadas,
  ) {
    if (bordasSelecionadas == null) return;

    final index = opcoes.indexWhere((opcao) => opcao.id == 6);
    if (index < 0) {
      opcoes.add(bordasSelecionadas);
      return;
    }

    opcoes[index] = bordasSelecionadas;
  }

  Future<void> listar() async {
    if (!carregando) {
      setState(() {
        carregando = true;
      });
    }

    var inicioServico = Modular.get<ServicoProduto>();
    try {
      final value = await inicioServico.listarPorId(
          widget.produto.id, provedorCardapio.tamanhosPizza?.id ?? '0');
      if (!mounted) return;
      itemProduto = value;
      if (value != null) {
        final bordasSelecionadas = _grupoBordasSelecionadas();
        final opcoesIniciais = _opcoesIniciais(value.opcoesPacotes ?? []);
        _preservarBordasSelecionadas(opcoesIniciais, bordasSelecionadas);
        _provedorProduto.opcoesPacotesListaFinal = opcoesIniciais;

        final valor =
            widget.valorVenda ?? double.tryParse(value.valorVenda) ?? 0;
        _provedorProduto.valorVenda = valor;
        _provedorProduto.valorVendaOriginal = valor;
        _provedorProduto.calcularValorVenda(false, '0');
      }
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  void avancar() async {
    final opcaoBorda = _provedorProduto.opcoesPacotesListaFinal
        .where((opcao) => opcao.id == 6)
        .firstOrNull;
    final temBordaSelecionada = opcaoBorda?.dados?.isNotEmpty ?? false;

    if (temBordaSelecionada &&
        _provedorProduto.bordaPrecisaSelecionarQuantidade(opcaoBorda!)) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione a quantidade de sabores da borda primeiro.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final produtoDestino = itemProduto ?? widget.produto;
    if (temBordaSelecionada && opcaoBorda != null) {
      final opcoesSalvas = [
        for (final opcao in produtoDestino.opcoesPacotesListaFinal ??
            <ModeloOpcoesPacotes>[])
          if (opcao.id != 6) ModeloOpcoesPacotes.fromMap(opcao.toMap()),
        ModeloOpcoesPacotes.fromMap(opcaoBorda.toMap()),
      ];
      produtoDestino.opcoesPacotesListaFinal = opcoesSalvas;
    }

    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) {
        return PaginaProduto(
          produto: produtoDestino,
          valorVenda: widget.valorVenda,
          montagemPizza: true,
        );
      },
    ));
  }

  int get _quantidadeBordasSelecionadas {
    return _provedorProduto.opcoesPacotesListaFinal
            .where((opcao) => opcao.id == 6)
            .firstOrNull
            ?.dados
            ?.length ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    if (itemProduto == null) {
      return const Scaffold(
        body: Center(child: Text('Produto não existe')),
      );
    }

    final opcoesProduto =
        itemProduto!.opcoesPacotes ?? const <ModeloOpcoesPacotes>[];

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        provedorCardapio.limiteSaborBordaSelecionado = -1;
      },
      child: GestureDetector(
        onTap: () {
          FocusScopeNode currentFocus = FocusScope.of(context);

          if (!currentFocus.hasPrimaryFocus) {
            currentFocus.unfocus();
          }
        },
        child: AnimatedBuilder(
          animation: _provedorProduto,
          builder: (context, valueProdutoProvedor) {
            final quantidadeBordasSelecionadas = _quantidadeBordasSelecionadas;
            return Scaffold(
              extendBody: true,
              appBar: AppBar(
                title: Text("${itemProduto!.nome} ${itemProduto!.tamanho}"),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: BotaoAcaoPedido(
                    rotulo: quantidadeBordasSelecionadas > 0
                        ? 'Avançar ($quantidadeBordasSelecionadas)'
                        : 'Avançar',
                    total: _provedorProduto.valorVenda.obterReal(),
                    onPressed: avancar,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom +
                      MediaQuery.textScalerOf(context).scale(88),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (carregando) const LinearProgressIndicator(),
                    if (opcoesProduto.isNotEmpty) ...[
                      ...opcoesProduto.map((opcoesPacote) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 0, top: 10, bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                        child: Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        '${opcoesPacote.titulo} (${opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length})',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    )),
                                  ],
                                ),
                              ),
                              if (int.parse(provedorCardapio
                                          .configBigchef!.saborlimitedeborda) >
                                      0 &&
                                  opcoesPacote.id == 6) ...[
                                // SÓ APARECE QUANDO TEM BORDAS
                                const ListaBordas(),
                                const ControleMeiaBorda(),
                              ],
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: opcoesPacote.id == 2
                                    ? opcoesPacote.produtos!.length
                                    : opcoesPacote.dados!.length,
                                padding: const EdgeInsets.only(
                                    left: 14, right: 14, top: 20, bottom: 10),
                                itemBuilder: (context, index) {
                                  var item = opcoesPacote.dados![index];

                                  return CardOpcoesPacotes(
                                    opcoesPacote: opcoesPacote,
                                    kit: false,
                                    item: item,
                                    idProduto: '0',
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
