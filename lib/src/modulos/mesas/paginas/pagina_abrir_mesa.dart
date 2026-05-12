import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaAbrirMesa extends StatefulWidget {
  final String id;
  final String nome;
  const PaginaAbrirMesa({super.key, required this.id, required this.nome});

  @override
  State<PaginaAbrirMesa> createState() => _PaginaAbrirMesaState();
}

class _PaginaAbrirMesaState extends State<PaginaAbrirMesa> {
  final _clienteSearchController = SearchController();
  final _observacaoController = TextEditingController();

  String _idCliente = '0';
  String _nomeCliente = '';
  bool _salvando = false;

  final ProvedorMesas _state = Modular.get<ProvedorMesas>();

  @override
  void dispose() {
    _clienteSearchController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _abrirMesa() async {
    if (_salvando) return;
    setState(() => _salvando = true);

    final retorno = await _state.inserirMesaOcupada(
      widget.id,
      _idCliente,
      _observacaoController.text,
    );

    if (!mounted) return;
    setState(() => _salvando = false);

    if (retorno.sucesso) {
      Modular.get<ProvedorMesas>().listarMesas('');
      Navigator.pop(context);
      return;
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ocorreu um erro ao abrir a mesa'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: const Text('Abrir mesa', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _abrirMesa,
            icon: _salvando
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              _salvando ? 'Abrindo...' : 'Abrir mesa',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            _HeroMesa(nome: widget.nome),
            const SizedBox(height: 16),
            const _LabelCampo(icone: Icons.person_outline_rounded, texto: 'Cliente', opcional: true),
            const SizedBox(height: 8),
            _SeletorCliente(
              controller: _clienteSearchController,
              listar: _state.listarClientes,
              onSelecionar: (id, nome) {
                setState(() {
                  _idCliente = id;
                  _nomeCliente = nome;
                });
              },
              onLimpar: () {
                setState(() {
                  _idCliente = '0';
                  _nomeCliente = '';
                });
                _clienteSearchController.clear();
              },
              clienteSelecionado: _nomeCliente,
            ),
            const SizedBox(height: 18),
            const _LabelCampo(icone: Icons.notes_rounded, texto: 'Observação', opcional: true),
            const SizedBox(height: 8),
            _CampoObservacao(controller: _observacaoController),
          ],
        ),
      ),
    );
  }
}

class _HeroMesa extends StatelessWidget {
  final String nome;
  const _HeroMesa({required this.nome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.table_bar_outlined, size: 28, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOVA OCUPAÇÃO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelCampo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool opcional;

  const _LabelCampo({required this.icone, required this.texto, this.opcional = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icone, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: 0.1),
        ),
        if (opcional) ...[
          const SizedBox(width: 6),
          Text(
            '(opcional)',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SeletorCliente extends StatelessWidget {
  final SearchController controller;
  final Future<List<dynamic>> Function(String) listar;
  final void Function(String id, String nome) onSelecionar;
  final VoidCallback onLimpar;
  final String clienteSelecionado;

  const _SeletorCliente({
    required this.controller,
    required this.listar,
    required this.onSelecionar,
    required this.onLimpar,
    required this.clienteSelecionado,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temSelecionado = clienteSelecionado.isNotEmpty;

    return SearchAnchor(
      searchController: controller,
      builder: (BuildContext context, SearchController c) {
        return Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => c.openView(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    temSelecionado ? Icons.person_rounded : Icons.search_rounded,
                    size: 20,
                    color: temSelecionado ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      temSelecionado ? clienteSelecionado : 'Selecionar cliente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: temSelecionado ? FontWeight.w600 : FontWeight.w500,
                        color: temSelecionado ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (temSelecionado)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: onLimpar,
                      icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        tooltip: 'Cadastrar cliente',
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const InserirCliente()),
                          );
                          if (result is Map && result['idcliente'] != null) {
                            onSelecionar(
                              result['idcliente'].toString(),
                              (result['nomecliente'] ?? '').toString(),
                            );
                          }
                        },
                        icon: Icon(Icons.person_add_alt_1_rounded, size: 18, color: cs.onPrimaryContainer),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController c) async {
        final keyword = c.value.text;
        final res = await listar(keyword);
        if (res.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Nenhum cliente encontrado',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
                ),
              ),
            ),
          ];
        }
        return [
          ...res.map((e) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    c.closeView(e['nome']);
                    onSelecionar(e['id'].toString(), e['nome'].toString());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_outline_rounded, size: 18, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['nome'].toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${e['id']}',
                                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ];
      },
    );
  }
}

class _CampoObservacao extends StatelessWidget {
  final TextEditingController controller;
  const _CampoObservacao({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: 5,
        minLines: 4,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Ex.: aniversariante, sem cebola, mesa reservada...',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
