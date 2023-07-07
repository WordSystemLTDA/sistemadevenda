import 'package:app/src/features/produtos/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/produtos/interactor/states/produtos_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TabCustom extends StatefulWidget {
  final String category;
  const TabCustom({super.key, required this.category});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  void initState() {
    super.initState();
    final cubit = context.read<ProdutosCubit>();
    cubit.getProdutos(widget.category);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _pullRefresh() async {
    final cubit = context.read<ProdutosCubit>();
    cubit.getProdutos(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cubit = context.watch<ProdutosCubit>();
    final state = cubit.state;
    final produtos = state.produtos;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: Stack(
          children: [
            if (state is ProdutoLoadingState) const Center(child: CircularProgressIndicator()),
            if (state is ProdutoLoadedState)
              ListView.builder(
                itemCount: produtos.isEmpty ? 1 : produtos.length,
                itemBuilder: (context, index) {
                  if (produtos.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text('Sem Produtos'),
                      ),
                    );
                  }

                  final produto = produtos[index];

                  return InkWell(
                    onTap: () {
                      Navigator.pushNamed(context, "/produto", arguments: produto);
                    },
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      height: 100,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: FadeInImage.assetNetwork(
                                width: 70,
                                height: 70,
                                fit: BoxFit.cover,
                                fadeOutDuration: const Duration(milliseconds: 100),
                                placeholder: 'assets/placeholder.png',
                                image: produto.imagem,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${produto.nome} ${produto.tamanho}",
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: SizedBox(
                                      width: 270,
                                      child: Text(
                                        produto.descricao,
                                        overflow: TextOverflow.fade,
                                        maxLines: 2,
                                        style: const TextStyle(
                                          color: Color.fromARGB(255, 111, 111, 111),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "R\$ ${produto.valor}",
                                    style: const TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
