import 'dart:async';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/pagina_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/servicos/servicos_itens_recorrentes.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaItensRecorrentes extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;
  final String? idCliente;

  const PaginaItensRecorrentes({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    this.idCliente,
    required this.tipo,
  });

  @override
  State<PaginaItensRecorrentes> createState() => _PaginaItensRecorrentesState();
}

class _PaginaItensRecorrentesState extends State<PaginaItensRecorrentes> {
  final ProvedorItensRecorrentes provedorItensRecorrentes = Modular.get<ProvedorItensRecorrentes>();
  final ServicosItensRecorrentes servicosItensRecorrentes = Modular.get<ServicosItensRecorrentes>();

  final TextEditingController _pesquisaController = TextEditingController();

  Modeloworddadoscardapio? dados;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    listarComandasPedidos();
  }

  void listarComandasPedidos() async {
    provedorItensRecorrentes.listarComandasPedidos(widget.idComandaPedido ?? '0');
    await servicosItensRecorrentes.listarPorId(widget.idComandaPedido ?? '0', TipoCardapio.comanda, 'Sim').then((value) {
      setState(() {
        dados = value;
      });
    });
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
          // title: Text('Itens Recorrentes da $nomeTipo'),
          title: Text('Itens Recorrentes'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // title: Text('Itens Recorrentes da $nomeTipo'),
        title: Text('Itens Recorrentes'),
      ),
      floatingActionButton: AnimatedBuilder(
        animation: provedorItensRecorrentes,
        builder: (context, _) {
          return badges.Badge(
            badgeContent: Text(provedorItensRecorrentes.itensCarrinho.length.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
            position: badges.BadgePosition.topEnd(end: 0),
            child: FloatingActionButton(
              heroTag: 'botao2',
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return PaginaCarrinhoItensRecorrentes(
                      idComanda: widget.idComanda ?? '0',
                      idComandaPedido: widget.idComandaPedido ?? '0',
                      idMesa: widget.idMesa ?? '0',
                      idCliente: widget.idCliente ?? '0',
                    );
                  },
                ));
              },
              shape: const CircleBorder(),
              child: const Icon(Icons.shopping_cart),
            ),
          );
        },
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Padding(
          //   padding: const EdgeInsets.all(20.0),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       Row(
          //         children: [
          //           const Icon(Icons.topic_outlined, size: 30),
          //           const SizedBox(width: 10),
          //           Text(dados!.nome!, style: const TextStyle(fontSize: 18)),
          //         ],
          //       ),
          //       Row(
          //         children: [
          //           const Icon(Icons.person_outline_outlined, size: 30),
          //           const SizedBox(width: 10),
          //           Text(
          //             dados!.nomeCliente!,
          //             style: const TextStyle(fontSize: 18),
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _pesquisaController,
                // readOnly: true,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey[700]!),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  contentPadding: const EdgeInsets.all(0),
                  hintText: 'Pesquisar...',
                  prefixIcon: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                      // provedor.resetarTudo();
                    },
                    icon: const Icon(Icons.arrow_back),
                  ),
                ),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (value) async {
                  setState(() => _pesquisaController.text = value);
                  // if (_debounce?.isActive ?? false) _debounce!.cancel();

                  // _debounce = Timer(const Duration(milliseconds: 500), () {
                  //   if (value.isEmpty) {
                  //     provedor.listarProdutosPorNome('', widget.category, '0');

                  //     return;
                  //   }

                  //   provedor.listarProdutosPorNome(value, widget.category, '0');
                  // });
                },
                // onTap: () => _searchController.openView(),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              // padding: const EdgeInsets.all(10),
              itemCount: dados!.produtos!.where((e) {
                return e.nome.toLowerCase().contains(_pesquisaController.text.toLowerCase()) || e.codigo.toLowerCase().contains(_pesquisaController.text.toLowerCase());
              }).length,
              itemBuilder: (context, index) {
                var item = dados!.produtos!.where((e) {
                  return e.nome.toLowerCase().contains(_pesquisaController.text.toLowerCase()) || e.codigo.toLowerCase().contains(_pesquisaController.text.toLowerCase());
                }).toList()[index];
                //   provedorItensRecorrentes

                // return SizedBox();
                return CardItensRecorrentes(
                  estaPesquisando: false,
                  searchController: null,
                  item: item,
                  categoria: null,
                  finalizar: true,
                  idComanda: widget.idComanda ?? '0',
                  idMesa: widget.idMesa ?? '0',
                  idComandaPedido: widget.idComandaPedido ?? '0',
                );
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
