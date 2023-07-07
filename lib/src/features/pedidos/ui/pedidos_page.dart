import 'package:app/src/features/pedidos/interactor/cubit/pedidos_cubit.dart';
import 'package:app/src/features/pedidos/interactor/states/pedidos_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PedidosPage extends StatefulWidget {
  final String? mesa;
  const PedidosPage({super.key, this.mesa});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  @override
  void initState() {
    listarPedidos();
    super.initState();
  }

  Future<void> _pullRefresh() async {
    listarPedidos();
  }

  void listarPedidos() async {
    final cubit = context.read<PedidosCubit>();
    cubit.getPedidos(widget.mesa);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<PedidosCubit>();
    final state = cubit.state;
    final pedidos = state.pedidos;

    return Scaffold(
      appBar: AppBar(
        title: Text('Mesa ${widget.mesa}'),
      ),
      body: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Stack(
            children: [
              if (state is PedidoLoadingState) const LinearProgressIndicator(),
              if (state is PedidoLoadedState)
                GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: pedidos
                      .map(
                        (e) => ElevatedButton(
                          onPressed: () {
                            Navigator.pushNamed(context, "/produtos");
                          },
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          child: Text(
                            e.id,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
