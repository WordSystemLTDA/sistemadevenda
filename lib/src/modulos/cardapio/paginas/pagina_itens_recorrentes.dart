import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaItensRecorrentes extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;

  const PaginaItensRecorrentes({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    required this.tipo,
  });

  @override
  State<PaginaItensRecorrentes> createState() => _PaginaItensRecorrentesState();
}

class _PaginaItensRecorrentesState extends State<PaginaItensRecorrentes> {
  final ProvedorItensRecorrentes provedorItensRecorrentes = Modular.get<ProvedorItensRecorrentes>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  Modeloworddadoscardapio? dados;

  @override
  void initState() {
    super.initState();

    listarComandasPedidos();
  }

  void listarComandasPedidos() async {
    provedorItensRecorrentes.listarComandasPedidos(widget.idComandaPedido ?? '0');
    // await servicoCardapio.listarPorId(widget.idComandaPedido ?? '0', TipoCardapio.comanda, 'Sim').then((value) {
    //   setState(() {
    //     dados = value;
    //   });
    // });
  }

  @override
  Widget build(BuildContext context) {
    var nomeTipo = widget.idComandaPedido != null
        ? 'Comanda'
        : widget.idMesa != null
            ? 'Mesa'
            : '';

    if (dados == null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text('Itens Recorrentes da $nomeTipo'),
          // title: Text('Detalhes da $nomeTipo'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('Itens Recorrentes da $nomeTipo'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: AnimatedBuilder(
        animation: provedorItensRecorrentes,
        builder: (context, _) {
          return Stack(
            children: [
              // if (provedorItensRecorrentes.itensCarrinho.isNotEmpty) ...[
              //   Align(
              //     alignment: Alignment.bottomCenter,
              //     child: SizedBox(
              //       width: 170,
              //       child: FloatingActionButton.extended(
              //         heroTag: 'botao1',
              //         onPressed: () async {
              //           // if (!context.mounted) return;

              //           // var item = provedor.saboresPizzaSelecionados[0];

              //           // Navigator.of(context).push(MaterialPageRoute(
              //           //   builder: (context) {
              //           //     return PaginaSaborBordas(
              //           //       produto: item,
              //           //       valorVenda: provedor.calcularPrecoPizza(),
              //           //     );
              //           //   },
              //           // ));
              //         },
              //         backgroundColor: Colors.green,
              //         foregroundColor: Colors.white,
              //         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              //         label: Text('Avançar'),
              //         // label: Text('Avançar ${provedor.calcularPrecoPizza().obterReal()}'),
              //       ),
              //     ),
              //   ),
              // ],
              Positioned(
                right: 25,
                bottom: 0,
                child: badges.Badge(
                  badgeContent: Text(provedorItensRecorrentes.itensCarrinho.length.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
                  position: badges.BadgePosition.topEnd(end: 0),
                  child: FloatingActionButton(
                    heroTag: 'botao2',
                    onPressed: () {
                      // Navigator.of(context).push(MaterialPageRoute(
                      //   builder: (context) {
                      //     return const PaginaCarrinho();
                      //   },
                      // ));
                    },
                    shape: const CircleBorder(),
                    child: const Icon(Icons.shopping_cart),
                  ),
                ),
              ),
            ],
          );
        },
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
                    Text(dados!.nome!, style: const TextStyle(fontSize: 18)),
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
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(10),
              itemCount: dados!.produtos!.length,
              itemBuilder: (context, index) {
                var item = dados!.produtos![index];
                //   provedorItensRecorrentes

                return SizedBox();
                // return CardItensRecorrentes(
                //   item: item,
                //   dados: dados,
                //   idComanda: widget.idComanda ?? '0',
                //   idComandaPedido: widget.idComandaPedido ?? '0',
                //   idMesa: widget.idMesa ?? '0',
                //   setarQuantidade: (increase) {},
                //   value: '',
                //   tipo: widget.tipo,
                // );
              },
            ),
          ),
        ],
      ),
    );
  }
}
