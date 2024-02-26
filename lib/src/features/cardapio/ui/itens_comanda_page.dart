import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ItensComandaPage extends StatefulWidget {
  final String idComanda;
  final String idMesa;
  const ItensComandaPage({super.key, required this.idComanda, required this.idMesa});

  @override
  State<ItensComandaPage> createState() => _ItensComandaPageState();
}

class _ItensComandaPageState extends State<ItensComandaPage> {
  final ItensComandaState state = ItensComandaState();
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    double itemWidth = MediaQuery.of(context).size.width / 2;

    return ValueListenableBuilder(
      valueListenable: itensComandaState,
      builder: (context, value, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Comanda'),
          centerTitle: true,
          actions: [
            if (value.listaComandosPedidos.isNotEmpty) ...[
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        children: [
                          const Text(
                            'Deseja realmente excluir todos?',
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Carcelar'),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () async {
                                    List<String> listaIdItemComanda = [];
                                    for (int index = 0; index < value.listaComandosPedidos.length; index++) {
                                      listaIdItemComanda.add(value.listaComandosPedidos[index].id);
                                    }

                                    final res = await state.removerComandasPedidos(widget.idComanda, widget.idMesa, listaIdItemComanda);

                                    Navigator.pop(context);

                                    if (res) return;

                                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                      content: Text('Ocorreu um erro'),
                                      showCloseIcon: true,
                                    ));
                                  },
                                  child: const Text('excluir'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete),
              ),
            ]
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: value.listaComandosPedidos.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  setState(() => isLoading = !isLoading);
                  final res = await state.lancarPedido(
                    widget.idMesa,
                    widget.idComanda,
                    value.precoTotal,
                    value.quantidadeTotal,
                    '',
                    [...value.listaComandosPedidos.map((e) => e.id)],
                  );
                  setState(() => isLoading = !isLoading);

                  if (mounted && res) {
                    Navigator.pop(context);
                    return;
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ocorreu um erro'),
                      showCloseIcon: true,
                    ));
                  }
                },
                label: isLoading
                    ? const CircularProgressIndicator()
                    : const Row(
                        children: [
                          Text('Finalizar'),
                          SizedBox(width: 10),
                          Icon(Icons.check),
                        ],
                      ),
              ),
        bottomNavigationBar: Visibility(
          visible: true,
          child: Material(
            color: const Color.fromARGB(255, 61, 61, 61),
            child: InkWell(
              onTap: () {},
              child: SizedBox(
                height: kToolbarHeight,
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 30),
                        child: SizedBox(
                          width: itemWidth,
                          child: const Text(
                            'Total: ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      width: itemWidth,
                      padding: const EdgeInsets.only(right: 30),
                      child: Text('R\$ ${value.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.right),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
          // child: widget.listaComandosPedidos.isEmpty
          child: value.listaComandosPedidos.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 100, child: Center(child: Text('Não há itens na Comanda'))),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: value.listaComandosPedidos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == value.listaComandosPedidos.length) {
                      return const SizedBox(height: 100, child: Center(child: Text('Fim da Lista')));
                    }

                    final item = value.listaComandosPedidos[index];
                    return Card(
                      clipBehavior: Clip.hardEdge,
                      child: InkWell(
                        key: widget.key,
                        onTap: () async {},
                        borderRadius: BorderRadius.circular(5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                fadeOutDuration: const Duration(milliseconds: 100),
                                placeholder: (context, url) => const SizedBox(
                                  height: 50.0,
                                  width: 50.0,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                                imageUrl: item.foto,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.all(0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width - 130,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        SizedBox(
                                          width: MediaQuery.of(context).size.width - 190,
                                          child: Text(
                                            '${item.nome} ID: ${item.id}',
                                            style: const TextStyle(
                                              fontSize: 17,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                        InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => Dialog(
                                                child: ListView(
                                                  padding: const EdgeInsets.all(20),
                                                  shrinkWrap: true,
                                                  children: [
                                                    const Text(
                                                      'Deseja realmente excluir?',
                                                      style: TextStyle(fontSize: 20),
                                                    ),
                                                    const SizedBox(height: 15),
                                                    Expanded(
                                                      child: Row(
                                                        mainAxisAlignment: MainAxisAlignment.end,
                                                        children: [
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(context);
                                                            },
                                                            child: const Text('Carcelar'),
                                                          ),
                                                          const SizedBox(width: 10),
                                                          TextButton(
                                                            onPressed: () async {
                                                              final res = await state.removerComandasPedidos(
                                                                widget.idComanda,
                                                                widget.idMesa,
                                                                [item.id],
                                                              );

                                                              Navigator.pop(context);

                                                              if (res) return;

                                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                                content: Text('Ocorreu um erro'),
                                                                showCloseIcon: true,
                                                              ));
                                                            },
                                                            child: const Text('excluir'),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                          child: const SizedBox(
                                            width: 50,
                                            height: 40,
                                            child: Center(
                                              child: Icon(
                                                Icons.close,
                                                color: Colors.red,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    'Sem descrição',
                                    overflow: TextOverflow.fade,
                                    maxLines: 2,
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 111, 111, 111),
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width - 140,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '${item.quantidade.toStringAsFixed(0)} x R\$ ${item.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                                          style: const TextStyle(fontSize: 15),
                                        ),
                                        SizedBox(
                                          child: Align(
                                            alignment: Alignment.bottomRight,
                                            child: Text(
                                              'R\$ ${(item.valor * item.quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                                              style: const TextStyle(color: Colors.green, fontSize: 17),
                                            ),
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
                  },
                ),
        ),
      ),
    );
  }
}
