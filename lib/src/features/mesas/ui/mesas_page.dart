import 'package:app/src/features/mesas/interactor/cubit/mesas_cubit.dart';
import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';
import 'package:app/src/features/mesas/ui/widgets/mesas_grid.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MesasPage extends StatefulWidget {
  const MesasPage({super.key});

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  final MesasCubit _mesasCubit = Modular.get<MesasCubit>();

  @override
  void initState() {
    _mesasCubit.getMesas();
    super.initState();
  }

  Future<void> _pullRefresh() async {
    _mesasCubit.getMesas();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MesasCubit, MesasState>(
      bloc: _mesasCubit,
      builder: (context, state) {
        final mesas = state.mesas;

        final mesasOcupadas = mesas?.mesasOcupadas;
        final mesasLivres = mesas?.mesasLivres;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mesas'),
            actions: [
              if (state is MesaErrorState)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _pullRefresh,
                ),
            ],
          ),
          body: Stack(
            children: [
              if (state is MesaLoadingState) const LinearProgressIndicator(),
              if (state is MesaLoadedState)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (mesasOcupadas != null && mesasOcupadas.isNotEmpty) ...[
                        Text(
                          'Pedidos em andamento (${mesasOcupadas.length})',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        MesasGrid(mesas: mesasOcupadas),
                        const SizedBox(height: 40),
                      ],
                      if (mesasLivres != null && mesasLivres.isNotEmpty) ...[
                        Text('Mesas livres (${mesasLivres.length})', style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 10),
                        MesasGrid(mesas: mesasLivres),
                      ],
                    ],
                  ),
                )
            ],
          ),
        );
      },
    );
  }
}
