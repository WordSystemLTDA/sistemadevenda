import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/uteis/montagem_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_ingredientes_cardapio.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class EtapaMontagemCardapio extends StatefulWidget {
  final String nomeProduto;
  final String valor;
  final List<ModeloDadosOpcoesPacotes> ingredientes;
  final TextEditingController? pesquisaController;
  final void Function(ModeloDadosOpcoesPacotes, AcaoIngredienteCardapio)
      aoAlterar;
  final void Function(ModeloDadosOpcoesPacotes, bool) aoSeparar;
  final ValueChanged<ModeloDadosOpcoesPacotes> aoTrocar;
  final VoidCallback aoRestaurar;
  final VoidCallback aoVoltar;
  final bool preferenciasTodosDias;

  const EtapaMontagemCardapio({
    super.key,
    required this.nomeProduto,
    required this.valor,
    required this.ingredientes,
    this.pesquisaController,
    required this.aoAlterar,
    required this.aoSeparar,
    required this.aoTrocar,
    required this.aoRestaurar,
    required this.aoVoltar,
    this.preferenciasTodosDias = false,
  });

  @override
  State<EtapaMontagemCardapio> createState() => _EtapaMontagemCardapioState();
}

class _EtapaMontagemCardapioState extends State<EtapaMontagemCardapio> {
  late final TextEditingController _controllerLocal;

  TextEditingController get _pesquisaController =>
      widget.pesquisaController ?? _controllerLocal;

  @override
  void initState() {
    super.initState();
    _controllerLocal = TextEditingController();
    _pesquisaController.addListener(_atualizarPesquisa);
  }

  @override
  void didUpdateWidget(covariant EtapaMontagemCardapio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pesquisaController != widget.pesquisaController) {
      (oldWidget.pesquisaController ?? _controllerLocal)
          .removeListener(_atualizarPesquisa);
      _pesquisaController.addListener(_atualizarPesquisa);
    }
  }

  @override
  void dispose() {
    _pesquisaController.removeListener(_atualizarPesquisa);
    _controllerLocal.dispose();
    super.dispose();
  }

  void _atualizarPesquisa() {
    if (mounted) setState(() {});
  }

  bool _contemPesquisa(ModeloDadosOpcoesPacotes item, String pesquisa) {
    if (pesquisa.isEmpty) return true;
    final nomeOriginal = item.montagemCardapio?.nomeOriginal ?? item.nome;
    final destino = item.montagemCardapio?.destinoNome ?? '';
    return _normalizar(nomeOriginal).contains(pesquisa) ||
        _normalizar(item.nome).contains(pesquisa) ||
        _normalizar(destino).contains(pesquisa) ||
        _normalizar(item.codigo ?? '').contains(pesquisa);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alteracoes = widget.ingredientes
        .where((item) =>
            item.montagemCardapio?.acao != AcaoIngredienteCardapio.normal ||
            item.montagemCardapio?.separado == true)
        .length;
    final resumo = alteracoes == 0
        ? 'Montagem padrão'
        : alteracoes == 1
            ? '1 alteração'
            : '$alteracoes alterações';
    final valorFormatado = (double.tryParse(widget.valor) ?? 0).obterReal();
    final pesquisa = _normalizar(_pesquisaController.text);
    final ingredientesFiltrados = widget.ingredientes
        .where((item) => _contemPesquisa(item, pesquisa))
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CampoBuscaMontagemCardapio(controller: _pesquisaController),
      const SizedBox(height: 10),
      LayoutBuilder(builder: (context, constraints) {
        final compacto = constraints.maxWidth < 520;
        final titulo = Row(children: [
          IconButton(
            tooltip: 'Voltar',
            onPressed: widget.aoVoltar,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 2),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.nomeProduto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.preferenciasTodosDias
                    ? 'Preferências para todos os dias - $valorFormatado'
                    : 'Cardápio do dia - $valorFormatado',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ]),
          ),
          IconButton(
            tooltip: 'Restaurar montagem padrão',
            onPressed: widget.aoRestaurar,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ]);
        final resumoMontagem = Text(
          resumo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: TextStyle(
            color: alteracoes == 0 ? cs.onSurfaceVariant : cs.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        );

        if (compacto) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titulo,
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: resumoMontagem,
                  ),
                ),
              ]);
        }

        return Row(children: [
          Expanded(child: titulo),
          const SizedBox(width: 12),
          SizedBox(width: 180, child: resumoMontagem),
        ]);
      }),
      const SizedBox(height: 12),
      Expanded(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            for (final item in ingredientesFiltrados)
              CardIngredientesCardapio(
                item: item,
                aoAlterar: (acao) => widget.aoAlterar(item, acao),
                aoSeparar: (separado) => widget.aoSeparar(item, separado),
                aoTrocar: () => widget.aoTrocar(item),
                aoRestaurar: () => widget.aoAlterar(
                  item,
                  MontagemCardapio.acaoInicial(item),
                ),
              ),
            if (widget.ingredientes.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.preferenciasTodosDias
                    ? 'Nenhum ingrediente vinculado a este cardápio.'
                    : 'Nenhum ingrediente disponível hoje.'),
              ),
            if (widget.ingredientes.isNotEmpty && ingredientesFiltrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhum ingrediente encontrado.'),
              ),
          ],
        ),
      ),
    ]);
  }
}

class EtapaTrocaCardapio extends StatefulWidget {
  final ModeloDadosOpcoesPacotes item;
  final List<ModeloDadosOpcoesPacotes> ingredientes;
  final List<ModeloDadosOpcoesPacotes> adicionais;
  final ModeloDadosOpcoesPacotes? destinoSelecionado;
  final String? tipoSelecionado;
  final int quantidade;
  final TextEditingController? pesquisaController;
  final VoidCallback aoVoltar;
  final void Function(ModeloDadosOpcoesPacotes item, String tipo) aoSelecionar;
  final ValueChanged<int> aoAlterarQuantidade;

  const EtapaTrocaCardapio({
    super.key,
    required this.item,
    required this.ingredientes,
    required this.adicionais,
    this.destinoSelecionado,
    this.tipoSelecionado,
    required this.quantidade,
    this.pesquisaController,
    required this.aoVoltar,
    required this.aoSelecionar,
    required this.aoAlterarQuantidade,
  });

  @override
  State<EtapaTrocaCardapio> createState() => _EtapaTrocaCardapioState();
}

class _EtapaTrocaCardapioState extends State<EtapaTrocaCardapio> {
  late final TextEditingController _controllerLocal;

  TextEditingController get _pesquisaController =>
      widget.pesquisaController ?? _controllerLocal;

  @override
  void initState() {
    super.initState();
    _controllerLocal = TextEditingController();
    _pesquisaController.addListener(_atualizarPesquisa);
  }

  @override
  void didUpdateWidget(covariant EtapaTrocaCardapio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pesquisaController != widget.pesquisaController) {
      (oldWidget.pesquisaController ?? _controllerLocal)
          .removeListener(_atualizarPesquisa);
      _pesquisaController.addListener(_atualizarPesquisa);
    }
  }

  @override
  void dispose() {
    _pesquisaController.removeListener(_atualizarPesquisa);
    _controllerLocal.dispose();
    super.dispose();
  }

  void _atualizarPesquisa() {
    if (mounted) setState(() {});
  }

  bool _contemPesquisa(ModeloDadosOpcoesPacotes item, String pesquisa) {
    if (pesquisa.isEmpty) return true;
    final nome = item.montagemCardapio?.nomeOriginal ?? item.nome;
    return _normalizar(nome).contains(pesquisa) ||
        _normalizar(item.nome).contains(pesquisa) ||
        _normalizar(item.codigo ?? '').contains(pesquisa);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeOrigem =
        widget.item.montagemCardapio?.nomeOriginal ?? widget.item.nome;
    final opcoesIngredientes = [
      for (final item in widget.ingredientes)
        if (MontagemCardapio.validarTroca(
                widget.ingredientes, widget.item.id, item.id, 'ingrediente') ==
            null)
          (item: item, tipo: 'ingrediente'),
    ];
    final opcoesAdicionais = [
      if (!MontagemCardapio.recebeTroca(widget.ingredientes, widget.item.id))
        for (final item in widget.adicionais) (item: item, tipo: 'adicional'),
    ];
    final pesquisa = _normalizar(_pesquisaController.text);
    final ingredientesFiltrados = opcoesIngredientes
        .where((opcao) => _contemPesquisa(opcao.item, pesquisa))
        .toList();
    final adicionaisFiltrados = opcoesAdicionais
        .where((opcao) => _contemPesquisa(opcao.item, pesquisa))
        .toList();
    final destino = widget.destinoSelecionado;
    final destinoNome = destino == null
        ? 'Selecione uma opção'
        : '${widget.quantidade}x ${destino.montagemCardapio?.nomeOriginal ?? destino.nome}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _CampoBuscaMontagemCardapio(controller: _pesquisaController),
      const SizedBox(height: 10),
      Row(children: [
        IconButton(
          tooltip: 'Voltar',
          onPressed: widget.aoVoltar,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        Icon(Icons.swap_horiz_rounded, size: 20, color: cs.primary),
        const SizedBox(width: 8),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              'Trocar $nomeOrigem',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              'Substituição do cardápio',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ]),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        destinoNome,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: destino == null ? cs.onSurfaceVariant : cs.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (destino != null) ...[
        const SizedBox(height: 8),
        _ControleQuantidadeTrocaCardapio(
          quantidade: widget.quantidade,
          aoAlterarQuantidade: widget.aoAlterarQuantidade,
        ),
      ],
      const SizedBox(height: 12),
      Expanded(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            if (ingredientesFiltrados.isNotEmpty)
              const _TituloSecaoTrocaCardapio('Ingredientes do dia'),
            for (final opcao in ingredientesFiltrados)
              _CardOpcaoTrocaCardapio(
                item: opcao.item,
                tipo: opcao.tipo,
                selecionado: widget.destinoSelecionado?.id == opcao.item.id &&
                    widget.tipoSelecionado == opcao.tipo,
                aoSelecionar: () => widget.aoSelecionar(opcao.item, opcao.tipo),
              ),
            if (adicionaisFiltrados.isNotEmpty)
              const _TituloSecaoTrocaCardapio('Opções dos adicionais'),
            for (final opcao in adicionaisFiltrados)
              _CardOpcaoTrocaCardapio(
                item: opcao.item,
                tipo: opcao.tipo,
                selecionado: widget.destinoSelecionado?.id == opcao.item.id &&
                    widget.tipoSelecionado == opcao.tipo,
                aoSelecionar: () => widget.aoSelecionar(opcao.item, opcao.tipo),
              ),
            if (opcoesIngredientes.isEmpty && opcoesAdicionais.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma troca disponível para este ingrediente.'),
              ),
            if ((opcoesIngredientes.isNotEmpty ||
                    opcoesAdicionais.isNotEmpty) &&
                ingredientesFiltrados.isEmpty &&
                adicionaisFiltrados.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Nenhuma opção encontrada.'),
              ),
          ],
        ),
      ),
    ]);
  }
}

class _ControleQuantidadeTrocaCardapio extends StatelessWidget {
  final int quantidade;
  final ValueChanged<int> aoAlterarQuantidade;

  const _ControleQuantidadeTrocaCardapio({
    required this.quantidade,
    required this.aoAlterarQuantidade,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Expanded(child: Text('Quantidade na troca')),
      IconButton(
        tooltip: 'Diminuir',
        onPressed:
            quantidade > 1 ? () => aoAlterarQuantidade(quantidade - 1) : null,
        icon: const Icon(Icons.remove_circle_outline_rounded),
      ),
      SizedBox(
        width: 32,
        child: Text('$quantidade', textAlign: TextAlign.center),
      ),
      IconButton(
        tooltip: 'Aumentar',
        onPressed:
            quantidade < 99 ? () => aoAlterarQuantidade(quantidade + 1) : null,
        icon: const Icon(Icons.add_circle_outline_rounded),
      ),
    ]);
  }
}

class _TituloSecaoTrocaCardapio extends StatelessWidget {
  final String texto;

  const _TituloSecaoTrocaCardapio(this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Text(
        texto,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _CardOpcaoTrocaCardapio extends StatelessWidget {
  final ModeloDadosOpcoesPacotes item;
  final String tipo;
  final bool selecionado;
  final VoidCallback aoSelecionar;

  const _CardOpcaoTrocaCardapio({
    required this.item,
    required this.tipo,
    required this.selecionado,
    required this.aoSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nome = item.montagemCardapio?.nomeOriginal ?? item.nome;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: VisualAtendimento.superficie(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: selecionado ? cs.primary : cs.outlineVariant,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoSelecionar,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              Icon(
                selecionado
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        tipo == 'ingrediente'
                            ? 'Porção da troca, além da montagem'
                            : 'Substituição sem acréscimo',
                        style:
                            TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CampoBuscaMontagemCardapio extends StatelessWidget {
  final TextEditingController controller;

  const _CampoBuscaMontagemCardapio({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 44,
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar pelo nome ou código',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpar pesquisa',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: VisualAtendimento.superficie(context),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 1.4),
          ),
        ),
      ),
    );
  }
}

String _normalizar(String texto) {
  const acentos = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ç': 'c',
  };
  final buffer = StringBuffer();
  for (final codigo in texto.toLowerCase().runes) {
    final char = String.fromCharCode(codigo);
    buffer.write(acentos[char] ?? char);
  }
  return buffer.toString().trim();
}
