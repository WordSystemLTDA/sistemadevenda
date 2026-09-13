import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/sugestoes_observacao.dart';
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
  final ProvedorItensRecorrentes provedorItensRecorrentes =
      Modular.get<ProvedorItensRecorrentes>();
  final TextEditingController _observacoesController = TextEditingController();
  final FocusNode _focus = FocusNode();
  late final ContextoCarrinho? _contexto;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _contexto = widget.itensRecorrentes == true
        ? provedorItensRecorrentes.contexto
        : carrinhoProvedor.contexto;
    _observacoesController.text = widget.observacao;
  }

  @override
  void dispose() {
    _observacoesController.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    _focus.unfocus();
    final rota = ModalRoute.of(context);
    final texto = _observacoesController.text.trim();
    setState(() => _salvando = true);
    try {
      final recorrente = widget.itensRecorrentes == true;
      final contexto = _contexto;
      final atual = recorrente
          ? provedorItensRecorrentes.contexto
          : carrinhoProvedor.contexto;
      if (contexto == null || atual?.chave != contexto.chave) {
        throw StateError('O atendimento foi alterado.');
      }
      final itens = recorrente
          ? provedorItensRecorrentes.itensCarrinho
          : carrinhoProvedor.itensCarrinho.listaComandosPedidos;
      if (widget.index >= itens.length ||
          itens[widget.index].id != widget.idProduto) {
        throw StateError('O item foi alterado.');
      }
      final item = Modelowordprodutos.fromMap(itens[widget.index].toMap());
      item.observacao = texto;
      item.opcoesPacotesListaFinal =
          _atualizarLista(item.opcoesPacotesListaFinal, texto);
      final salvo = recorrente
          ? await provedorItensRecorrentes.editar(
              contexto.idAtendimento, item, widget.index)
          : await carrinhoProvedor.editar(item, widget.index);
      if (!salvo) throw StateError('Observacao nao salva.');
      if (mounted && rota?.isCurrent == true) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível salvar a observação. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  List<ModeloOpcoesPacotes> _atualizarLista(
      List<ModeloOpcoesPacotes>? atual, String texto) {
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
            )
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: (media.size.height -
                      media.viewInsets.bottom -
                      media.padding.vertical -
                      24)
                  .clamp(0.0, double.infinity)),
          child: Material(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                            child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(2)),
                        )),
                        const SizedBox(height: 12),
                        Row(children: [
                          Icon(Icons.edit_note_rounded, color: cs.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                              child: Text('Observação do item',
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600))),
                          IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                              tooltip: 'Fechar'),
                        ]),
                        const SizedBox(height: 12),
                        ListenableBuilder(
                          listenable: _focus,
                          builder: (context, _) => TextField(
                            controller: _observacoesController,
                            focusNode: _focus,
                            enabled: !_salvando,
                            minLines: 2,
                            maxLines: 4,
                            maxLength: 200,
                            onChanged: (_) => setState(() {}),
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _focus.unfocus(),
                            onTapUpOutside: (_) => _focus.unfocus(),
                            decoration: InputDecoration(
                              hintText: 'Ex.: Sem cebola, ponto bem passado...',
                              filled: true,
                              fillColor: cs.surfaceContainerLow,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              suffixIcon: _focus.hasFocus
                                  ? IconButton(
                                      tooltip: 'Ocultar teclado',
                                      onPressed: _focus.unfocus,
                                      icon: const Icon(
                                          Icons.keyboard_hide_outlined),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        AbsorbPointer(
                          absorbing: _salvando,
                          child: SugestoesObservacao(
                            controller: _observacoesController,
                            maxLength: 200,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: TextFieldTapRegion(
                      child: Row(children: [
                    IconButton.outlined(
                      tooltip: 'Limpar observação',
                      onPressed:
                          _salvando || _observacoesController.text.isEmpty
                              ? null
                              : () {
                                  _observacoesController.clear();
                                  setState(() {});
                                },
                      icon: const Icon(Icons.delete_outline),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: FilledButton.icon(
                      onPressed: _salvando ? null : _salvar,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label:
                          Text(_salvando ? 'Salvando...' : 'Salvar observação'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )),
                  ])),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
