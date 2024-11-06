import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_forma_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaSelecionarPagamento extends StatefulWidget {
  final double totalReceber;
  final double desconto;
  final String acrescimo;
  final String descontoPercentual;
  final String totalPedido;

  const PaginaSelecionarPagamento({
    super.key,
    required this.totalReceber,
    required this.desconto,
    required this.acrescimo,
    required this.descontoPercentual,
    required this.totalPedido,
  });

  @override
  State<PaginaSelecionarPagamento> createState() => _PaginaSelecionarPagamentoState();
}

class _PaginaSelecionarPagamentoState extends State<PaginaSelecionarPagamento> {
  var provedor = Modular.get<ProvedorFinalizarPagamento>();
  String pagamentoSelecionado = '1';

  bool carregando = true;

  // Bancos padrões
  List<BancoPixModelo> bancos = [
    BancoPixModelo(id: '1', nome: 'Dinheiro'),
    BancoPixModelo(id: '2', nome: 'Conta'),
    BancoPixModelo(id: '3', nome: 'Débito'),
    BancoPixModelo(id: '4', nome: 'Crédito'),
  ];

  @override
  void initState() {
    super.initState();
    listarBancos();
  }

  void listarBancos() async {
    await context.read<ServicoFinalizarPagamento>().listarBancos().then((dadosBancos) {
      if (mounted) {
        if (dadosBancos.ativoBancoPix == 'Sim') {
          bancos.add(BancoPixModelo(id: '5', nome: dadosBancos.nomeBancoPix));
        }
        if (dadosBancos.ativoBancoOpcao2 == 'Sim') {
          bancos.add(BancoPixModelo(id: '6', nome: dadosBancos.nomeBancoOpcao2));
        }
        if (dadosBancos.ativoBancoOpcao3 == 'Sim') {
          bancos.add(BancoPixModelo(id: '7', nome: dadosBancos.nomeBancoOpcao3));
        }
        if (dadosBancos.ativoBancoOpcao4 == 'Sim') {
          bancos.add(BancoPixModelo(id: '8', nome: dadosBancos.nomeBancoOpcao4));
        }
        if (dadosBancos.ativoBancoOpcao5 == 'Sim') {
          bancos.add(BancoPixModelo(id: '9', nome: dadosBancos.nomeBancoOpcao5));
        }
      }
    });

    setState(() {
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecione a forma de pagamento'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton.extended(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaFinalizarFormaPagamento(
                totalReceber: widget.totalReceber,
                desconto: widget.desconto,
                acrescimo: widget.acrescimo,
                descontoPercentual: widget.descontoPercentual,
                totalPedido: widget.totalPedido,
                pagamentoselecionado: pagamentoSelecionado,
              ),
            ),
          );
        },
        label: SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: const Text('Avançar', textAlign: TextAlign.center),
        ),
      ),
      body: Visibility(
        visible: carregando == false,
        replacement: const Center(child: CircularProgressIndicator()),
        child: Stack(
          children: [
            // Positioned(
            //   bottom: 120,
            //   right: 20,
            //   left: 20,
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
            //     children: [
            //       const Text('Total a Receber ', style: TextStyle(fontSize: 15)),
            //       Text(
            //         widget.totalReceber.obterReal(),
            //         style: const TextStyle(
            //           fontSize: 15,
            //           fontWeight: FontWeight.w600,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SearchAnchor(
                            builder: (BuildContext context, SearchController controller) {
                              return IconButton(
                                onPressed: () {
                                  controller.openView();
                                },
                                icon: const Icon(Icons.menu),
                              );
                            },
                            suggestionsBuilder: (BuildContext context, SearchController controller) async {
                              final res = await Modular.get<ServicoBalcao>().listarHistoricoPagamentos(provedor.idVenda, TipoCardapio.balcao);
                              return [
                                ...res.map(
                                  (e) => Card(
                                    elevation: 3.0,
                                    margin: const EdgeInsets.all(5.0),
                                    child: InkWell(
                                      onTap: () {},
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      child: ListTile(
                                        leading: const Icon(Icons.person_2_outlined),
                                        title: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e.pagamento),
                                            Text("Valor ${double.parse(e.valor).obterReal()}"),
                                            Text("Total: ${double.parse(e.somaValorHistorico).obterReal()}"),
                                          ],
                                        ),
                                        subtitle: Text('ID: ${e.id}'),
                                      ),
                                    ),
                                  ),
                                ),
                              ];
                            },
                          ),
                          const Text('A pagar: ', style: TextStyle(fontSize: 25)),
                        ],
                      ),
                      // const Spacer(),
                      Text(
                        widget.totalReceber.obterReal(),
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    itemCount: bancos.length,
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    itemBuilder: (context, index) {
                      var item = bancos[index];

                      return SizedBox(
                        width: 130,
                        height: 78,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 13.0),
                          child: ElevatedButton(
                            style: ButtonStyle(
                              shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(5))),
                              backgroundColor: pagamentoSelecionado == item.id ? const WidgetStatePropertyAll(Colors.green) : null,
                              foregroundColor: pagamentoSelecionado == item.id ? const WidgetStatePropertyAll(Colors.white) : null,
                            ),
                            onPressed: () {
                              setState(() {
                                pagamentoSelecionado = item.id;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.attach_money_outlined),
                                Text('[${item.id}] ${item.nome}'),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
