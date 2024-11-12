import 'package:app/src/modulos/mesas/paginas/widgets/nova_mesa.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
// ignore: depend_on_referenced_packages
import 'package:ndef/ndef.dart' as ndef;

class PaginaListaMesas extends StatefulWidget {
  const PaginaListaMesas({super.key});

  @override
  State<PaginaListaMesas> createState() => PaginaListaMesasState();
}

class PaginaListaMesasState extends State<PaginaListaMesas> {
  final ProvedorMesas _state = Modular.get<ProvedorMesas>();
  bool isLoading = true;
  bool _isNfcAvailable = false;

  final pesquisaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    listar();
  }

  @override
  void dispose() {
    pesquisaController.dispose();
    super.dispose();
  }

  void listar() async {
    setState(() => isLoading = true);
    await _state.listarMesasLista('');
    await initNFC();
    setState(() => isLoading = false);
  }

  Future<void> initNFC() async {
    try {
      final availability = await FlutterNfcKit.nfcAvailability;
      _isNfcAvailable = availability == NFCAvailability.available;
    } catch (e) {
      _isNfcAvailable = false;
    }
  }

  Future<void> escreverCodigoNaTag(String codigo) async {
    FlutterNfcKit.finish();

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiplas TAGS Encontradas!",
        iosAlertMessage: "Escaneie a sua TAG",
        readIso14443A: true,
      );

      if (tag.type == NFCTagType.mifare_ultralight) {
        if (tag.ndefWritable ?? false) {
          await FlutterNfcKit.writeNDEFRecords([
            ndef.TextRecord(encoding: ndef.TextEncoding.UTF8, language: 'pt', text: codigo),
          ]);
          FlutterNfcKit.finish(iosAlertMessage: 'Tag editada com Sucesso.');
        } else {
          FlutterNfcKit.finish(iosErrorMessage: 'Tag não é editavel.');
        }
      } else {
        FlutterNfcKit.finish(iosErrorMessage: 'Tipo de TAG não reconhecido: ${tag.type.name}');
        return;
      }
    } on PlatformException catch (e) {
      FlutterNfcKit.finish(iosErrorMessage: e.details);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mesas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (context) => NovaMesa(
              editar: false,
              aoSalvar: () {},
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, child) {
          final listaMesas = _state.mesasLista;

          return GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: RefreshIndicator(
              onRefresh: () async {
                _state.listarMesasLista('');
                pesquisaController.text = '';
              },
              child: Padding(
                padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
                child: Column(
                  children: [
                    TextField(
                      controller: pesquisaController,
                      onChanged: (value) {
                        _state.listarMesasLista(value);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Pesquisa',
                        contentPadding: EdgeInsets.all(13),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _state.mesasLista.isEmpty
                        ? Expanded(
                            child: ListView(children: const [
                            SizedBox(height: 50),
                            Center(child: Text('Não há Mesas')),
                          ]))
                        : Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: listaMesas.length + 1,
                              itemBuilder: (context, index) {
                                if (listaMesas.length == index) {
                                  return const SizedBox(height: 100, child: Center(child: Text('Fim da Lista de Mesas')));
                                }
                                final item = listaMesas[index];

                                return SizedBox(
                                  height: 100,
                                  child: Card(
                                    child: InkWell(
                                      onTap: () {},
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 5,
                                                clipBehavior: Clip.hardEdge,
                                                decoration: const BoxDecoration(
                                                  borderRadius: BorderRadius.only(
                                                    topLeft: Radius.circular(8),
                                                    bottomLeft: Radius.circular(8),
                                                  ),
                                                ),
                                                child: VerticalDivider(
                                                  color: item.ativo == 'Sim' ? Colors.green : Colors.red,
                                                  thickness: 5,
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(10),
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text('ID: ${item.id}'),
                                                    const SizedBox(height: 10),
                                                    Row(
                                                      children: [
                                                        const Text('Nome: '),
                                                        Text(item.nome),
                                                      ],
                                                    ),
                                                    Row(
                                                      children: [
                                                        const Text('Código: ', style: TextStyle(fontSize: 12)),
                                                        Text(item.codigo.isEmpty ? 'Sem Código' : item.codigo, style: const TextStyle(fontSize: 12)),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: SizedBox(
                                                  width: 50,
                                                  child: InkWell(
                                                      onTap: () async {
                                                        await _state.editarAtivo(item.id, item.ativo == 'Sim' ? 'Não' : 'Sim').then((sucesso) {
                                                          if (context.mounted && !sucesso) {
                                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              const SnackBar(
                                                                content: Text('Ocorreu um erro!'),
                                                                showCloseIcon: true,
                                                              ),
                                                            );
                                                          } else {
                                                            item.ativo = item.ativo == 'Sim' ? 'Não' : 'Sim';
                                                          }
                                                        });
                                                      },
                                                      borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                                      child: item.ativo == 'Sim' ? const Icon(Icons.check_box_outlined) : const Icon(Icons.check_box_outline_blank_rounded)),
                                                ),
                                              ),
                                              Expanded(
                                                child: MenuAnchor(
                                                  builder: (context, controller, child) {
                                                    return SizedBox(
                                                      width: 50,
                                                      child: InkWell(
                                                        onTap: () {
                                                          if (controller.isOpen) {
                                                            controller.close();
                                                          } else {
                                                            controller.open();
                                                          }
                                                        },
                                                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                                                        child: const Icon(Icons.more_vert),
                                                      ),
                                                    );
                                                  },
                                                  menuChildren: [
                                                    MenuItemButton(
                                                      onPressed: () {
                                                        showModalBottomSheet(
                                                          context: context,
                                                          isScrollControlled: true,
                                                          showDragHandle: true,
                                                          builder: (context) => NovaMesa(
                                                            editar: true,
                                                            nome: item.nome,
                                                            codigo: item.codigo,
                                                            id: item.id,
                                                            aoSalvar: () {
                                                              listar();
                                                            },
                                                          ),
                                                        );
                                                      },
                                                      child: const Text('Editar'),
                                                    ),
                                                    if (_isNfcAvailable && item.codigo.isNotEmpty)
                                                      MenuItemButton(
                                                        onPressed: () {
                                                          escreverCodigoNaTag(item.codigo);
                                                        },
                                                        child: const Text('Escrever Código'),
                                                      ),
                                                    MenuItemButton(
                                                      onPressed: () async {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) => Dialog(
                                                            child: ListView(
                                                              padding: const EdgeInsets.all(20),
                                                              shrinkWrap: true,
                                                              children: [
                                                                const Text(
                                                                  'Deseja realmente excluir?',
                                                                  style: TextStyle(fontSize: 20),
                                                                ),
                                                                const SizedBox(height: 15),
                                                                Expanded(
                                                                  child: Row(
                                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                                    children: [
                                                                      TextButton(
                                                                        onPressed: () {
                                                                          Navigator.pop(context);
                                                                        },
                                                                        child: const Text('Cancelar'),
                                                                      ),
                                                                      const SizedBox(width: 10),
                                                                      TextButton(
                                                                        onPressed: () async {
                                                                          await _state.excluirMesa(item.id).then((value) {
                                                                            if (context.mounted) {
                                                                              Navigator.pop(context);
                                                                            }

                                                                            if (context.mounted && !value['sucesso']) {
                                                                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                                              ScaffoldMessenger.of(context).showSnackBar(
                                                                                SnackBar(
                                                                                  content: Text(value['mensagem'] ?? 'Ocorreu um erro!'),
                                                                                  showCloseIcon: true,
                                                                                ),
                                                                              );
                                                                            } else {
                                                                              listar();
                                                                            }
                                                                          });
                                                                        },
                                                                        child: const Text('Excluir'),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: const Text('Excluir'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
