import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_kit.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaProduto extends StatefulWidget {
  final Modelowordprodutos produto;
  final double? valorVenda;

  const PaginaProduto({
    super.key,
    required this.produto,
    this.valorVenda,
  });

  @override
  State<PaginaProduto> createState() => _PaginaProdutoState();
}

class _PaginaProdutoState extends State<PaginaProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  Modelowordprodutos? itemProduto;
  bool carregando = false;
  TextEditingController obsController = TextEditingController();

  @override
  void initState() {
    super.initState();

    listar();
  }

  void listar() async {
    if (carregando == false) {
      setState(() {
        carregando = true;
      });
    }

    var inicioServico = Modular.get<ServicoProduto>();
    await inicioServico.listarPorId(widget.produto.id, provedorCardapio.tamanhosPizza?.id ?? '0').then((value) {
      itemProduto = value;
      if (value != null) {
        if (widget.valorVenda == null) {
          _provedorProduto.opcoesPacotesListaFinal = [for (var elm in value.opcoesPacotes!) ModeloOpcoesPacotes.fromMap(elm.toMap())].map((e) {
            // SE FOR KITS/COMBOS
            if (e.id == 2) {
              var a = e.produtos!.map((e1) {
                e1.opcoesPacotes?.map((e2) {
                  // se for acompanhamentos retorna todos
                  if (e2.id == 5) {
                    return e2;
                  }

                  // se for cortesia
                  if (e2.id == 1) {
                    e2.dados = e2.dados!.where((element) => element.estaSelecionado == true).toList();
                    return e2;
                  }

                  e2.dados = [];
                  return e2;
                }).toList();

                return e1;
              }).toList();

              e.produtos = a;

              return e;
            }

            // se for acompanhamentos retorna todos
            if (e.id == 5) {
              return e;
            }

            // se for cortesia
            if (e.id == 1) {
              e.dados = e.dados!.where((element) => element.estaSelecionado == true).toList();
              return e;
            }

            e.dados = [];

            return e;
          }).toList();

          _provedorProduto.valorVenda = double.parse(value.valorVenda);
          _provedorProduto.valorVendaOriginal = double.parse(value.valorVenda);
          _provedorProduto.calcularValorVenda(false, '0');
        }
      }
    }).whenComplete(() {
      setState(() {
        carregando = false;
      });
    });
  }

  void inserirNoCarrinho() async {
    final idComanda = provedorCardapio.idComanda;
    final idMesa = provedorCardapio.idMesa;

    var comanda = idComanda.isEmpty ? 0 : idComanda;
    var mesa = idMesa.isEmpty ? 0 : idMesa;
    var valor = itemProduto!.valorVenda;
    var idProduto = itemProduto!.id;
    var observacaoMesa = '';
    var observacao = obsController.text;

    if ((itemProduto?.opcoesPacotes?.where((element) => element.id == 4) ?? []).isNotEmpty && _provedorProduto.retornarDadosPorID([4], false, '0').isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Selecione um tamanho antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    setState(() => carregando = !carregando);

    if (provedorCardapio.tamanhosPizza != null) {
      _provedorProduto.opcoesPacotesListaFinal.insert(
        0,
        ModeloOpcoesPacotes(
          id: 9,
          titulo: 'Tamanho Pizza',
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: provedorCardapio.tamanhosPizza!.id,
              nome: provedorCardapio.tamanhosPizza!.nomedotamanho,
              valor: provedorCardapio.calcularPrecoPizza().toStringAsFixed(2),
            )
          ],
        ),
      );

      _provedorProduto.opcoesPacotesListaFinal.insert(
        1,
        ModeloOpcoesPacotes(
            id: 10,
            titulo: 'Sabores Pizza (${provedorCardapio.saboresPizzaSelecionados.length})',
            obrigatorio: false,
            dados: provedorCardapio.saboresPizzaSelecionados
                .map((e) => ModeloDadosOpcoesPacotes(
                      id: e.id,
                      nome: e.nome,
                      valor: ((double.tryParse(e.valorVenda) ?? 0) / provedorCardapio.saboresPizzaSelecionados.length).toStringAsFixed(2),
                      quantimaximaselecao: '1/${provedorCardapio.saboresPizzaSelecionados.length}',
                    ))
                .toList()),
      );

      provedorCardapio.limiteSaborBordaSelecionado = -1;
      provedorCardapio.tamanhosPizza = null;
      provedorCardapio.saboresPizzaSelecionados = [];
    }

    itemProduto!.quantidade = _provedorProduto.quantidade.toDouble();
    itemProduto!.valorVenda = _provedorProduto.valorVenda.toStringAsFixed(2);
    itemProduto!.observacao = obsController.text;

    _provedorProduto.opcoesPacotesListaFinal.insert(
      0,
      ModeloOpcoesPacotes(
        id: 11,
        titulo: 'Observação',
        tipo: 7,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '0',
            nome: obsController.text,
            foto: '',
            estaSelecionado: false,
            excluir: false,
          ),
        ],
      ),
    );

    itemProduto!.opcoesPacotesListaFinal = _provedorProduto.opcoesPacotesListaFinal;

    await carrinhoProvedor
        .inserir(
      itemProduto!,
      provedorCardapio.tipo.nome,
      mesa,
      comanda,
      valor,
      observacaoMesa,
      idProduto,
      itemProduto!.nome,
      itemProduto!.quantidade,
      observacao,
    )
        .then((sucesso) {
      if (sucesso) {
        _provedorProduto.resetarTudo();
        if (mounted) Navigator.pop(context);
        if (widget.valorVenda != null) {
          if (mounted) Navigator.pop(context);
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ocorreu um erro'),
          showCloseIcon: true,
        ));
      }
    }).whenComplete(() {
      setState(() => carregando = !carregando);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (itemProduto == null) {
      if (carregando == false) {
        return const Scaffold(
          body: Center(child: Text('Produto não existe')),
        );
      }

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);

        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: AnimatedBuilder(
        animation: _provedorProduto,
        builder: (context, valueProdutoProvedor) {
          return Scaffold(
            appBar: AppBar(
              title: Text("${itemProduto!.nome} ${itemProduto!.tamanho}"),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            // backgroundColor: Colors.white,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                inserirNoCarrinho();
              },
              label: carregando
                  ? const CircularProgressIndicator()
                  : Row(
                      children: [
                        const SizedBox(width: 10),
                        Text('${_provedorProduto.quantidade}x ${(_provedorProduto.valorVenda).obterReal()}'),
                        const SizedBox(width: 10),
                        const Icon(Icons.check),
                        const SizedBox(width: 10),
                      ],
                    ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        itemProduto!.foto.isEmpty
                            ? Image.asset(Assets.boxAsset, width: 120, height: 120)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedNetworkImage(
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  fadeOutDuration: const Duration(milliseconds: 100),
                                  placeholder: (context, url) => const SizedBox(
                                    height: 50.0,
                                    width: 50.0,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                  imageUrl: itemProduto!.foto,
                                ),
                              ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _provedorProduto.aoDiminuirQuantidade(),
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    size: 30,
                                    color: _provedorProduto.quantidade == 1 ? Colors.grey : Colors.red,
                                  ),
                                ),
                                Text(
                                  _provedorProduto.quantidade.toString(),
                                  style: const TextStyle(fontSize: 20),
                                ),
                                IconButton(
                                  onPressed: () => _provedorProduto.aoAumentarQuantidade(),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 30,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const Text("Preço", style: TextStyle(fontSize: 18)),
                            Text(
                              (_provedorProduto.retornarDadosPorID([4], false, '0').isEmpty &&
                                      _provedorProduto.retornarDadosPorID([4], false, '0').firstOrNull == null &&
                                      itemProduto!.opcoesPacotes!.where((element) => element.id == 4).firstOrNull != null)
                                  ? "${double.parse(itemProduto!.opcoesPacotes!.where((element) => element.id == 4).first.dados!.first.valor ?? '0').obterReal()} à ${double.parse(itemProduto!.opcoesPacotes!.where((element) => element.id == 4).first.dados!.last.valor ?? '0').obterReal()}"
                                  : (_provedorProduto.valorVenda).obterReal(),
                              style: const TextStyle(color: Colors.green, fontSize: 18),
                            ),
                            const Row(
                              children: [
                                Text("Total", style: TextStyle(fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Observações: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          (_provedorProduto.valorVenda * _provedorProduto.quantidade).obterReal(),
                          style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: TextField(
                      controller: obsController,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        hintText: "Digite alguma observação",
                        hintStyle: TextStyle(fontWeight: FontWeight.w300),
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (itemProduto!.descricao.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        itemProduto!.descricao,
                        overflow: TextOverflow.fade,
                        maxLines: 6,
                        style: const TextStyle(color: Color.fromARGB(255, 161, 161, 161)),
                      ),
                    ),
                  ],
                  if (itemProduto!.opcoesPacotes!.isNotEmpty) ...[
                    ...itemProduto!.opcoesPacotes!.map((opcoesPacote) {
                      if (opcoesPacote.id == 6) {
                        return const SizedBox();
                      }

                      return Container(
                        padding: const EdgeInsets.only(left: 20, right: 20),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.5),
                              blurRadius: 30.0,
                              spreadRadius: -30,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              // color: Colors.white,
                              color: Theme.of(context).brightness == Brightness.dark ? null : Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              elevation: 0,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 10),
                                          child: Text(
                                            '${opcoesPacote.titulo} (${opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length})',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length,
                                    padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                    itemBuilder: (context, index) {
                                      if (opcoesPacote.id == 2) {
                                        var item = opcoesPacote.produtos![index];
                                        return CardKit(item: item);
                                      }

                                      var item = opcoesPacote.dados![index];
                                      return CardOpcoesPacotes(
                                        opcoesPacote: opcoesPacote,
                                        item: item,
                                        kit: false,
                                        idProduto: '0',
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
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
    );
  }
}
