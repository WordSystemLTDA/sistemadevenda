// import 'dart:convert';
// import 'dart:developer';

// import 'package:app/src/essencial/api/socket/server.dart';
// import 'package:app/src/essencial/utils/impressao.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_modular/flutter_modular.dart';
// import 'package:web_socket_channel/web_socket_channel.dart';

// class Client extends ChangeNotifier {
//   String hostname = '';
//   int port = 0;
//   String nomedopc = '';
//   bool connected = false;
//   String idUsuarioConectado = '0';

//   // Socket? socket;
//   WebSocketChannel? channel;

//   BuildContext? contextMesa;
//   BuildContext? contextMesa1;

//   BuildContext? contextComanda;
//   BuildContext? contextComanda1;

//   Future<bool> connect(String hostnameNovo, int portaNova) async {
//     try {
//       final wsUrl = Uri.parse('ws://$hostnameNovo:$portaNova');

//       channel = WebSocketChannel.connect(wsUrl);

//       await channel!.ready;

//       // !IMPORTANTE! Caso o client se conecte isso mudara o ip do servidor também
//       if (Modular.get<Client>().connected) {
//         Modular.get<Client>().channel!.sink.add(jsonEncode({
//               'tipo': 'Rede',
//               'ip': hostnameNovo,
//             }));
//       }

//       connected = true;
//       hostname = hostnameNovo;
//       port = portaNova;
//       notifyListeners();

//       channel!.stream.listen(
//         (message) {
//           onData(message);
//         },
//         onError: (error) {
//           log('Error: $error');
//         },
//         onDone: () {
//           if (AppRotas.navigatorKey?.currentContext != null && AppRotas.navigatorKey!.currentContext!.mounted) {
//             ScaffoldMessenger.of(AppRotas.navigatorKey!.currentContext!).showSnackBar(
//               SnackBar(
//                 content: Row(
//                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                   children: [
//                     const Text('Banco de dados foi desconectado.'),
//                     Row(
//                       children: [
//                         SizedBox(
//                           height: 30,
//                           child: TextButton(
//                             onPressed: () async {
//                               if (DioCliente().tipoDeInstalador == '1') {
//                                 Modular.get<AutenticacaoProvedor>().baseUrlSistema = (await Conexao().getConexaoSistema()).servidor;
//                               }

//                               final ConfigSharedPreferences config = ConfigSharedPreferences();
//                               var conexaoCliente = await config.getConexao();
//                               if (conexaoCliente != null) {
//                                 ConfigSistema.retornarIPMaquina().then((ip) async {
//                                   if (ip.isNotEmpty) {
//                                     if (ip != conexaoCliente.servidor) {
//                                       await Modular.get<Client>().connect(conexaoCliente.servidor, int.parse(conexaoCliente.porta));
//                                     }
//                                   }
//                                 });
//                               }
//                             },
//                             child: const Text('Reconectar', style: TextStyle(color: Colors.white)),
//                           ),
//                         ),
//                         SizedBox(
//                           height: 40,
//                           child: IconButton(
//                             onPressed: () {
//                               ScaffoldMessenger.of(AppRotas.navigatorKey!.currentContext!).removeCurrentSnackBar();
//                             },
//                             icon: const Icon(Icons.close, color: Colors.white),
//                           ),
//                         ),
//                       ],
//                     )
//                   ],
//                 ),
//                 backgroundColor: Colors.red,
//                 duration: const Duration(days: 300),
//               ),
//             );
//           }
//         },
//       );

//       return true;
//     } catch (e) {
//       connected = false;
//       log('Error', error: e);
//       notifyListeners();
//       return false;
//     }
//   }

//   write(String message) {
//     try {
//       channel!.sink.add(message);
//       return;
//     } catch (e) {
//       if (kDebugMode) {
//         print(e);
//       }
//     }
//   }

//   disconnect() {
//     try {
//       if (channel == null) return;
//       write(jsonEncode({
//         'tipo': 'Desconectou',
//         'nomeConexao': 'Sem Nome',
//         'idUsuario': '0',
//       }));

//       if (AppRotas.navigatorKey?.currentContext != null && AppRotas.navigatorKey!.currentContext!.mounted) {
//         ScaffoldMessenger.of(AppRotas.navigatorKey!.currentContext!).showSnackBar(
//           SnackBar(
//             content: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text('Banco de dados foi desconectado.'),
//                 Row(
//                   children: [
//                     SizedBox(
//                       height: 30,
//                       child: TextButton(
//                         onPressed: () async {
//                           if (DioCliente().tipoDeInstalador == '1') {
//                             Modular.get<AutenticacaoProvedor>().baseUrlSistema = (await Conexao().getConexaoSistema()).servidor;
//                           }

//                           final ConfigSharedPreferences config = ConfigSharedPreferences();
//                           var conexaoCliente = await config.getConexao();
//                           if (conexaoCliente != null) {
//                             ConfigSistema.retornarIPMaquina().then((ip) async {
//                               if (ip.isNotEmpty) {
//                                 if (ip != conexaoCliente.servidor) {
//                                   await Modular.get<Client>().connect(conexaoCliente.servidor, int.parse(conexaoCliente.porta));
//                                 }
//                               }
//                             });
//                           }
//                         },
//                         child: const Text('Reconectar', style: TextStyle(color: Colors.white)),
//                       ),
//                     ),
//                     SizedBox(
//                       height: 40,
//                       child: IconButton(
//                         onPressed: () {
//                           ScaffoldMessenger.of(AppRotas.navigatorKey!.currentContext!).removeCurrentSnackBar();
//                         },
//                         icon: const Icon(Icons.close, color: Colors.white),
//                       ),
//                     ),
//                   ],
//                 )
//               ],
//             ),
//             backgroundColor: Colors.red,
//             duration: const Duration(days: 300),
//           ),
//         );
//       }

//       channel!.sink.close();
//       connected = false;
//     } catch (e) {
//       if (kDebugMode) {
//         print(e);
//       }
//     }
//   }

//   void onData(dynamic data) async {
//     try {
//       var dados = ModeloRetornoSocket.fromJson(data);

//       if (contextMesa != null) {
//         if (contextMesa!.mounted) {
//           Navigator.pop(contextMesa!);
//         }
//       }

//       if (contextMesa1 != null) {
//         if (contextMesa1!.mounted) {
//           Navigator.pop(contextMesa1!);
//         }
//       }
//       if (contextComanda != null) {
//         if (contextComanda!.mounted) {
//           Navigator.pop(contextComanda!);
//         }
//       }
//       if (contextComanda1 != null) {
//         if (contextComanda1!.mounted) {
//           Navigator.pop(contextComanda1!);
//         }
//       }

//       if (dados.tipo == 'MesaNFC') {
//         MesaModelo mesa = MesaModelo.fromMap({
//           'id': dados.id,
//           'idComandaPedido': dados.idComandaPedido,
//           'nome': dados.nome,
//           'codigo': dados.codigo,
//           'mesaOcupada': dados.ocupado,
//         });

//         if (dados.ocupado == true) {
//           showDialog(
//             context: AppRotas.navigatorKey!.currentContext!,
//             builder: (context) {
//               contextMesa = context;

//               return ModalAddOuFinalizarMesa(
//                 mesa: mesa,
//               );
//             },
//           );
//         } else {
//           var provedor = Modular.get<Provedoreswordmesa>();
//           provedor.modalEstaAparecendo = true;

//           showDialog(
//             context: AppRotas.navigatorKey!.currentContext!,
//             builder: (context) {
//               contextMesa1 = context;

//               return ModalAbrirMesa(
//                 mesa: mesa,
//               );
//             },
//           ).then((value) {
//             provedor.modalEstaAparecendo = false;
//           });
//         }
//       } else if (dados.tipo == 'ComandaNFC') {
//         Modelowordcomanda comanda = Modelowordcomanda.fromMap({
//           'id': dados.id,
//           'idComandaPedido': dados.idComandaPedido,
//           'nome': dados.nome,
//           'codigo': dados.codigo,
//           'comandaOcupada': dados.ocupado,
//         });

//         if (dados.ocupado == true) {
//           showDialog(
//             context: AppRotas.navigatorKey!.currentContext!,
//             builder: (context) {
//               contextComanda = context;

//               return ModalAddOuFinalizar(
//                 comanda: comanda,
//               );
//             },
//           );
//         } else {
//           var provedor = Modular.get<Provedoreswordcomandaspedidos>();
//           provedor.modalEstaAparecendo = true;

//           showDialog(
//             context: AppRotas.navigatorKey!.currentContext!,
//             builder: (context) {
//               contextComanda1 = context;

//               return ModalAbrirComanda(
//                 comanda: comanda,
//               );
//             },
//           ).then((value) {
//             provedor.modalEstaAparecendo = false;
//           });
//         }
//       }

//       AtualizacaoDeTela().call(dados);

//       // pedido
//       if (dados.tipoImpressao == '1') {
//         Impressao.comprovanteDePedido(
//           produtos: dados.produtos ?? [],
//           comanda: dados.comanda ?? '',
//           numeroPedido: dados.numeroPedido ?? '',
//           nomeCliente: dados.nomeCliente ?? '',
//           nomeEmpresa: dados.nomeEmpresa ?? '',
//           tipodeentrega: dados.tipodeentrega ?? '',
//           tipoTela: dados.tipo == 'Mesa'
//               ? TipoCardapio.mesa
//               : dados.tipo == 'Comanda'
//                   ? TipoCardapio.comanda
//                   : TipoCardapio.balcao,
//           imprimirSomenteLocal: true,
//           enviarDeVolta: dados.enviarDeVolta ?? false,
//         );

//         // conta
//       } else if (dados.tipoImpressao == '2') {
//         Impressao.comprovanteDeConsumo(
//           produtos: dados.produtos ?? [],
//           celularEmpresa: dados.celularEmpresa ?? '',
//           nomelancamento: dados.nomelancamento ?? [],
//           somaValorHistorico: dados.somaValorHistorico ?? '0',
//           cnpjEmpresa: dados.cnpjEmpresa ?? '',
//           enderecoEmpresa: dados.enderecoEmpresa ?? '',
//           nomeEmpresa: dados.nomeEmpresa ?? '',
//           total: dados.total ?? '0',
//           numeroPedido: dados.numeroPedido ?? '0',
//           local: dados.local ?? '',
//           permanencia: dados.permanencia!,
//           tipodeentrega: dados.tipodeentrega!,
//           imprimirSomenteLocal: true,
//         );
//       } else if (dados.tipoImpressao == '3') {
//         Impressao.comprovanteDoEntregador(
//           produtos: dados.produtos ?? [],
//           celularEmpresa: dados.celularEmpresa ?? '',
//           nomelancamento: dados.nomelancamento ?? [],
//           somaValorHistorico: dados.somaValorHistorico ?? '0',
//           cnpjEmpresa: dados.cnpjEmpresa ?? '',
//           enderecoEmpresa: dados.enderecoEmpresa ?? '',
//           nomeEmpresa: dados.nomeEmpresa ?? '',
//           total: dados.total ?? '0',
//           numeroPedido: dados.numeroPedido ?? '0',
//           permanencia: dados.permanencia ?? '',
//           celularCliente: dados.celularCliente ?? '',
//           enderecoCliente: dados.enderecoCliente ?? '',
//           nomeCliente: dados.nomeCliente ?? '',
//           valortroco: dados.valortroco ?? '',
//           valorentrega: dados.valorentrega ?? '',
//           bairroCliente: dados.bairroCliente ?? '',
//           cidadeCliente: dados.cidadeCliente ?? '',
//           complementoCliente: dados.complementoCliente ?? '',
//           numeroCliente: dados.numeroCliente ?? '',
//           tipodeentrega: dados.tipodeentrega ?? '',
//           imprimirSomenteLocal: true,
//         );
//       }

//       idUsuarioConectado = dados.idUsuario ?? '0';
//     } catch (e) {
//       if (kDebugMode) {
//         print(e);
//       }
//     }
//   }

//   void onError(dynamic d) {}
// }
