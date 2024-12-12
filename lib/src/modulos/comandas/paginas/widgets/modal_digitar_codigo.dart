import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ModalDigitarCodigo extends StatefulWidget {
  final TipoCardapio tipo;
  const ModalDigitarCodigo({super.key, required this.tipo});

  @override
  State<ModalDigitarCodigo> createState() => _ModalDigitarCodigoState();
}

class _ModalDigitarCodigoState extends State<ModalDigitarCodigo> {
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();

  TextEditingController codigoController = TextEditingController();

  bool listando = false;

  void botaoAbrir() async {
    if (codigoController.text.isEmpty) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Você precisa digitar um código'),
        backgroundColor: Colors.red,
        showCloseIcon: true,
      ));
      return;
    }
    if (context.mounted) {
      setState(() {
        listando = true;
      });
    }

    var servico = Modular.get<ServicoCardapio>();

    var value = await servico.listarIdCodigoQrcode(widget.tipo, codigoController.text);

    if (value.sucesso == false) {
      if (mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nenhuma ${widget.tipo.nome} foi encontrada com o código ${codigoController.text}'),
          backgroundColor: Colors.red,
          showCloseIcon: true,
        ));
      }
      if (context.mounted) {
        setState(() {
          listando = false;
        });
      }
      return;
    }

    if (mounted) {
      Navigator.pop(context);
    }

    if (widget.tipo == TipoCardapio.mesa) {
      if (value.ocupado == true) {
        if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '1') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaginaDetalhesPedido(
                  idComandaPedido: value.idComandaPedido,
                  idMesa: value.id,
                  tipo: TipoCardapio.mesa,
                ),
              ),
            );
          }
        } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '2') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaginaDetalhesPedido(
                  idComandaPedido: value.idComandaPedido,
                  idMesa: value.id,
                  tipo: TipoCardapio.mesa,
                  abrirModalFecharDireto: true,
                ),
              ),
            );
          }
        } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '3') {
          if (value.fechamento == true) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaDetalhesPedido(
                    idComandaPedido: value.idComandaPedido,
                    idMesa: value.id,
                    tipo: TipoCardapio.mesa,
                  ),
                ),
              );
            }
            return;
          }

          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return PaginaCardapio(
                  tipo: TipoCardapio.comanda,
                  idComanda: value.id,
                  idMesa: '0',
                  idCliente: value.idCliente,
                  id: value.idComandaPedido,
                );
              },
            ));
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaginaComandaDesocupada(
                id: value.id,
                nome: value.nome,
                tipo: TipoCardapio.mesa,
              ),
            ),
          );
        }
      }
    } else if (widget.tipo == TipoCardapio.comanda) {
      if (value.ocupado == true) {
        if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '1') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaginaDetalhesPedido(
                  idComandaPedido: value.idComandaPedido,
                  idComanda: value.id,
                  tipo: TipoCardapio.comanda,
                ),
              ),
            );
          }
        } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '2') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaginaDetalhesPedido(
                  idComandaPedido: value.idComandaPedido,
                  idComanda: value.id,
                  tipo: TipoCardapio.comanda,
                  abrirModalFecharDireto: true,
                ),
              ),
            );
          }
        } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '3') {
          if (value.fechamento == true) {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaDetalhesPedido(
                    idComandaPedido: value.idComandaPedido,
                    idComanda: value.id,
                    tipo: TipoCardapio.comanda,
                  ),
                ),
              );
            }
            return;
          }

          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return PaginaCardapio(
                  tipo: TipoCardapio.comanda,
                  idComanda: value.id,
                  idMesa: '0',
                  idCliente: value.idCliente,
                  id: value.idComandaPedido,
                );
              },
            ));
          }
        }
      } else {
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PaginaComandaDesocupada(
                id: value.id,
                nome: value.nome,
                tipo: TipoCardapio.comanda,
              ),
            ),
          );
        }
      }
    }

    if (context.mounted) {
      setState(() {
        listando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {},
        child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, __) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                    color: Colors.white,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Digite o código da ${widget.tipo.nome}', style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 20),
                        TextField(
                          autofocus: true,
                          controller: codigoController,
                          decoration: const InputDecoration(
                            hintText: 'Código',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (value) {
                            botaoAbrir();
                          },
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: const WidgetStatePropertyAll(Colors.green),
                              foregroundColor: const WidgetStatePropertyAll(Colors.white),
                              shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              )),
                            ),
                            onPressed: () async {
                              botaoAbrir();
                            },
                            child: listando
                                ? const Center(
                                    child: SizedBox(
                                      width: 15,
                                      height: 15,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    ),
                                  )
                                : const Text('Abrir', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              );
            }),
      ),
    );
  }
}
