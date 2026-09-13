import 'package:app/src/modulos/cardapio/provedores/observacoes_rapidas.dart';
import 'package:flutter/material.dart';

class SugestoesObservacao extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final int? maxLength;

  const SugestoesObservacao({
    super.key,
    required this.controller,
    this.onChanged,
    this.maxLength,
  });

  @override
  State<SugestoesObservacao> createState() => _SugestoesObservacaoState();
}

class _SugestoesObservacaoState extends State<SugestoesObservacao> {
  final _repositorio = ObservacoesRapidas.doAparelho;
  List<String>? _sugestoes;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _repositorio.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    _repositorio.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _repositorio.listar();
      if (mounted) {
        setState(() {
          _sugestoes = lista;
          _erro = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar as observações.');
      }
    }
  }

  void _adicionar(String texto) {
    final atual = widget.controller.text.trim();
    final novo = atual.isEmpty ? texto : '$atual, $texto';
    if (widget.maxLength != null &&
        novo.characters.length > widget.maxLength!) {
      setState(() =>
          _erro = 'A observação permite até ${widget.maxLength} caracteres.');
      return;
    }
    widget.controller.value = TextEditingValue(
      text: novo,
      selection: TextSelection.collapsed(offset: novo.length),
    );
    widget.onChanged?.call(novo);
    setState(() => _erro = null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.bolt_rounded, size: 20, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Observações rápidas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ))),
          IconButton.filledTonal(
            tooltip: 'Cadastrar observação rápida',
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              _editarObservacao(context);
            },
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Gerenciar observações rápidas',
            onPressed: () {
              FocusManager.instance.primaryFocus?.unfocus();
              showDialog<void>(
                  context: context,
                  builder: (_) => const _GerenciarObservacoes());
            },
            icon: const Icon(Icons.tune_rounded),
          ),
        ]),
        if (_erro != null)
          Row(children: [
            Expanded(child: Text(_erro!, style: TextStyle(color: cs.error))),
            if (_sugestoes == null)
              IconButton(
                  tooltip: 'Tentar novamente',
                  onPressed: _carregar,
                  icon: const Icon(Icons.refresh)),
          ]),
        if (_sugestoes == null && _erro == null)
          const LinearProgressIndicator()
        else if (_sugestoes?.isEmpty == true)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Nenhuma observação cadastrada.'))
        else
          LayoutBuilder(
              builder: (context, constraints) => Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final texto in _sugestoes ?? <String>[])
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: constraints.maxWidth),
                          child: ActionChip(
                            tooltip: texto,
                            avatar: const Icon(Icons.add_rounded, size: 18),
                            label: Text(texto,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            onPressed: () => _adicionar(texto),
                          ),
                        ),
                    ],
                  )),
      ],
    );
  }
}

Future<void> _editarObservacao(BuildContext context, {String? anterior}) =>
    showDialog<void>(
        context: context,
        builder: (_) => _EditarObservacao(anterior: anterior));

class _EditarObservacao extends StatefulWidget {
  final String? anterior;
  const _EditarObservacao({this.anterior});

  @override
  State<_EditarObservacao> createState() => _EditarObservacaoState();
}

class _EditarObservacaoState extends State<_EditarObservacao> {
  late final _controller = TextEditingController(text: widget.anterior);
  bool _salvando = false;
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      await ObservacoesRapidas.doAparelho
          .salvar(_controller.text, anterior: widget.anterior);
      if (mounted) Navigator.pop(context);
    } catch (erro) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = erro is FormatException
              ? erro.message
              : 'Não foi possível salvar neste aparelho. Tente novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_salvando,
        child: AlertDialog(
          scrollable: true,
          title: Text(widget.anterior == null
              ? 'Nova observação rápida'
              : 'Editar observação rápida'),
          content: SizedBox(
            width: 400,
            child: TextField(
              key: const Key('texto_observacao_rapida'),
              controller: _controller,
              autofocus: true,
              enabled: !_salvando,
              minLines: 2,
              maxLines: 4,
              maxLength: ObservacoesRapidas.limiteCaracteres,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _salvar(),
              decoration: InputDecoration(
                  labelText: 'Observação',
                  errorText: _erro,
                  errorMaxLines: 3,
                  border: const OutlineInputBorder()),
            ),
          ),
          actions: [
            TextButton(
                onPressed: _salvando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar')),
            FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.check),
                label: const Text('Salvar')),
          ],
        ),
      );
}

class _GerenciarObservacoes extends StatefulWidget {
  const _GerenciarObservacoes();

  @override
  State<_GerenciarObservacoes> createState() => _GerenciarObservacoesState();
}

class _GerenciarObservacoesState extends State<_GerenciarObservacoes> {
  final _repositorio = ObservacoesRapidas.doAparelho;
  List<String>? _lista;
  String? _erro;
  bool _excluindo = false;

  @override
  void initState() {
    super.initState();
    _repositorio.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    _repositorio.removeListener(_carregar);
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final lista = await _repositorio.listar();
      if (mounted) {
        setState(() {
          _lista = lista;
          _erro = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível carregar as observações.');
      }
    }
  }

  Future<void> _excluir(String texto) async {
    final excluir = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Excluir observação rápida?'),
              content: Text(texto),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Excluir')),
              ],
            ));
    if (!mounted || excluir != true) return;
    setState(() => _excluindo = true);
    try {
      await _repositorio.excluir(texto);
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível excluir. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _excluindo = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: MediaQuery.sizeOf(context).height * 0.8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Observações rápidas',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      Text('Neste aparelho', style: TextStyle(fontSize: 13)),
                    ])),
                IconButton(
                    tooltip: 'Fechar observações rápidas',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ]),
              const SizedBox(height: 8),
              if (_erro != null)
                Text(_erro!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              if (_lista == null)
                _erro == null
                    ? const LinearProgressIndicator()
                    : IconButton(
                        tooltip: 'Tentar novamente',
                        onPressed: _carregar,
                        icon: const Icon(Icons.refresh))
              else if (_lista!.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Nenhuma observação cadastrada.'))
              else
                Flexible(
                    child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _lista!.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final texto = _lista![index];
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Expanded(child: Text(texto)),
                          IconButton(
                              tooltip: 'Editar $texto',
                              onPressed: _excluindo
                                  ? null
                                  : () => _editarObservacao(context,
                                      anterior: texto),
                              icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                              tooltip: 'Excluir $texto',
                              onPressed:
                                  _excluindo ? null : () => _excluir(texto),
                              icon: const Icon(Icons.delete_outline)),
                        ]));
                  },
                )),
              const SizedBox(height: 12),
              FilledButton.icon(
                  onPressed:
                      _excluindo ? null : () => _editarObservacao(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova observação')),
            ]),
          ),
        ),
      );
}
