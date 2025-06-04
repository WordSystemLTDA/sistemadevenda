import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_acompanhar_pedido.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/pagina_itens_recorrentes.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaDetalhesPedido extends StatefulWidget {
  final String? codigoQrcode;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;
  final bool? abrirModalFecharDireto;
  final TipoCardapio tipo;

  const PaginaDetalhesPedido({
    super.key,
    this.codigoQrcode,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    this.abrirModalFecharDireto,
    required this.tipo,
  });

  @override
  State<PaginaDetalhesPedido> createState() => _PaginaDetalhesPedidoState();
}

class _PaginaDetalhesPedidoState extends State<PaginaDetalhesPedido> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();

  Modeloworddadoscardapio? dados;
  bool carregando = false;
  String idComanda = '0';
  String idComandaPedido = '0';
  String idMesa = '0';
  String idCliente = '0';

  @override
  void initState() {
    super.initState();
    idComanda = widget.idComanda ?? '0';
    idComandaPedido = widget.idComandaPedido ?? '0';
    idMesa = widget.idMesa ?? '0';

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (mounted) {
        listarComandasPedidos();
      }
    });
  }

  Future<void> listarComandasPedidos() async {
    setState(() {
      carregando = true;
    });

    await servicoCardapio.listarPorId(widget.idComandaPedido ?? '0', widget.tipo, 'Não', codigoQrcode: widget.codigoQrcode).then((value) {
      dados = value;
      idComanda = value.idComanda ?? '0';
      idComandaPedido = value.id ?? '0';
      idMesa = value.idMesa ?? '0';
    });

    setState(() {
      carregando = false;
    });

    if (widget.abrirModalFecharDireto == true) {
      fechar();
    }
  }

  void fechar() async {
    if (dados!.status == 'Fechamento') return;

    showDialog(
      context: context,
      builder: (contextDialog) => AlertDialog(
        title: Text("Fechamento de Comanda"),
        actions: <Widget>[
          TextButton(
            child: const Text('Não'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Sim'),
            onPressed: () async {
              await servicoCardapio.fecharAbrirComanda(idComandaPedido, 'Fechamento').then((value) async {
                if (mounted) {
                  if (value.sucesso) {
                    Modular.get<Server>().write(jsonEncode({
                      'tipo': widget.tipo.nome,
                    }));
                  }

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(value.mensagem), backgroundColor: value.sucesso ? Colors.green : Colors.red),
                  );

                  final duration = DateTime.now().difference(DateTime.parse(dados!.dataAbertura!));
                  final newDuration = ConfigSistema.formatarHora(duration);

                  Impressao.comprovanteDeConsumo(
                    // tipoImpressao: '2',
                    // tipo: widget.tipo,
                    // nomeCliente: dados!.nomeCliente!,
                    tipodeentrega: dados!.tipodeentrega ?? '',
                    valorentrega: dados!.valorentrega ?? '',
                    nomeEmpresa: dados!.nomeEmpresa!,
                    produtos: dados!.produtos!,
                    nomelancamento: dados!.nomelancamento!,
                    somaValorHistorico: dados!.somaValorHistorico!,
                    celularEmpresa: dados!.celularEmpresa!,
                    cnpjEmpresa: dados!.cnpjEmpresa!,
                    enderecoEmpresa: dados!.enderecoEmpresa!,
                    permanencia: newDuration,
                    local: dados!.nome!,
                    total: dados!.valorTotal!,
                    numeroPedido: dados!.numeroPedido!,
                    nomeCliente: (dados!.nomeCliente == '' ? null : dados!.nomeCliente) ?? 'Sem Cliente',
                  );

                  if (widget.tipo == TipoCardapio.mesa) {
                    provedorMesas.listarMesas('');
                  } else if (widget.tipo == TipoCardapio.comanda) {
                    provedorComanda.listarComandas('');
                  }

                  await listarComandasPedidos();
                }
              });
            },
          ),
        ],
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              const Text(
                'Deseja realmente fechar essa comanda?',
                style: TextStyle(fontSize: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void abrir() async {
    if (dados!.status == 'Andamento') return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            const Text(
              'Deseja realmente abrir essa comanda?',
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Não'),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () async {
                    servicoCardapio.fecharAbrirComanda(idComandaPedido, 'Andamento').then((value) {
                      if (context.mounted) {
                        if (value.sucesso) {
                          Modular.get<Server>().write(jsonEncode({
                            'tipo': widget.tipo.nome,
                          }));
                        }

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(value.mensagem), backgroundColor: value.sucesso ? Colors.green : Colors.red),
                        );

                        if (widget.tipo == TipoCardapio.mesa) {
                          provedorMesas.listarMesas('');
                        } else if (widget.tipo == TipoCardapio.comanda) {
                          provedorComanda.listarComandas('');
                        }

                        listarComandasPedidos();
                      }
                    });
                  },
                  child: const Text('Sim'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var nomeTipo = widget.tipo.nome;

    if (dados == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('Detalhes da $nomeTipo'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (dados!.id == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('Detalhes da $nomeTipo'),
        ),
        body: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Não foi possível encontrar essa $nomeTipo',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              const Icon(Icons.not_listed_location_outlined, size: 32),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Detalhes da $nomeTipo'),
      ),
      body: Stack(
        children: [
          if (carregando)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(child: CircularProgressIndicator()),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.topic_outlined, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          dados!.nome!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.person_outline_outlined, size: 30),
                        const SizedBox(width: 10),
                        Text(
                          dados!.nomeCliente!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 50),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.inversePrimary),
                        ),
                        onPressed: () {
                          if (dados!.status == 'Fechamento') {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Comanda está em status de Fechamento", textAlign: TextAlign.center),
                              backgroundColor: Colors.red,
                            ));
                            return;
                          }

                          if (widget.tipo == TipoCardapio.comanda) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return PaginaCardapio(
                                  tipo: TipoCardapio.comanda,
                                  idComanda: dados!.idComanda,
                                  idMesa: '0',
                                  idCliente: dados!.idCliente!,
                                  id: idComandaPedido,
                                );
                              },
                            ));
                          } else if (widget.tipo == TipoCardapio.mesa) {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return PaginaCardapio(
                                  tipo: TipoCardapio.mesa,
                                  idComanda: '0',
                                  idMesa: idMesa,
                                  idCliente: dados!.idCliente!,
                                  id: idComandaPedido,
                                );
                              },
                            ));
                          }
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_outlined, size: 26, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Adicionar', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.inversePrimary),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return PaginaItensRecorrentes(
                                idComanda: idComanda,
                                idComandaPedido: idComandaPedido,
                                idMesa: idMesa,
                                tipo: widget.tipo,
                                idCliente: idCliente,
                              );
                            },
                          ));
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle_outline_outlined, size: 26, color: Colors.white),
                            SizedBox(width: 10),
                            Text('Itens Recorrentes', style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        ),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) {
                              return PaginaAcompanharPedido(
                                idComanda: idComanda,
                                idComandaPedido: idComandaPedido,
                                idMesa: idMesa,
                                tipo: widget.tipo,
                              );
                            },
                          ));
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_basket_outlined, size: 26),
                            SizedBox(width: 10),
                            Text('Pedidos', style: TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: ElevatedButton(
                        style: ButtonStyle(
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        onPressed: () {
                          if (dados!.status == 'Fechamento') {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text("Comanda está em status de Fechamento", textAlign: TextAlign.center),
                              backgroundColor: Colors.red,
                            ));
                            return;
                          }

                          if (idComanda != '0') {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => PaginaComandaDesocupada(
                                  id: idComanda,
                                  idComandaPedido: idComandaPedido,
                                  nome: dados!.nome!,
                                  tipo: widget.tipo,
                                ),
                              ),
                            );
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.edit, size: 26),
                            const SizedBox(width: 10),
                            Text('Editar $nomeTipo', style: const TextStyle(fontSize: 18)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(60), topRight: Radius.circular(60)),
                  color: Theme.of(context).colorScheme.inversePrimary,
                  // gradient: LinearGradient(
                  //   colors: [
                  //     Theme.of(context).colorScheme.inversePrimary,
                  //     Theme.of(context).colorScheme.primary,
                  //   ],
                  //   end: Alignment.bottomRight,
                  // ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text(
                        'Conta',
                        style: TextStyle(fontSize: 26, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, right: 30, bottom: 30, top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 60,
                                        child: ElevatedButton(
                                          style: ButtonStyle(
                                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                            backgroundColor: WidgetStatePropertyAll(dados!.status == 'Fechamento' ? const Color.fromARGB(255, 190, 190, 190) : null),
                                            foregroundColor: WidgetStatePropertyAll(dados!.status == 'Fechamento' ? const Color.fromARGB(255, 112, 110, 110) : null),
                                          ),
                                          onPressed: () {
                                            fechar();
                                          },
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.print_outlined, size: 26),
                                              SizedBox(width: 10),
                                              Text('Fechar', style: TextStyle(fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: SizedBox(
                                        height: 60,
                                        child: ElevatedButton(
                                          style: ButtonStyle(
                                            shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                            backgroundColor: WidgetStatePropertyAll(dados!.status == 'Andamento' ? const Color.fromARGB(255, 190, 190, 190) : null),
                                            foregroundColor: WidgetStatePropertyAll(dados!.status == 'Andamento' ? const Color.fromARGB(255, 112, 110, 110) : null),
                                          ),
                                          onPressed: () {
                                            abrir();
                                          },
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.folder_zip_outlined, size: 26),
                                              SizedBox(width: 10),
                                              Text('Abrir', style: TextStyle(fontSize: 18)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.timelapse_outlined,
                                    size: 24,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Row(
                                    children: [
                                      Text(
                                        'Tempo Aberto: ',
                                        style: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary),
                                      ),
                                      TempoAberto(
                                        textStyle: TextStyle(fontSize: 18, color: Theme.of(context).colorScheme.primary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Total:',
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
                              ),
                              Text(
                                double.parse(dados!.valorTotal!).obterReal(),
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}
