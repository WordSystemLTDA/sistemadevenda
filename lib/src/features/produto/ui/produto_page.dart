import 'package:app/src/features/produto/interactor/cubit/counter_cubit.dart';
import 'package:app/src/features/produto/interactor/cubit/salvar_produto_cubit.dart';
import 'package:app/src/features/produto/interactor/states/counter_state.dart';
import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/features/produto/interactor/states/salvar_produto_state.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProdutoPage extends StatefulWidget {
  final ProdutoModel produto;
  final String? tipo;
  final String? idComanda;
  const ProdutoPage({super.key, required this.produto, required this.tipo, required this.idComanda});

  @override
  State<ProdutoPage> createState() => _ProdutoPageState();
}

class _ProdutoPageState extends State<ProdutoPage> {
  final CounterCubit _counterCubit = Modular.get<CounterCubit>();
  final SalvarProdutoCubit _salvarProdutoCubit = Modular.get<SalvarProdutoCubit>();

  TextEditingController controller = TextEditingController();

  final snackBarErro = SnackBar(
    content: const Text('Erro ao inserir, tente novamente.'),
    action: SnackBarAction(
      label: 'OK',
      onPressed: () {},
    ),
  );

  void inserir(comanda, produto, quantidade) {
    var idComanda = comanda!.isEmpty ? null : comanda;
    var valor = produto.valorVenda;
    var idProduto = produto.id;
    var observacaoMesa = '';
    var observacao = controller.text;

    _salvarProdutoCubit.inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao);
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;
    final idComanda = widget.idComanda;
    final tipo = widget.tipo;

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
            floatingActionButton: BlocConsumer<SalvarProdutoCubit, SalvarProdutoState>(
              bloc: _salvarProdutoCubit,
              listener: (context, stateSalvarProduto) {
                if (stateSalvarProduto is SalvarProdutoSucessoState) {
                  Modular.to.pop();
                } else if (stateSalvarProduto is SalvarProdutoErroState) {
                  ScaffoldMessenger.of(context).showSnackBar(snackBarErro);
                }
              },
              builder: (context, stateSalvarProduto) {
                return FloatingActionButton(
                  onPressed: () {
                    inserir(idComanda, produto, state.counterValue);
                  },
                  child: stateSalvarProduto is SalvarProdutoCarregandoState ? const CircularProgressIndicator() : const Icon(Icons.check),
                );
              },
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
                          imageUrl: produto.foto,
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
                        Utils.coverterEmReal.format(double.parse(produto.valorVenda)),
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
                        Utils.coverterEmReal.format(double.parse(produto.valorVenda) * state.counterValue),
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
          ),
        );
      },
    );
  }
}
