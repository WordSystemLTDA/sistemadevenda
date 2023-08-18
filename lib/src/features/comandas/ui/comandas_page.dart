import 'package:app/src/features/comandas/interactor/cubit/comandas_cubit.dart';
import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:app/src/features/comandas/ui/widgets/comandas_grid.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandasPage extends StatefulWidget {
  const ComandasPage({super.key});

  @override
  State<ComandasPage> createState() => _ComandasPageState();
}

class _ComandasPageState extends State<ComandasPage> {
  final ComandasCubit _comandasCubit = Modular.get<ComandasCubit>();

  @override
  void initState() {
    _comandasCubit.getComandas();
    super.initState();
  }

  Future<void> _pullRefresh() async {
    _comandasCubit.getComandas();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ComandasCubit, ComandasState>(
      bloc: _comandasCubit,
      builder: (context, state) {
        final comandas = state.comandas;

        final comandasOcupadas = comandas?.comandasOcupadas;
        final comandasLivres = comandas?.comandasLivres;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Comandas'),
            actions: [
              if (state is ComandaErrorState)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _pullRefresh,
                ),
            ],
          ),
          body: Stack(
            children: [
              if (state is ComandaLoadingState) const LinearProgressIndicator(),
              if (state is ComandaLoadedState)
                Padding(
                  padding: const EdgeInsets.all(30.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (comandasOcupadas != null && comandasOcupadas.isNotEmpty) ...[
                        Text(
                          'Pedidos em andamento (${comandasOcupadas.length})',
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 10),
                        ComandasGrid(comandas: comandasOcupadas),
                        const SizedBox(height: 40),
                      ],
                      if (comandasLivres != null && comandasLivres.isNotEmpty) ...[
                        Text('Comandas livres (${comandasLivres.length})', style: const TextStyle(fontSize: 18)),
                        const SizedBox(height: 10),
                        ComandasGrid(comandas: comandasLivres),
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
