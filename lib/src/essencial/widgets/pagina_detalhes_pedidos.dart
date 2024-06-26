import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/comandas/ui/pagina_comanda_desocupada.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class PaginaDetalhesPedido extends StatefulWidget {
  final String? idComanda;
  final String? idMesa;
  const PaginaDetalhesPedido({super.key, this.idComanda, this.idMesa});

  @override
  State<PaginaDetalhesPedido> createState() => _PaginaDetalhesPedidoState();
}

class _PaginaDetalhesPedidoState extends State<PaginaDetalhesPedido> {
  @override
  Widget build(BuildContext context) {
    var nomeTipo = widget.idComanda != null
        ? 'Comanda'
        : widget.idMesa != null
            ? 'Mesa'
            : '';
    var idTipo = widget.idComanda ?? (widget.idMesa ?? '');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Detalhes da $nomeTipo'),
      ),
      body: Column(
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
                      '$nomeTipo $idTipo',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Icon(Icons.person_outline_outlined, size: 30),
                    SizedBox(width: 10),
                    Text(
                      'João Pedro Siqueira Chiquitin',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 50),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ButtonStyle(
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      backgroundColor: WidgetStatePropertyAll(Theme.of(context).colorScheme.inversePrimary),
                    ),
                    onPressed: () {
                      if (widget.idComanda != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return PaginaCardapio(tipo: 'Comanda', idComanda: widget.idComanda, idMesa: '0');
                          },
                        ));
                      } else if (widget.idMesa != null) {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return PaginaCardapio(tipo: 'Mesa', idComanda: '0', idMesa: widget.idMesa!);
                          },
                        ));
                      }
                    },
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_circle_outline_outlined,
                          size: 26,
                          color: Colors.white,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Adicionar',
                          style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.w700),
                        ),
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
                    onPressed: () {},
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_basket_outlined,
                          size: 26,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Pedidos',
                          style: TextStyle(fontSize: 18),
                        ),
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
                      if (widget.idComanda != null) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaginaComandaDesocupada(id: widget.idComanda!, nome: 'Comanda'),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit,
                          size: 26,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Editar $nomeTipo',
                          style: const TextStyle(fontSize: 18),
                        ),
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
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.print_outlined,
                                            size: 26,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Fechar',
                                            style: TextStyle(fontSize: 18),
                                          ),
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
                                        shape: WidgetStatePropertyAll(
                                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.folder_zip_outlined,
                                            size: 26,
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            'Abrir',
                                            style: TextStyle(fontSize: 18),
                                          ),
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
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                  TempoAberto(
                                    textStyle: TextStyle(
                                      fontSize: 18,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
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
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            100.obterReal(),
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
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
    );
  }
}
