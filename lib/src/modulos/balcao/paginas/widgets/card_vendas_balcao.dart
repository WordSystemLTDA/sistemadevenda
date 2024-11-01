import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CardVendasBalcao extends StatefulWidget {
  final ModeloVendasBalcao item;
  // final Function(String idCliente) aoClicarExcluir;
  // final Function(ClienteModelo item) aoClicarHistAten;
  // final Function(ClienteModelo item) editarDadosPessoais;
  // final Function(ClienteModelo item) editarAtivo;

  const CardVendasBalcao({
    super.key,
    required this.item,
    // required this.aoClicarExcluir,
    // required this.aoClicarHistAten,
    // required this.editarDadosPessoais,
    // required this.editarAtivo,
  });

  @override
  State<CardVendasBalcao> createState() => _CardVendasBalcaoState();
}

class _CardVendasBalcaoState extends State<CardVendasBalcao> {
  double tamanhoCard = 110;
  final SearchController pesquisaAtend = SearchController();
  final TextEditingController nomeAten = TextEditingController();

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    var item = widget.item;
    return SizedBox(
      height: 110,
      child: Card(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: InkWell(
                onTap: () {},
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
                          Text(item.tipodeentrega, style: const TextStyle(fontSize: 12)),
                          Text((double.tryParse(item.subtotal) ?? 0).obterReal()),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                    onTap: () async {
                      // await servico.editarAtivo(item.id, item.ativo).then((sucesso) {
                      //   if (sucesso) {
                      //     setState(() {
                      //       item.ativo = item.ativo == 'Sim' ? 'Não' : 'Sim';
                      //     });

                      //     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      //       content: Text("Cliente editado com sucesso."),
                      //       backgroundColor: Colors.green,
                      //       showCloseIcon: true,
                      //     ));
                      //   }
                      // });
                    },
                    child: SizedBox(
                      width: 50,
                      child: item.status == 'Sim' ? const Icon(Icons.check_box_outlined) : const Icon(Icons.check_box_outline_blank_rounded),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => PaginaClienteEditorDadosPessoais(
                      //       dadosCliente: item,
                      //     ),
                      //   ),
                      // );
                    },
                    child: const SizedBox(width: 50, child: Icon(Icons.edit)),
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
                    menuChildren: const [
                      // MenuItemButton(
                      //   onPressed: () {
                      //     Navigator.push(context, MaterialPageRoute(builder: (context) => PaginaEndereco(idCliente: item.id)));
                      //   },
                      //   child: const Row(
                      //     children: [
                      //       SizedBox(width: 15),
                      //       Text("Endereços"),
                      //       SizedBox(width: 15),
                      //     ],
                      //   ),
                      // ),
                      // MenuItemButton(
                      //   onPressed: () {
                      //     // Navigator.push(
                      //     //   context,
                      //     //   MaterialPageRoute(
                      //     //     builder: (context) => PaginaClienteResponsavel(
                      //     //       idClientes: item.id,
                      //     //       eCpf: item.tipoPessoa == 'Física',
                      //     //     ),
                      //     //   ),
                      //     // );
                      //   },
                      //   child: item.tipoPessoa == 'Física'
                      //       ? const Row(
                      //           children: [
                      //             SizedBox(width: 15),
                      //             Text("Responsável do Cliente"),
                      //             SizedBox(width: 15),
                      //           ],
                      //         )
                      //       : const Row(
                      //           children: [
                      //             SizedBox(width: 15),
                      //             Text("Responsável pela Empresa"),
                      //             SizedBox(width: 15),
                      //           ],
                      //         ),
                      // ),
                      // const Divider(height: 0),
                      // MenuItemButton(
                      //   onPressed: () {
                      //     showDialog<String>(
                      //       context: context,
                      //       builder: (BuildContext context) {
                      //         return AlertDialog(
                      //           title: const Text('Exclusão'),
                      //           content: const SingleChildScrollView(
                      //             child: ListBody(
                      //               children: <Widget>[
                      //                 Text("Deseja realmente excluir esse Cliente? "),
                      //               ],
                      //             ),
                      //           ),
                      //           actions: <Widget>[
                      //             TextButton(
                      //               child: const Text('Cancelar'),
                      //               onPressed: () {
                      //                 Navigator.of(context).pop();
                      //               },
                      //             ),
                      //             TextButton(
                      //               child: const Text('Excluir'),
                      //               onPressed: () async {
                      //                 await servico.excluir(item.id).then((sucesso) {
                      //                   if (sucesso) {
                      //                     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                      //                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      //                       content: Text("Cliente excluído com sucesso."),
                      //                       backgroundColor: Colors.green,
                      //                       showCloseIcon: true,
                      //                     ));

                      //                     provedor.excluir(item);

                      //                     // paginacaoController.itemList = paginacaoController.itemList!.where((element) => element.id != idCliente).toList();
                      //                   }
                      //                   Navigator.pop(context);
                      //                 });
                      //               },
                      //             ),
                      //           ],
                      //         );
                      //       },
                      //     );
                      //   },
                      //   child: const Row(
                      //     children: [
                      //       SizedBox(width: 15),
                      //       Text("Excluir", style: TextStyle(color: Colors.red)),
                      //       SizedBox(width: 15),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    // return SizedBox(
    //   height: tamanhoCard,
    //   child: Card(
    //     child: InkWell(
    //       onTap: () {},
    //       borderRadius: BorderRadius.circular(8),
    //       child: Row(
    //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //         children: [
    //           Container(
    //             width: 5,
    //             clipBehavior: Clip.hardEdge,
    //             decoration: const BoxDecoration(
    //               borderRadius: BorderRadius.only(
    //                 topLeft: Radius.circular(8),
    //                 bottomLeft: Radius.circular(8),
    //               ),
    //             ),
    //             child: VerticalDivider(
    //               color: item.ativo == 'Sim' ? Colors.green : Colors.red,
    //               thickness: 5,
    //             ),
    //           ),
    //           Padding(
    //             padding: const EdgeInsets.only(left: 10, top: 9),
    //             child: Column(
    //               crossAxisAlignment: CrossAxisAlignment.start,
    //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //               children: [
    //                 SizedBox(
    //                   width: width * 0.70,
    //                   child: Text(
    //                     item.nome,
    //                     overflow: TextOverflow.ellipsis,
    //                     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    //                   ),
    //                 ),
    //                 if (item.doc.isNotEmpty) Text(item.doc),
    //                 if (item.celular.isNotEmpty) Text(item.celular),
    //                 if (item.email.isNotEmpty) Text(item.email),
    //               ],
    //             ),
    //           ),
    //           SizedBox(
    //             width: 50,
    //             child: Card(
    //               shape: const RoundedRectangleBorder(
    //                 borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
    //               ),
    //               margin: EdgeInsets.zero,
    //               child: Column(
    //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
    //                 children: [
    //                   Expanded(
    //                     child: SizedBox(
    //                       width: 50,
    //                       child: InkWell(
    //                         onTap: () {
    //                           widget.editarAtivo(item);
    //                         },
    //                         borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
    //                         child: item.ativo == 'Sim' ? const Icon(Icons.check_box_outlined) : const Icon(Icons.check_box_outline_blank_rounded),
    //                       ),
    //                     ),
    //                   ),
    //                   Expanded(
    //                     child: SizedBox(
    //                       width: 50,
    //                       child: InkWell(
    //                         onTap: () {
    //                           widget.editarDadosPessoais(item);
    //                         },
    //                         child: const Icon(Icons.edit),
    //                       ),
    //                     ),
    //                   ),
    //                   Expanded(
    //                     child: MenuAnchor(
    //                       builder: (BuildContext context, MenuController controller, Widget? child) {
    //                         return SizedBox(
    //                           width: 50,
    //                           child: InkWell(
    //                             borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
    //                             onTap: () {
    //                               if (controller.isOpen) {
    //                                 controller.close();
    //                               } else {
    //                                 controller.open();
    //                               }
    //                             },
    //                             child: const Icon(Icons.more_vert),
    //                           ),
    //                         );
    //                       },
    //                       menuChildren: [
    //                         // if (item.celular.isNotEmpty) ...[
    //                         //   MenuItemButton(
    //                         //     child: Text('WhatsApp ${item.celular}'),
    //                         //     onPressed: () async {
    //                         //       FuncoesGlobais.abrirWhatsapp(item.celular);
    //                         //     },
    //                         //   ),
    //                         // ],
    //                         MenuItemButton(
    //                           onPressed: () {
    //                             widget.aoClicarExcluir(item.id);
    //                           },
    //                           child: const Row(
    //                             children: [
    //                               SizedBox(width: 15),
    //                               Text(
    //                                 "Excluir",
    //                                 style: TextStyle(color: Colors.red),
    //                               ),
    //                               SizedBox(width: 15),
    //                             ],
    //                           ),
    //                         ),
    //                       ],
    //                     ),
    //                   )
    //                 ],
    //               ),
    //             ),
    //           ),
    //         ],
    //       ),
    //     ),
    //   ),
    // );
  }
}
