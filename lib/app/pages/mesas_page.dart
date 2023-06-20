import 'package:app/app/data/blocs/mesas/mesas_bloc.dart';
import 'package:app/app/data/blocs/mesas/mesas_event.dart';
import 'package:app/app/data/blocs/mesas/mesas_state.dart';
import 'package:app/app/widgets/mesas_grid.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MesasPage extends StatefulWidget {
  const MesasPage({super.key});

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  late final MesasBloc _mesasBloc;

  @override
  void initState() {
    _mesasBloc = MesasBloc();
    _mesasBloc.add(GetMesas());
    super.initState();
  }

  Future<void> _pullRefresh() async {
    _mesasBloc.add(GetMesas());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas'),
      ),
      body: RefreshIndicator(
        onRefresh: _pullRefresh,
        child: BlocBuilder<MesasBloc, MesasState>(
          bloc: _mesasBloc,
          builder: (context, state) {
            if (state is MesaLoadingState) {
              return const LinearProgressIndicator();
            } else if (state is MesaLoadedState) {
              final mesasOcupadas = state.mesas['mesasOcupadas'];
              final mesasLivres = state.mesas['mesasLivres'];

              return Padding(
                padding: const EdgeInsets.all(30.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pedidos em andamento (${mesasOcupadas.length})',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    MesasGrid(mesas: mesasOcupadas),
                    const SizedBox(height: 40),
                    Text('Mesas livres (${mesasLivres.length})',
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    MesasGrid(mesas: mesasLivres),
                  ],
                ),
              );
            } else {
              return const Text("Error");
            }
          },
        ),
      ),
    );
  }
}
