import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
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
        _provedorProduto.opcoesPacotesListaFinal = [for (var elm in value.opcoesPacotes!) ModeloOpcoesPacotes.fromMap(elm.toMap())].map((e) {
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

        _provedorProduto.valorVenda = widget.valorVenda ?? 0;
        _provedorProduto.valorVendaOriginal = widget.valorVenda ?? 0;
        _provedorProduto.calcularValorVenda(false, '0');
      }
    }).whenComplete(() {
      setState(() {
        carregando = false;
      });
    });
  }

  void avancar() async {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) {
        return PaginaProduto(
          produto: widget.produto,
          valorVenda: widget.valorVenda,
        );
      },
    ));
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
            return Scaffold(
              appBar: AppBar(
                title: Text("${itemProduto!.nome} ${itemProduto!.tamanho}"),
                backgroundColor: Theme.of(context).colorScheme.inversePrimary,
              ),
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              floatingActionButton: FloatingActionButton.extended(
                heroTag: '123021903901',
                label: carregando ? const CircularProgressIndicator() : Text('Avançar ${_provedorProduto.valorVenda.obterReal()}'),
                onPressed: () {
                  avancar();
                },
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (itemProduto!.opcoesPacotes!.isNotEmpty) ...[
                      ...itemProduto!.opcoesPacotes!.map((opcoesPacote) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(left: 12),
                                      child: Text(
                                        '${opcoesPacote.titulo} (${opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length})',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (int.parse(provedorCardapio.configBigchef!.saborlimitedeborda) > 0 && opcoesPacote.id == 6) ...[
                                // SÓ APARECE QUANDO TEM BORDAS
                                const ListaBordas(),
                              ],
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length,
                                padding: const EdgeInsets.only(left: 14, right: 14, top: 20, bottom: 10),
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
