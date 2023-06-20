import 'package:app/app/data/blocs/produtos/produtos_bloc.dart';
import 'package:app/app/data/blocs/produtos/produtos_event.dart';
import 'package:app/app/data/blocs/produtos/produtos_state.dart';
import 'package:app/app/pages/produto_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class TabCustom extends StatefulWidget {
  final String category;
  const TabCustom({super.key, required this.category});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  late final ProdutosBloc _produtosBloc;

  @override
  void initState() {
    super.initState();
    _produtosBloc = ProdutosBloc();
    _produtosBloc.add(GetProdutos(category: widget.category));
  }

  Future<void> _pullRefresh() async {
    _produtosBloc.add(GetProdutos(category: widget.category));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: BlocBuilder<ProdutosBloc, ProdutosState>(
          bloc: _produtosBloc,
          builder: (context, state) {
            if (state is ProdutoLoadingState) {
              return const Center(child: CircularProgressIndicator());
            } else if (state is ProdutoLoadedState) {
              return ListView.builder(
                itemCount: state.produtos.isEmpty ? 1 : state.produtos.length,
                itemBuilder: (context, index) {
                  if (state.produtos.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 30),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Text('Sem Produtos'),
                      ),
                    );
                  }

                  final produtos = state.produtos[index];

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProdutoPage(
                            produto: produtos,
                          ),
                        ),
                      );
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
                                image: produtos.imagem,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 9),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${produtos.nome} ${produtos.tamanho}",
                                    style: const TextStyle(
                            
                                      fontSize: 12,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5),
                                    child: SizedBox(
                                      width: 270,
                                      child: Text(
                                        produtos.descricao,
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
                                    "R\$ ${produtos.valor}",
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
              );
            } else {
              return const Text('Error');
            }

            // return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _produtosBloc.close();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;
}
