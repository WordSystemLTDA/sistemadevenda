import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/pagina_detalhes_da_venda_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/modal_cancelar_venda.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class CardVendasBalcao extends StatefulWidget {
  final ModeloVendasBalcao item;
  final Function() listar;

  const CardVendasBalcao({
    super.key,
    required this.item,
    required this.listar,
  });

  @override
  State<CardVendasBalcao> createState() => _CardVendasBalcaoState();
}

class _CardVendasBalcaoState extends State<CardVendasBalcao> {
  var servico = Modular.get<ServicoBalcao>();

  final SearchController pesquisaAtend = SearchController();
  final TextEditingController nomeAten = TextEditingController();

  @override
  void dispose() {
    pesquisaAtend.dispose();
    nomeAten.dispose();
    super.dispose();
  }

  Future<void> cancelarVenda(String justificativa) async {
    await servico.excluir(widget.item.id, justificativa).then((value) {
      if (value.sucesso == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(value.mensagem),
          ));
        }
      }
    });

    widget.listar();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    var item = widget.item;
    return SizedBox(
      height: 115,
      child: Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) {
                    return PaginaDetalhesDaVendaBalcao(idVenda: item.id);
                  }));
                },
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                      ),
                      child: VerticalDivider(
                        color: item.status == 'Concluída' ? Colors.green : Colors.red,
                        thickness: 5,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 9),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: width * 0.70,
                            child: Text(
                              item.nomecliente,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Text(item.nomeusuario, style: const TextStyle(fontSize: 12)),
                          Text(DateFormat('dd/MM/yyyy hh:ss').format(DateTime.parse(item.dataHora)), style: const TextStyle(fontSize: 12)),
                          const SizedBox(height: 5),
                          Text(item.tipodeentrega, style: const TextStyle(fontSize: 12)),
                          Text((double.tryParse(item.subtotal) ?? 0).obterReal()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              child: Column(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return ModalCancelarVenda(
                              aoSalvar: (justificativa) async {
                                await cancelarVenda(justificativa);
                              },
                            );
                          },
                        );
                      },
                      child: const SizedBox(width: 50, child: Icon(Icons.delete_outline_outlined)),
                    ),
                  ),
                  Expanded(
                    child: MenuAnchor(
                      builder: (BuildContext context, MenuController controller, Widget? child) {
                        return SizedBox(
                          width: 50,
                          child: InkWell(
                            borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
                            onTap: () {
                              if (controller.isOpen) {
                                controller.close();
                              } else {
                                controller.open();
                              }
                            },
                            child: const Icon(Icons.more_vert),
                          ),
                        );
                      },
                      menuChildren: [
                        MenuItemButton(
                          onPressed: () async {
                            var informacoes = await servico.listarPorId(widget.item.id);

                            await Impressao.comprovanteDePedido(
                              local: "",
                              tipoTela: TipoCardapio.balcao,
                              comanda: "Balcão ${item.id}",
                              numeroPedido: item.numeropedido,
                              nomeCliente: (item.nomecliente) == 'Sem Cliente' && (item.observacaoDoPedido ?? '').isNotEmpty ? (item.observacaoDoPedido ?? '') : (item.nomecliente),
                              nomeEmpresa: item.nomeEmpresa,
                              produtos: informacoes.produtos,
                              tipodeentrega: informacoes.informacoes.tipodeentrega,
                            );

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
                          child: const Row(
                            children: [
                              SizedBox(width: 15),
                              Text("Imprimir Preparo"),
                              SizedBox(width: 15),
                            ],
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            var informacoes = await servico.listarPorId(widget.item.id);
                            var parcelas = await servico.listarFinanceiroVenda(widget.item.id);

                            final duration = DateTime.now().difference(DateTime.parse(widget.item.dataHora));
                            final newDuration = ConfigSistema.formatarHora(duration);

                            Impressao.comprovanteDeConsumo(
                              // tipoImpressao: '2',
                              // : TipoCardapio.balcao,
                              // nomeCliente: item.nomecliente,

                              valorentrega: informacoes.informacoes.valorentrega,
                              nomeEmpresa: item.nomeEmpresa,
                              produtos: informacoes.produtos,
                              nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                                return ModeloNomeLancamento(
                                    nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                              })),
                              somaValorHistorico: informacoes.informacoes.subtotal,
                              cnpjEmpresa: informacoes.informacoes.docempresa,
                              celularEmpresa: informacoes.informacoes.celularcliente,
                              enderecoEmpresa: informacoes.informacoes.enderecoempresa,
                              permanencia: newDuration,
                              local: '',
                              total: informacoes.informacoes.subtotal,
                              numeroPedido: informacoes.informacoes.numerodopedido,
                              tipodeentrega: informacoes.informacoes.tipodeentrega,
                            );

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
                          child: const Row(
                            children: [
                              SizedBox(width: 15),
                              Text("Comprovante da Conta"),
                              SizedBox(width: 15),
                            ],
                          ),
                        ),
                        MenuItemButton(
                          onPressed: () async {
                            var informacoes = await servico.listarPorId(widget.item.id);
                            var parcelas = await servico.listarFinanceiroVenda(widget.item.id);

                            final duration = DateTime.now().difference(DateTime.parse(widget.item.dataHora));
                            final newDuration = ConfigSistema.formatarHora(duration);

                            Impressao.comprovanteDoEntregador(
                              // tipoImpressao: '3',
                              // tipo: TipoCardapio.balcao,
                              nomeCliente: item.nomecliente,
                              nomeEmpresa: item.nomeEmpresa,
                              produtos: informacoes.produtos,
                              nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                                return ModeloNomeLancamento(
                                    nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                              })),
                              somaValorHistorico: informacoes.informacoes.subtotal,
                              cnpjEmpresa: informacoes.informacoes.docempresa,
                              celularEmpresa: informacoes.informacoes.celularcliente,
                              enderecoEmpresa: informacoes.informacoes.enderecoempresa,
                              permanencia: newDuration,
                              // local: '',
                              total: informacoes.informacoes.subtotal,
                              numeroPedido: informacoes.informacoes.numerodopedido,
                              tipodeentrega: informacoes.informacoes.tipodeentrega,
                              // '
                              celularCliente: informacoes.informacoes.celularcliente,
                              enderecoCliente: informacoes.informacoes.enderecoenderecocliente,
                              valortroco: informacoes.informacoes.valortroco,
                              valorentrega: informacoes.informacoes.valorentrega,
                              bairroCliente: informacoes.informacoes.nomebairro,
                              cidadeCliente: informacoes.informacoes.nomecidade,
                              complementoCliente: informacoes.informacoes.complementoenderecocliente,
                              numeroCliente: informacoes.informacoes.numeroenderecocliente,
                            );

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
                          child: const Row(
                            children: [
                              SizedBox(width: 15),
                              Text("Comprovante do Entregador"),
                              SizedBox(width: 15),
                            ],
                          ),
                        ),
                      ],
                    ),
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
