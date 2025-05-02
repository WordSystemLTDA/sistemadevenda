import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/keep_alive_wrapper.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_lista_financeiro_venda.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/modal_cancelar_venda.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaDetalhesDaVendaBalcao extends StatefulWidget {
  final String idVenda;
  const PaginaDetalhesDaVendaBalcao({super.key, required this.idVenda});

  @override
  State<PaginaDetalhesDaVendaBalcao> createState() => _PaginaDetalhesDaVendaBalcaoState();
}

class _PaginaDetalhesDaVendaBalcaoState extends State<PaginaDetalhesDaVendaBalcao> {
  var servico = Modular.get<ServicoBalcao>();
  RetornoListarPorIdBalcao? informacoes;
  bool carregando = true;
  List<Modelolistafinanceirovenda> parcelas = [];

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    informacoes = await servico.listarPorId(widget.idVenda);
    parcelas = await servico.listarFinanceiroVenda(widget.idVenda);

    setState(() {
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes Balcão'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: ExpandableFab.location,
      floatingActionButton: Stack(
        // mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Positioned(
            left: 0,
            bottom: 0,
            child: SizedBox(
              height: 800,
              width: 300,
              child: ExpandableFab(
                distance: 70,
                pos: ExpandableFabPos.left,
                type: ExpandableFabType.up,
                openButtonBuilder: RotateFloatingActionButtonBuilder(
                  child: const Icon(Icons.print_outlined),
                  fabSize: ExpandableFabSize.regular,
                  shape: const CircleBorder(),
                ),
                closeButtonBuilder: DefaultFloatingActionButtonBuilder(
                  child: const Icon(Icons.close),
                  fabSize: ExpandableFabSize.regular,
                  shape: const CircleBorder(),
                ),
                children: [
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async {
                      final duration = DateTime.now().difference(DateTime.parse(informacoes!.informacoes.dataAbertura));
                      final newDuration = ConfigSistema.formatarHora(duration);

                      Impressao.comprovanteDoEntregador(
                        nomeCliente: informacoes!.informacoes.nomeCliente,
                        nomeEmpresa: informacoes!.informacoes.nomeempresa,
                        produtos: informacoes!.produtos,
                        nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                          return ModeloNomeLancamento(nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                        })),
                        somaValorHistorico: informacoes!.informacoes.subtotal,
                        cnpjEmpresa: informacoes!.informacoes.docempresa,
                        celularEmpresa: informacoes!.informacoes.celularcliente,
                        enderecoEmpresa: informacoes!.informacoes.enderecoempresa,
                        permanencia: newDuration,
                        total: informacoes!.informacoes.subtotal,
                        numeroPedido: informacoes!.informacoes.numerodopedido,
                        tipodeentrega: informacoes!.informacoes.tipodeentrega,
                        celularCliente: informacoes!.informacoes.celularcliente,
                        enderecoCliente: informacoes!.informacoes.enderecoenderecocliente,
                        valortroco: informacoes!.informacoes.valortroco,
                        valorentrega: informacoes!.informacoes.valorentrega,
                        bairroCliente: informacoes!.informacoes.nomebairro,
                        cidadeCliente: informacoes!.informacoes.nomecidade,
                        complementoCliente: informacoes!.informacoes.complementoenderecocliente,
                        numeroCliente: informacoes!.informacoes.numeroenderecocliente,
                      );
                      // var sucessoAoImprimir = await Impressao.enviarImpressao(
                      //   tipoImpressao: '3',
                      //   tipo: TipoCardapio.balcao,
                      //   nomeCliente: informacoes!.informacoes.nomeCliente,
                      //   nomeEmpresa: informacoes!.informacoes.nomeempresa,
                      //   produtos: informacoes!.produtos,
                      //   nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                      //     return ModeloNomeLancamento(nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                      //   })),
                      //   somaValorHistorico: informacoes!.informacoes.subtotal,
                      //   cnpjEmpresa: informacoes!.informacoes.docempresa,
                      //   celularEmpresa: informacoes!.informacoes.celularcliente,
                      //   enderecoEmpresa: informacoes!.informacoes.enderecoempresa,
                      //   permanencia: newDuration,
                      //   local: '',
                      //   total: informacoes!.informacoes.subtotal,
                      //   numeroPedido: informacoes!.informacoes.numerodopedido,
                      //   tipodeentrega: informacoes!.informacoes.tipodeentrega,
                      //   celularCliente: informacoes!.informacoes.celularcliente,
                      //   enderecoCliente: informacoes!.informacoes.enderecoenderecocliente,
                      //   valortroco: informacoes!.informacoes.valortroco,
                      //   valorentrega: informacoes!.informacoes.valorentrega,
                      //   bairroCliente: informacoes!.informacoes.nomebairro,
                      //   cidadeCliente: informacoes!.informacoes.nomecidade,
                      //   complementoCliente: informacoes!.informacoes.complementoenderecocliente,
                      //   numeroCliente: informacoes!.informacoes.numeroenderecocliente,
                      // );

                      // if (sucessoAoImprimir == false) {
                      //   if (context.mounted) {
                      //     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      //       content: Text('Não foi possível imprimir, você não está conectado em nenhum servidor.'),
                      //       backgroundColor: Colors.red,
                      //     ));
                      //   }
                      // }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    label: const Text('Comprovante do Entregador'),
                  ),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async {
                      final duration = DateTime.now().difference(DateTime.parse(informacoes!.informacoes.dataAbertura));
                      final newDuration = ConfigSistema.formatarHora(duration);

                      Impressao.comprovanteDeConsumo(
                        // tipoImpressao: '2',
                        // tipo: TipoCardapio.balcao,
                        // nomeCliente: informacoes!.informacoes.nomeCliente,
                        nomeEmpresa: informacoes!.informacoes.nomeempresa,
                        produtos: informacoes!.produtos,
                        nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                          return ModeloNomeLancamento(nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                        })),
                        somaValorHistorico: informacoes!.informacoes.subtotal,
                        cnpjEmpresa: informacoes!.informacoes.docempresa,
                        celularEmpresa: informacoes!.informacoes.celularcliente,
                        enderecoEmpresa: informacoes!.informacoes.enderecoempresa,
                        permanencia: newDuration,
                        local: '',
                        total: informacoes!.informacoes.subtotal,
                        numeroPedido: informacoes!.informacoes.numerodopedido,
                        tipodeentrega: informacoes!.informacoes.tipodeentrega,
                      );
                      // var sucessoAoImprimir = await Impressao.enviarImpressao(
                      //   tipoImpressao: '2',
                      //   tipo: TipoCardapio.balcao,
                      //   nomeCliente: informacoes!.informacoes.nomeCliente,
                      //   nomeEmpresa: informacoes!.informacoes.nomeempresa,
                      //   produtos: informacoes!.produtos,
                      //   nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                      //     return ModeloNomeLancamento(nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                      //   })),
                      //   somaValorHistorico: informacoes!.informacoes.subtotal,
                      //   cnpjEmpresa: informacoes!.informacoes.docempresa,
                      //   celularEmpresa: informacoes!.informacoes.celularcliente,
                      //   enderecoEmpresa: informacoes!.informacoes.enderecoempresa,
                      //   permanencia: newDuration,
                      //   local: '',
                      //   total: informacoes!.informacoes.subtotal,
                      //   numeroPedido: informacoes!.informacoes.numerodopedido,
                      //   tipodeentrega: informacoes!.informacoes.tipodeentrega,
                      // );

                      // if (sucessoAoImprimir == false) {
                      //   if (context.mounted) {
                      //     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      //       content: Text('Não foi possível imprimir, você não está conectado em nenhum servidor.'),
                      //       backgroundColor: Colors.red,
                      //     ));
                      //   }
                      // }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    label: const Text('Comprovante de Conta'),
                  ),
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async {
                      // var sucessoAoImprimir = await Impressao.comprovanteDePedido(
                      await Impressao.comprovanteDePedido(
                        local: "",
                        tipoTela: TipoCardapio.balcao,
                        comanda: "Balcão ${widget.idVenda}",
                        numeroPedido: informacoes!.informacoes.numerodopedido,
                        // nomeCliente: informacoes!.informacoes.nomeCliente,
                        nomeCliente: (informacoes?.informacoes.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' && (informacoes?.informacoes.observacaoDoPedido ?? '').isNotEmpty
                            ? (informacoes?.informacoes.observacaoDoPedido ?? '')
                            : (informacoes?.informacoes.nomeCliente ?? 'Sem Cliente'),
                        nomeEmpresa: informacoes!.informacoes.nomeempresa,
                        produtos: informacoes!.produtos,
                        tipodeentrega: informacoes!.informacoes.tipodeentrega,
                      );
                      // var sucessoAoImprimir = await Impressao.enviarImpressao(
                      //   tipoImpressao: '1',
                      //   tipo: TipoCardapio.balcao,
                      //   comanda: "Balcão ${widget.idVenda}",
                      //   numeroPedido: informacoes!.informacoes.numerodopedido,
                      //   nomeCliente: informacoes!.informacoes.nomeCliente,
                      //   nomeEmpresa: informacoes!.informacoes.nomeempresa,
                      //   produtos: informacoes!.produtos,
                      //   tipodeentrega: informacoes!.informacoes.tipodeentrega,
                      // );

                      // if (sucessoAoImprimir == false) {
                      //   if (context.mounted) {
                      //     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      //       content: Text('Não foi possível imprimir, você não está conectado em nenhum servidor.'),
                      //       backgroundColor: Colors.red,
                      //     ));
                      //   }
                      // }
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    label: const Text('Imprimir Preparo'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 800,
              width: 300,
              child: ExpandableFab(
                distance: 70,
                pos: ExpandableFabPos.right,
                type: ExpandableFabType.up,
                openButtonBuilder: RotateFloatingActionButtonBuilder(
                  child: const Icon(Icons.settings_outlined),
                  fabSize: ExpandableFabSize.regular,
                  shape: const CircleBorder(),
                ),
                closeButtonBuilder: DefaultFloatingActionButtonBuilder(
                  child: const Icon(Icons.close),
                  fabSize: ExpandableFabSize.regular,
                  shape: const CircleBorder(),
                ),
                children: [
                  FloatingActionButton.extended(
                    heroTag: null,
                    onPressed: () async {
                      showDialog(
                        context: context,
                        builder: (context) {
                          return ModalCancelarVenda(
                            aoSalvar: (justificativa) async {
                              await servico.excluir(widget.idVenda, justificativa).then((value) {
                                if (value.sucesso == false) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      content: Text(value.mensagem),
                                    ));
                                  }
                                } else {
                                  if (context.mounted) {
                                    var provedor = Modular.get<ProvedorBalcao>();
                                    provedor.listar();
                                    Navigator.pop(context);
                                  }
                                }
                              });
                            },
                          );
                        },
                      );
                    },
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    label: const Text('Cancelar Pedido'),
                  ),
                  // FloatingActionButton.extended(
                  //   heroTag: null,
                  //   onPressed: () {},
                  //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                  //   label: const Text('Enviar por e-mail'),
                  // ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Visibility(
        visible: informacoes != null,
        replacement: const Center(child: CircularProgressIndicator()),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(child: Text('Geral')),
                  Tab(child: Text('Financeiro')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    KeepAliveWrapper(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text.rich(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      TextSpan(
                                        text: 'Cliente: ',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        children: [
                                          TextSpan(
                                            text: informacoes?.informacoes.nomeCliente,
                                            style: const TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text.rich(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      TextSpan(
                                        text: 'Vendedor(a): ',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        children: [
                                          TextSpan(
                                            text: (informacoes?.informacoes.nomevendedor ?? '').isEmpty ? 'Sem Vendedor' : informacoes?.informacoes.nomevendedor,
                                            style: const TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Telefone: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: (informacoes?.informacoes.telefonecliente ?? '').isEmpty ? 'Sem Telefone' : informacoes?.informacoes.telefonecliente,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Celular: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: (informacoes?.informacoes.celularcliente ?? '').isEmpty ? 'Sem Celular' : informacoes?.informacoes.celularcliente,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Data: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: informacoes?.informacoes.datalanc,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Pedido: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: informacoes?.informacoes.numerodopedido,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text.rich(
                                TextSpan(
                                  text: 'Endereço: ',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${informacoes?.informacoes.enderecoenderecocliente}, ${informacoes?.informacoes.nomebairro}, ${informacoes?.informacoes.nomecidade} - ${informacoes?.informacoes.nomeestado} ${informacoes?.informacoes.cependerecocliente}.',
                                      style: const TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  'Produtos e Serviços (${informacoes?.produtos.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: informacoes?.produtos.length,
                                itemBuilder: (context, index) {
                                  var item = informacoes?.produtos[index];

                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Código: ${item!.codigo}", style: const TextStyle(fontSize: 13)),
                                          Text(item.nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(double.parse(item.valorVenda).obterReal()),
                                              const Text('x'),
                                              Text(item.quantidade.toString()),
                                              const Text('='),
                                              Text((double.parse(item.valorVenda) * num.parse(item.quantidade.toString())).obterReal()),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    KeepAliveWrapper(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(
                                'Meios de Pagamentos (${parcelas.length})',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: parcelas.length,
                              itemBuilder: (context, index) {
                                var item = parcelas[index];

                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Parcela: ${item.descricaoMov}", style: const TextStyle(fontSize: 13)),
                                        Text(item.valorMovF, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(item.entradaMov),
                                            Text(item.vencimentoMovF),
                                            Text(item.statusMov),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
