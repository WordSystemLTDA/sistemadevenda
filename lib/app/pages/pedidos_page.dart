import 'package:app/app/data/blocs/pedidos/pedidos_bloc.dart';
import 'package:app/app/data/blocs/pedidos/pedidos_event.dart';
import 'package:app/app/data/blocs/pedidos/pedidos_state.dart';
import 'package:app/app/pages/produtos_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:page_transition/page_transition.dart';

class PedidosPage extends StatefulWidget {
  final String mesa;
  const PedidosPage({super.key, required this.mesa});

  @override
  State<PedidosPage> createState() => _PedidosPageState();
}

class _PedidosPageState extends State<PedidosPage> {
  late final PedidosBloc _pedidosBloc;

  @override
  void initState() {
    _pedidosBloc = PedidosBloc();
    _pedidosBloc.add(GetPedidos(idMesa: widget.mesa));
    super.initState();
  }

  Future<void> _pullRefresh() async {
    _pedidosBloc.add(GetPedidos(idMesa: widget.mesa));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Mesa ${widget.mesa}'),
      ),
      body: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: BlocBuilder<PedidosBloc, PedidosState>(
            bloc: _pedidosBloc,
            builder: (context, state) {
              if (state is PedidoLoadingState) {
                return const LinearProgressIndicator();
              } else if (state is PedidoLoadedState) {
                final pedidos = state.pedidos;

                return GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  children: pedidos
                      .map(
                        (e) => ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              PageTransition(
                                child: const ProdutosPage(idMesa: '2'),
                                type: PageTransitionType.rightToLeft,
                              ),
                            );
                          },
                          style: ButtonStyle(
                            shape: MaterialStateProperty.all<
                                RoundedRectangleBorder>(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          child: Text(e.id,
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.white)),
                        ),
                      )
                      .toList(),
                );
              } else {
                return const Text("Error");
              }
            },
          ),
        ),
      ),
    );
  }
}
