import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final String? idComanda;
  final String tipo;
  const TabCustom({super.key, required this.category, this.idComanda, required this.tipo});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final ProdutoState _state;

  void listarProdutos() async {
    _state.listarProdutos(widget.category);
  }

  @override
  void initState() {
    super.initState();

    _state = ProdutoState([]);
    listarProdutos();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async => listarProdutos(),
      child: ValueListenableBuilder(
          valueListenable: _state,
          builder: (context, value, child) {
            List<ProdutoModel> listaProdutos = [];

            value.map((e) => e.categoria == widget.category ? listaProdutos = e.listaProdutos : listaProdutos = []).toList();

            if (listaProdutos.isEmpty) {
              return ListView(
                children: const [Text('hhh')],
              );
            }

            return ListView.builder(
              itemCount: listaProdutos.length,
              itemBuilder: (context, index) {
                final item = listaProdutos[index];

                return Card(
                  clipBehavior: Clip.hardEdge,
                  child: InkWell(
                    key: widget.key,
                    onTap: () async {
                      Modular.to.pushNamed("/cardapio/produto/${widget.tipo}/${widget.idComanda}", arguments: item);
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: Row(
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
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Align(
                                alignment: Alignment.topLeft,
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width / 1.6,
                                  child: Text(
                                    "${item.nome} ${item.tamanho}",
                                    style: const TextStyle(
                                      fontSize: 17,
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: MediaQuery.of(context).size.width / 1.6,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: Text(
                                      item.descricao.isEmpty ? 'Sem descrição' : item.descricao,
                                      overflow: TextOverflow.fade,
                                      // softWrap: false,
                                      maxLines: 2,
                                      style: const TextStyle(
                                        color: Color.fromARGB(255, 111, 111, 111),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 1.6,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    Utils.coverterEmReal.format(double.parse(item.valorVenda)),
                                    style: const TextStyle(color: Colors.green, fontSize: 17),
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
    );
  }
}
