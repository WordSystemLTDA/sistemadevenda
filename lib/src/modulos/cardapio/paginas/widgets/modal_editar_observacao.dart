import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ModalEditarObservacao extends StatefulWidget {
  final String idProduto;
  final String observacao;
  final int index;
  final bool? itensRecorrentes;
  const ModalEditarObservacao({
    super.key,
    required this.idProduto,
    required this.observacao,
    required this.index,
    this.itensRecorrentes = false,
  });

  @override
  State<ModalEditarObservacao> createState() => _ModalEditarObservacaoState();
}

class _ModalEditarObservacaoState extends State<ModalEditarObservacao> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorItensRecorrentes provedorItensRecorrentes = Modular.get<ProvedorItensRecorrentes>();

  final TextEditingController _observacoesController = TextEditingController();
  final FocusNode _focus = FocusNode();

  static const List<String> _sugestoes = [
    'Sem cebola',
    'Sem alface',
    'Sem tomate',
    'Sem maionese',
    'Bem passado',
    'Mal passado',
    'Caprichar',
    'Embalar separado',
  ];

  @override
  void initState() {
    super.initState();
    _observacoesController.text = widget.observacao;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _adicionarSugestao(String texto) {
    final atual = _observacoesController.text.trim();
    final novo = atual.isEmpty ? texto : '$atual, $texto';
    _observacoesController.value = TextEditingValue(
      text: novo,
      selection: TextSelection.collapsed(offset: novo.length),
    );
    setState(() {});
  }

  void _salvar() {
    final texto = _observacoesController.text.trim();

    if (widget.itensRecorrentes == true) {
      final item = provedorItensRecorrentes.itensCarrinho[widget.index];
      setState(() {
        item.observacao = texto;
        item.opcoesPacotesListaFinal = _atualizarLista(item.opcoesPacotesListaFinal, texto);
      });
      Navigator.pop(context);
      return;
    }

    final item = carrinhoProvedor.itensCarrinho.listaComandosPedidos[widget.index];
    setState(() {
      item.observacao = texto;
      item.opcoesPacotesListaFinal = _atualizarLista(item.opcoesPacotesListaFinal, texto);
    });
    Navigator.pop(context);
  }

  List<ModeloOpcoesPacotes> _atualizarLista(List<ModeloOpcoesPacotes>? atual, String texto) {
    return [
      ...(atual?.toList() ?? []).where((element) => element.id != 11),
      if (texto.isNotEmpty)
        ModeloOpcoesPacotes(
          id: 11,
          titulo: 'Observação',
          tipo: 7,
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: '0',
              nome: texto,
              foto: '',
              estaSelecionado: false,
              excluir: false,
            ),
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final texto = _observacoesController.text;
    final temTexto = texto.trim().isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.edit_note_rounded, color: cs.onPrimaryContainer, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Observação do item',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: cs.onSurface),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Anote pedidos especiais, preferências ou ajustes.',
                            style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // TextField
                Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: TextField(
                    controller: _observacoesController,
                    focusNode: _focus,
                    maxLines: 5,
                    minLines: 4,
                    maxLength: 200,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: 'Ex.: Sem cebola, ponto bem passado, embalar separado...',
                      hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      counterStyle: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sugestões
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'SUGESTÕES RÁPIDAS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sugestoes
                      .map((s) => InkWell(
                            onTap: () => _adicionarSugestao(s),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 14, color: cs.onSurfaceVariant),
                                  const SizedBox(width: 4),
                                  Text(
                                    s,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 22),
                // Botões
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: temTexto
                            ? () {
                                _observacoesController.clear();
                                setState(() {});
                              }
                            : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: cs.onSurface,
                          side: BorderSide(color: cs.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.zero,
                        ),
                        child: Icon(temTexto ? Icons.cleaning_services_outlined : Icons.close_rounded, size: 20),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: FilledButton.icon(
                          onPressed: _salvar,
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('Salvar observação'),
                          style: FilledButton.styleFrom(
                            backgroundColor: cs.primary,
                            foregroundColor: cs.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                            elevation: 2,
                          ),
                        ),
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
}
