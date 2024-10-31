import 'package:app/src/modulos/balcao/paginas/widgets/card_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/pagina_nova_venda_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaBalcao extends StatefulWidget {
  const PaginaBalcao({super.key});

  @override
  State<PaginaBalcao> createState() => _PaginaBalcaoState();
}

class _PaginaBalcaoState extends State<PaginaBalcao> {
  final ProvedorBalcao provedor = Modular.get<ProvedorBalcao>();

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    await provedor.listar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balcão'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return PaginaNovaVendaBalcao(
                aoSalvar: () {},
              );
            },
          ));
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () async => listar(),
            child: Stack(
              children: [
                provedor.listando ? const LinearProgressIndicator() : const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 5, left: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                            mainAxisExtent: 100,
                            mainAxisSpacing: 2,
                            crossAxisSpacing: 2,
                          ),
                          scrollDirection: Axis.vertical,
                          itemCount: provedor.dados.length,
                          padding: const EdgeInsets.only(top: 5, bottom: 10),
                          itemBuilder: (_, index) {
                            var item = provedor.dados[index];

                            return CardVendasBalcao(item: item);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
