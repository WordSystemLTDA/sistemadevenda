import 'package:app/src/modulos/balcao/modelos/modelo_enderecos_clientes.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaNovaVendaBalcao extends StatefulWidget {
  final Function() aoSalvar;

  const PaginaNovaVendaBalcao({
    super.key,
    required this.aoSalvar,
  });

  @override
  State<PaginaNovaVendaBalcao> createState() => _PaginaNovaVendaBalcaoState();
}

class _PaginaNovaVendaBalcaoState extends State<PaginaNovaVendaBalcao> {
  final ProvedorBalcao provedor = Modular.get<ProvedorBalcao>();

  final TextEditingController obsController = TextEditingController();
  final TextEditingController clienteController = TextEditingController(text: '');
  final TextEditingController enderecoController = TextEditingController(text: '');

  String idCliente = '0';
  String idEnderecoCliente = '0';
  String tipoentrega = '3';

  @override
  void initState() {
    super.initState();
    // listarDados();
  }

  @override
  void dispose() {
    obsController.dispose();
    clienteController.dispose();
    enderecoController.dispose();
    super.dispose();
  }

  bool verificarAbrirComanda() {
    if (idCliente.isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    double width = 1000;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.add_shopping_cart_rounded, size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Nova Venda Balcão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: cs.primary.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => abrir(),
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'Abrir Cardápio',
                      style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: 0.3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          child: LayoutBuilder(
            builder: (context, constraints) => ListView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelSecao(context, Icons.person_outline_rounded, 'Cliente'),
                    SearchAnchor(
                      builder: (BuildContext context, SearchController controller) {
                        return TextField(
                          controller: clienteController,
                          readOnly: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: _decoracaoCampo(
                            context,
                            hint: 'Selecione o Cliente',
                            prefixIcon: Icons.person_search_rounded,
                            sufixo: IconButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return const InserirCliente();
                                  },
                                ));
                              },
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              splashRadius: 20,
                            ),
                          ),
                          onTap: () => controller.openView(),
                        );
                      },
                      suggestionsBuilder: (BuildContext context, SearchController controller) async {
                        final keyword = controller.value.text;
                        final res = await provedor.listarClientes(keyword);
                        return [
                          ...res.map(
                            (e) => Card(
                              elevation: 3.0,
                              margin: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () async {
                                  controller.closeView('');
                                  clienteController.text = e['nome'];
                                  idCliente = e['id'];

                                  List<Modelowordenderecosclientes>? enderecos = await provedor.listarEnderecosClientes('', idCliente);

                                  if (enderecos.where((element) => element.padrao == 'Sim').isNotEmpty) {
                                    var end = enderecos.where((element) => element.padrao == 'Sim').first;
                                    enderecoController.text = "${end.endereco} ${end.bairro.isNotEmpty ? "- ${end.bairro} -" : ''} ${end.numero}";
                                    idEnderecoCliente = end.id;
                                  } else {
                                    enderecoController.text = 'Sem Endereço';
                                  }
                                  setState(() {});
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: ListTile(
                                  leading: const Icon(Icons.person_2_outlined),
                                  title: Text(e['nome']),
                                  subtitle: Text('ID: ${e['id']}'),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelSecao(context, Icons.location_on_outlined, 'Endereço de Entrega'),
                    SearchAnchor(
                      builder: (BuildContext context, SearchController controller) {
                        return TextField(
                          controller: enderecoController,
                          readOnly: true,
                          style: const TextStyle(fontSize: 14),
                          decoration: _decoracaoCampo(
                            context,
                            hint: 'Selecione um Endereço',
                            prefixIcon: Icons.location_on_outlined,
                            sufixo: IconButton(
                              onPressed: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return const InserirCliente();
                                  },
                                ));
                              },
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                              splashRadius: 20,
                            ),
                          ),
                          onTap: () => controller.openView(),
                        );
                      },
                      suggestionsBuilder: (BuildContext context, SearchController controller) async {
                        final keyword = controller.value.text;
                        final res = await provedor.listarEnderecosClientes(keyword, idCliente);
                        return [
                          ...res.map(
                            (e) => Card(
                              elevation: 3.0,
                              margin: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () {
                                  controller.closeView('');
                                  var endereco = e;

                                  enderecoController.text = "${endereco.endereco} ${endereco.bairro.isNotEmpty ? "- ${endereco.bairro} -" : '-'} ${endereco.numero}";
                                  idEnderecoCliente = endereco.id;
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: ListTile(
                                  leading: const Icon(Icons.person_2_outlined),
                                  title: Text("${e.endereco} ${e.bairro.isNotEmpty ? "- ${e.bairro} -" : '-'} ${e.numero}"),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelSecao(context, Icons.delivery_dining_outlined, 'Tipo de Entrega'),
                    DropdownMenu(
                      width: (constraints.maxWidth),
                      hintText: 'Selecione um Tipo de Entrega',
                      initialSelection: tipoentrega,
                      textStyle: const TextStyle(fontSize: 14),
                      inputDecorationTheme: InputDecorationTheme(
                        isDense: true,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: cs.primary, width: 1.4),
                        ),
                      ),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: '3', label: 'Consumir no Local'),
                        DropdownMenuEntry(value: '2', label: 'Retirar no Balcão'),
                      ],
                      onSelected: (value) {
                        if (value != null) {
                          tipoentrega = value;
                        } else {
                          tipoentrega = '0';
                        }
                      },
                      // titulo: const Text('Tipo de Entrega'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabelSecao(context, Icons.sticky_note_2_outlined, 'Observação'),
                    TextField(
                      controller: obsController,
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                      decoration: _decoracaoCampo(
                        context,
                        hint: 'Adicione uma observação para o pedido...',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabelSecao(BuildContext context, IconData icone, String texto) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Icon(icone, size: 18, color: cs.primary),
          const SizedBox(width: 8),
          Text(
            texto,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoracaoCampo(
    BuildContext context, {
    String? hint,
    IconData? prefixIcon,
    Widget? sufixo,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13.5, color: cs.onSurface.withValues(alpha: 0.5)),
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: cs.onSurface.withValues(alpha: 0.6)) : null,
      suffixIcon: sufixo,
      filled: true,
      fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
    );
  }

  void abrir() async {
    provedor.observacaoDoPedido = obsController.text;

    Navigator.push(context, MaterialPageRoute(
      builder: (context) {
        return PaginaCardapio(
          tipo: TipoCardapio.balcao,
          idCliente: idCliente,
          tipodeentrega: tipoentrega,
        );
      },
    ));
  }
}
