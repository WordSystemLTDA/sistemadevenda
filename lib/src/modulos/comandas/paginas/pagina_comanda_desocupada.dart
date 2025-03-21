// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaComandaDesocupada extends StatefulWidget {
  final String id;
  final String? idComandaPedido;
  final String? codigoQrcode;
  final String nome;
  final TipoCardapio tipo;

  const PaginaComandaDesocupada({
    super.key,
    required this.id,
    this.idComandaPedido,
    this.codigoQrcode,
    required this.nome,
    required this.tipo,
  });

  @override
  State<PaginaComandaDesocupada> createState() => _PaginaComandaDesocupadaState();
}

class _PaginaComandaDesocupadaState extends State<PaginaComandaDesocupada> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  final _mesaDestinoSearchController = TextEditingController();
  final _clienteSearchController = TextEditingController();
  final _obsconstroller = TextEditingController();

  bool carregando = true;
  bool salvando = false;

  Modeloworddadoscardapio? dados;

  String id = '0';
  String idMesa = '0';
  String idCliente = '0';

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
  ModeloConfigBigchef? configBigchef;

  @override
  void initState() {
    super.initState();
    id = widget.id;

    listarDados();
    if (widget.idComandaPedido != null) {
      listarComandasPedidos();
    } else {
      carregando = false;
    }
  }

  @override
  void dispose() {
    _mesaDestinoSearchController.dispose();
    _clienteSearchController.dispose();
    _obsconstroller.dispose();
    super.dispose();
  }

  void listarDados() async {
    await servicoConfigBigchef.listar().then((value) {
      setState(() {
        configBigchef = value;
      });
    });
  }

  Future<void> listarPorCodigoQrcode() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido!, TipoCardapio.comanda, 'Não').then((value) {
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente!;
        _mesaDestinoSearchController.text = value.nomeMesa!;
        _obsconstroller.text = value.observacoes!;
        idCliente = value.idCliente!;
        idMesa = value.idMesa!;
        carregando = false;
      });
    });
  }

  Future<void> listarComandasPedidos() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido!, TipoCardapio.comanda, 'Não').then((value) {
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente!;
        _mesaDestinoSearchController.text = value.nomeMesa!;
        _obsconstroller.text = value.observacoes!;
        idCliente = value.idCliente!;
        idMesa = value.idMesa!;
        carregando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.tipo.nome),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: Visibility(
          visible: carregando == false,
          child: FloatingActionButton.extended(
            onPressed: () async {
              if (salvando) return;

              setState(() {
                salvando = true;
              });

              final Server server = Modular.get<Server>();
              final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();

              if (widget.tipo == TipoCardapio.mesa) {
                final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
                if (widget.idComandaPedido != null) {
                  await provedorMesas.editarMesaOcupada(widget.idComandaPedido!, id, idCliente, _obsconstroller.text).then((sucesso) {
                    if (context.mounted) {
                      if (sucesso) {
                        server.write(jsonEncode({
                          'tipo': 'Mesa',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));

                        Navigator.pop(context);
                        Navigator.pop(context);
                      }

                      if (!sucesso) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    }
                  });
                } else {
                  await provedorMesas.inserirMesaOcupada(id, idCliente, _obsconstroller.text).then((resposta) async {
                    if (context.mounted) {
                      provedorComanda.listarMesas('');

                      if (resposta.sucesso) {
                        server.write(jsonEncode({
                          'tipo': 'Mesa',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));
                        Navigator.pop(context);
                        if (configBigchef != null && configBigchef!.abrircomandadireto == 'Sim') {
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return PaginaCardapio(
                                  tipo: TipoCardapio.mesa,
                                  idComanda: '0',
                                  idMesa: id,
                                  idCliente: idCliente,
                                  id: resposta.idcomandapedido,
                                );
                              },
                            ));
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      }

                      if (!resposta.sucesso) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Ocorreu um erro'),
                            showCloseIcon: true,
                          ));
                        }
                      }
                    }
                  });
                }
              } else {
                if (widget.idComandaPedido != null) {
                  await _state.editarComandaOcupada(widget.idComandaPedido!, idMesa, idCliente, _obsconstroller.text).then((sucesso) {
                    if (context.mounted) {
                      if (sucesso) {
                        server.write(jsonEncode({
                          'tipo': 'Comanda',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));
                        Navigator.pop(context);
                        Navigator.pop(context);
                      }

                      if (!sucesso) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    }
                  });
                } else {
                  await _state.inserirComandaOcupada(id, idMesa, idCliente, _obsconstroller.text).then((resposta) async {
                    if (context.mounted) {
                      provedorComanda.listarComandas('');

                      if (resposta.sucesso) {
                        server.write(jsonEncode({
                          'tipo': 'Comanda',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));

                        Navigator.pop(context);
                        if (configBigchef != null && configBigchef!.abrircomandadireto == 'Sim') {
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return PaginaCardapio(
                                  tipo: TipoCardapio.comanda,
                                  idComanda: id,
                                  idMesa: '0',
                                  idCliente: idCliente,
                                  id: resposta.idcomandapedido,
                                );
                              },
                            ));
                          }
                        } else {
                          Navigator.pop(context);
                        }
                      }

                      if (!resposta.sucesso) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Ocorreu um erro'),
                            showCloseIcon: true,
                          ));
                        }
                      }
                    }
                  });
                }
              }

              setState(() {
                salvando = false;
              });
            },
            label: Row(
              children: [
                if (salvando) ...[
                  const Center(child: CircularProgressIndicator()),
                ] else ...[
                  Text(widget.idComandaPedido != null ? 'Editar Comanda' : 'Abrir Comanda'),
                  const SizedBox(width: 10),
                  const Icon(Icons.check),
                ],
              ],
            ),
          ),
        ),
        body: Visibility(
          visible: carregando == false,
          replacement: const Center(child: CircularProgressIndicator()),
          child: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fact_check_outlined, size: 44),
                        const SizedBox(width: 10),
                        Text(widget.nome, style: const TextStyle(fontSize: 22)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.tipo != TipoCardapio.mesa) ...[
                      const Text('Mesa de Destino', style: TextStyle(fontSize: 18)),
                      SearchAnchor(
                        builder: (BuildContext context, SearchController controller) {
                          return TextField(
                            controller: _mesaDestinoSearchController,
                            readOnly: true,
                            decoration: const InputDecoration(
                              // contentPadding: EdgeInsets.all(12),
                              border: UnderlineInputBorder(),
                              isDense: true,
                              hintText: 'Selecione a Mesa de Destino',
                            ),
                            onTap: () => controller.openView(),
                          );
                        },
                        suggestionsBuilder: (BuildContext context, SearchController controller) async {
                          final keyword = controller.value.text;
                          final res = await _state.listarMesas(keyword);

                          var semMesa = {'nome': 'Sem Mesa', 'id': '0'};

                          return [
                            ...[semMesa, ...res].map((e) => Card(
                                  elevation: 3.0,
                                  margin: const EdgeInsets.all(5.0),
                                  child: InkWell(
                                    onTap: () {
                                      controller.closeView('');
                                      _mesaDestinoSearchController.text = e['nome'];
                                      idMesa = e['id'];
                                    },
                                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                                    child: ListTile(
                                      leading: const Icon(Icons.table_bar_outlined),
                                      title: Text(e['nome']),
                                      subtitle: Text('ID: ${e['id']}'),
                                    ),
                                  ),
                                )),
                          ];
                        },
                      ),
                      const SizedBox(height: 10),
                    ],
                    const Text('Cliente', style: TextStyle(fontSize: 18)),
                    SearchAnchor(
                      builder: (BuildContext context, SearchController controller) {
                        return TextField(
                          controller: _clienteSearchController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            isDense: true,
                            hintText: 'Selecione o Cliente',
                            suffixIcon: IconButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return const InserirCliente();
                                  },
                                )).then((value) {
                                  if (value != null) {
                                    var cliente = value as Map;

                                    _clienteSearchController.text = cliente['nomecliente'];
                                    idCliente = value['idcliente'];
                                  }
                                });
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ),
                          onTap: () => controller.openView(),
                        );
                      },
                      suggestionsBuilder: (BuildContext context, SearchController controller) async {
                        final keyword = controller.value.text;
                        final res = await _state.listarClientes(keyword);
                        return [
                          ...res.map(
                            (e) => Card(
                              elevation: 3.0,
                              margin: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () {
                                  controller.closeView('');
                                  _clienteSearchController.text = e['nome'];
                                  idCliente = e['id'];
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: ListTile(
                                  leading: const Icon(Icons.person_2_outlined),
                                  title: Text(e['nome']),
                                  subtitle: Text('ID: ${e['id']}'),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                    const SizedBox(height: 15),
                    const Text('Observação', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 7),
                    // TextField(
                    //   controller: _obsconstroller,
                    //   decoration: const InputDecoration(
                    //     border: UnderlineInputBorder(),
                    //     isDense: true,
                    //     hintText: 'Obs',
                    //   ),
                    // ),
                    SizedBox(
                      height: 150,
                      child: TextField(
                        maxLines: 4,
                        controller: _obsconstroller,
                        decoration: const InputDecoration(
                          hintText: 'Digite aqui alguma Observação',
                          label: Text('Observação'),
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
