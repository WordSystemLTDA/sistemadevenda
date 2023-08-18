import 'package:app/src/features/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cached_network_image/cached_network_image.dart';

class TabCustom extends StatefulWidget {
  final String category;
  const TabCustom({super.key, required this.category});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  final ProdutosCubit _produtosCubit = Modular.get<ProdutosCubit>();

  @override
  void initState() {
    _produtosCubit.getProdutos(widget.category);
    super.initState();
  }

  @override
  void dispose() {
    _produtosCubit.close();
    super.dispose();
  }

  Future<void> _pullRefresh() async {
    _produtosCubit.getProdutos(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: BlocBuilder<ProdutosCubit, ProdutosState>(
          bloc: _produtosCubit,
          builder: (context, state) {
            if (state is ProdutoLoadingState) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (state is ProdutoLoadedState) {
              if (state.produtos.isEmpty) {
                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text('Sem Produtos'),
                      ),
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: state.produtos.isEmpty ? 1 : state.produtos.length,
                itemBuilder: (context, index) {
                  final produto = state.produtos[index];

                  return Card(
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      key: widget.key,
                      onTap: () async {
                        Modular.to.pushNamed("/cardapio/produto", arguments: produto);
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
                              imageUrl: produto.imagem,
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
                                      "${produto.nome} ${produto.tamanho}",
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
                                        produto.descricao.isEmpty ? 'Sem descrição' : produto.descricao,
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
                                      Utils.coverterEmReal.format(produto.valor),
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
            }

            return const Text('erro');
          },
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
