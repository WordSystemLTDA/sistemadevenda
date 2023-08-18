import 'package:app/src/features/produto/interactor/cubit/counter_cubit.dart';
import 'package:app/src/features/produto/interactor/states/counter_state.dart';
import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProdutoPage extends StatefulWidget {
  final ProdutoModel produto;
  const ProdutoPage({super.key, required this.produto});

  @override
  State<ProdutoPage> createState() => _ProdutoPageState();
}

class _ProdutoPageState extends State<ProdutoPage> {
  final CounterCubit _counterCubit = Modular.get<CounterCubit>();

  TextEditingController controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;

    return BlocBuilder<CounterCubit, CounterState>(
      bloc: _counterCubit,
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            FocusScopeNode currentFocus = FocusScope.of(context);

            if (!currentFocus.hasPrimaryFocus) {
              currentFocus.unfocus();
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text("${produto.nome} ${produto.tamanho}"),
            ),
            body: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: CachedNetworkImage(
                          width: 120,
                          height: 120,
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
                      Row(
                        children: [
                          IconButton(
                            onPressed: _counterCubit.decrement,
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 30,
                              color: state.counterValue == 1 ? Colors.grey : Colors.red,
                            ),
                          ),
                          Text(
                            state.counterValue.toString(),
                            style: const TextStyle(fontSize: 20),
                          ),
                          IconButton(
                            onPressed: _counterCubit.increment,
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 30,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (produto.descricao.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        produto.descricao,
                        overflow: TextOverflow.fade,
                        maxLines: 6,
                        style: const TextStyle(color: Color.fromARGB(255, 161, 161, 161)),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      const Text(
                        "Preço: ",
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        Utils.coverterEmReal.format(produto.valor),
                        style: const TextStyle(color: Colors.green, fontSize: 18),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        "Total: ",
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        Utils.coverterEmReal.format(produto.valor * state.counterValue),
                        style: const TextStyle(color: Colors.green, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: controller,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      alignLabelWithHint: true,
                      labelText: "Observação do Produto",
                      hintStyle: TextStyle(fontWeight: FontWeight.w300),
                      border: OutlineInputBorder(),
                    ),
                  )
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () {
                Modular.to.pop();
              },
              child: const Icon(Icons.check),
            ),
          ),
        );
      },
    );
  }
}
