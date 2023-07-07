import 'package:app/src/features/mesas/interactor/cubit/mesas/mesas_bloc.dart';
import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';
import 'package:app/src/features/mesas/ui/widgets/mesas_grid.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MesasPage extends StatefulWidget {
  const MesasPage({super.key});

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  @override
  void initState() {
    final cubit = context.read<MesasCubit>();
    cubit.getMesas();
    super.initState();
  }

  Future<void> _pullRefresh() async {
    final cubit = context.read<MesasCubit>();
    cubit.getMesas();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.watch<MesasCubit>();
    final state = cubit.state;
    final mesas = state.mesas;

    final mesasOcupadas = mesas['mesasOcupadas'];
    final mesasLivres = mesas['mesasLivres'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas'),
      ),
      body: Stack(
        children: [
          if (state is MesaLoadingState) const LinearProgressIndicator(),
          if (state is MesaLoadedState)
            RefreshIndicator(
              onRefresh: _pullRefresh,
              child: Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (mesasOcupadas != null) ...[
                      Text(
                        'Pedidos em andamento ${mesasOcupadas.length}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 10),
                      MesasGrid(mesas: mesasOcupadas),
                      const SizedBox(height: 40),
                    ],
                    if (mesasLivres != null) ...[
                      Text('Mesas livres (${mesasLivres.length})', style: const TextStyle(fontSize: 18)),
                      const SizedBox(height: 10),
                      MesasGrid(mesas: mesasLivres),
                    ],
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}
