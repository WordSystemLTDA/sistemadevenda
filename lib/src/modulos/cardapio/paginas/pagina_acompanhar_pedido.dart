import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaAcompanharPedido extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;

  const PaginaAcompanharPedido({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    required this.tipo,
  });

  @override
  State<PaginaAcompanharPedido> createState() => _PaginaAcompanharPedidoState();
}

class _PaginaAcompanharPedidoState extends State<PaginaAcompanharPedido> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  Modeloworddadoscardapio? dados;

  @override
  void initState() {
    super.initState();
    listarComandasPedidos();
  }

  void listarComandasPedidos() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido ?? '0', TipoCardapio.comanda, 'Sim').then((value) {
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
          title: Text('Detalhes da $nomeTipo'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

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

                return CardProdutoAcompanhar(
                  item: item,
                  dados: dados,
                  idComanda: widget.idComanda ?? '0',
                  idComandaPedido: widget.idComandaPedido ?? '0',
                  idMesa: widget.idMesa ?? '0',
                  setarQuantidade: (increase) {},
                  value: '',
                  tipo: widget.tipo,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
