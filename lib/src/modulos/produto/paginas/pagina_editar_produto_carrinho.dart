import 'dart:developer' as developer;

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_opcoes_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class PaginaEditarProdutoCarrinho extends StatefulWidget {
  final EdicaoProdutoCarrinho edicao;
  final Future<ModeloConfigBigchef?> Function() carregarConfiguracao;
  final Future<bool> Function(Modelowordprodutos) aoSalvar;
  final bool recorrentes;
  final bool edicaoAposFinalizar;
  final bool mostrarControleQuantidade;

  const PaginaEditarProdutoCarrinho({
    super.key,
    required this.edicao,
    required this.carregarConfiguracao,
    required this.aoSalvar,
    this.recorrentes = false,
    this.edicaoAposFinalizar = false,
    this.mostrarControleQuantidade = false,
  });

  @override
  State<PaginaEditarProdutoCarrinho> createState() =>
      _PaginaEditarProdutoCarrinhoState();
}

class _PaginaEditarProdutoCarrinhoState
    extends State<PaginaEditarProdutoCarrinho> {
  EdicaoProdutoCarrinho get edicao => widget.edicao;
  late final TextEditingController _observacao;
  final _focoObservacao = FocusNode();
  bool _salvando = false;
  bool _iniciando = false;
  bool _permitirSair = false;
  ModeloConfigBigchef? _configuracao;
  String? _erroConfiguracao;

  bool get _usarPermissoesAposFinalizar => widget.edicaoAposFinalizar;

  @override
  void initState() {
    super.initState();
    _observacao = TextEditingController(text: edicao.observacao);
    _carregar();
  }

  Future<void> _carregar() async {
    if (_iniciando) return;
    setState(() {
      _iniciando = true;
      _erroConfiguracao = null;
    });
    try {
      final precisaConfiguracao = edicao.pizza || _usarPermissoesAposFinalizar;
      final configuracao =
          precisaConfiguracao ? await widget.carregarConfiguracao() : null;
      if (!mounted) return;
      if (precisaConfiguracao && configuracao == null) {
        throw StateError('Configuração indisponível.');
      }
      _configuracao = configuracao;
      await edicao.carregar(configuracao: configuracao);
    } catch (error, stackTrace) {
      developer.log('Falha ao iniciar edição do produto.',
          name: 'PaginaEditarProdutoCarrinho',
          error: error,
          stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _erroConfiguracao =
              'Não foi possível carregar as opções do produto. Tente novamente.';
        });
      }
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(mensagem)));
  }

  bool get _permiteEditarObservacao =>
      !_usarPermissoesAposFinalizar ||
      (_configuracao?.permiteEditarObservacaoAposFinalizar ?? false);

  bool get _permiteEditarQuantidade =>
      !_usarPermissoesAposFinalizar ||
      (_configuracao?.permiteEditarQuantidadeAposFinalizar ?? false);

  bool get _permiteEditarSaborPizza =>
      !_usarPermissoesAposFinalizar ||
      (_configuracao?.permiteEditarSaborPizzaAposFinalizar ?? false);

  bool _permiteEditarOpcao(int idOpcao) {
    if (widget.edicaoAposFinalizar) {
      if (!edicao.pizza) return false;
      if (idOpcao != 6 && idOpcao != 7) return false;
    }
    if (!_usarPermissoesAposFinalizar) return true;
    if (idOpcao == 6) {
      return _configuracao?.permiteEditarBordaAposFinalizar ?? false;
    }
    if (idOpcao == 7) {
      return _configuracao?.permiteEditarAdicionalAposFinalizar ?? false;
    }
    return true;
  }

  bool _podeAbrirEtapa(int? idOpcao) =>
      idOpcao == null ? _permiteEditarSaborPizza : _permiteEditarOpcao(idOpcao);

  Future<void> _abrirEtapa({int? idOpcao}) async {
    if (!_podeAbrirEtapa(idOpcao)) {
      _avisar('Edição bloqueada pela configuração do App Garçom.');
      return;
    }
    _focoObservacao.unfocus();
    final rascunho = edicao.criarRascunho();
    final rota = MaterialPageRoute<bool>(
        builder: (_) =>
            PaginaEditarOpcoesCarrinho(rascunho: rascunho, idOpcao: idOpcao));
    try {
      final salvar = await Navigator.of(context).push(rota);
      if (mounted && salvar == true) edicao.aplicarRascunho(rascunho);
      await rota.completed;
    } finally {
      rascunho.dispose();
    }
  }

  Future<void> _salvar() async {
    if (_salvando || _permitirSair) return;
    final erro = edicao.validar(
      validarSaboresPizza: _permiteEditarSaborPizza,
      validarOpcao: _permiteEditarOpcao,
    );
    if (erro != null) {
      _avisar(erro);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _salvando = true);
    try {
      final produto = await edicao.concluir(
        validarSaboresPizza: _permiteEditarSaborPizza,
        validarOpcao: _permiteEditarOpcao,
      );
      final salvo = await widget.aoSalvar(produto);
      if (!mounted) return;
      if (!salvo) throw StateError('Carrinho indisponível.');
      FeedbackUsuario.produtoAdicionado();
      setState(() {
        _salvando = false;
        _permitirSair = true;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, true);
    } catch (erro) {
      if (mounted) {
        _avisar(erro is StateError
            ? erro.message.toString()
            : 'Não foi possível salvar. Confira se o carrinho ainda está aberto e tente novamente.');
        setState(() => _salvando = false);
      }
    }
  }

  Future<void> _confirmarSaida() async {
    if (_salvando) return;
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (!mounted || descartar != true) return;
    setState(() => _permitirSair = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _observacao.dispose();
    _focoObservacao.dispose();
    edicao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alturaTeclado = MediaQuery.viewInsetsOf(context).bottom;
    return ListenableBuilder(
      listenable: Listenable.merge([edicao, edicao.produto, _focoObservacao]),
      builder: (context, _) {
        final erro = _iniciando ? null : _erroConfiguracao ?? edicao.erro;
        final carregando = _iniciando || edicao.carregando;
        final permiteEditarObservacao = _permiteEditarObservacao;
        return PopScope(
          canPop: !_salvando && (_permitirSair || !edicao.alterado),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmarSaida();
          },
          child: Scaffold(
            extendBody: alturaTeclado == 0,
            backgroundColor: VisualAtendimento.fundo(context),
            appBar: AppBar(
              title: const Text('Editar Produto'),
              backgroundColor: cs.inversePrimary,
            ),
            bottomNavigationBar: erro != null || carregando
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding:
                          EdgeInsets.fromLTRB(16, 8, 16, 12 + alturaTeclado),
                      child: TextFieldTapRegion(
                        child: BotaoAcaoPedido(
                          key: const Key('salvar_edicao_produto'),
                          rotulo: 'Salvar alterações',
                          rotuloSemantico:
                              'Salvar alterações. Total do item: ${edicao.total.obterReal()}',
                          iconeRotulo: Icons.check_rounded,
                          total: edicao.total.obterReal(),
                          carregando: _salvando,
                          onPressed: _salvar,
                        ),
                      ),
                    ),
                  ),
            body: erro != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(erro, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                                onPressed: _carregar,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente')),
                          ],
                        )),
                  )
                : carregando
                    ? const Center(child: CircularProgressIndicator())
                    : AbsorbPointer(
                        absorbing: _salvando,
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            bottom: alturaTeclado > 0
                                ? 16
                                : MediaQuery.paddingOf(context).bottom +
                                    MediaQuery.textScalerOf(context).scale(88),
                          ),
                          children: [
                            _resumoProduto(),
                            const SizedBox(height: 12),
                            if (edicao.pizza && _permiteEditarSaborPizza)
                              _secaoSabores(),
                            for (final opcao in edicao.opcoes)
                              if ((opcao.dados?.isNotEmpty ?? false) ||
                                  (opcao.produtos?.isNotEmpty ?? false))
                                if (_permiteEditarOpcao(opcao.id))
                                  _secaoOpcoes(opcao),
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Icon(Icons.edit_note_rounded,
                                        size: 22, color: cs.primary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text('Observação',
                                          style: TextStyle(
                                              color: cs.onSurface,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                  const SizedBox(height: 10),
                                  Semantics(
                                    label: 'Observação do produto',
                                    child: TextField(
                                      key: const Key(
                                          'observacao_edicao_produto'),
                                      controller: _observacao,
                                      focusNode: _focoObservacao,
                                      minLines: 2,
                                      maxLines: 5,
                                      scrollPadding: const EdgeInsets.fromLTRB(
                                          20, 20, 20, 64),
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.done,
                                      onSubmitted: (_) =>
                                          _focoObservacao.unfocus(),
                                      onTapUpOutside: (_) =>
                                          _focoObservacao.unfocus(),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      style: const TextStyle(fontSize: 15),
                                      readOnly: !permiteEditarObservacao,
                                      onChanged: permiteEditarObservacao
                                          ? (texto) => setState(
                                              () => edicao.observacao = texto)
                                          : null,
                                      decoration: InputDecoration(
                                        suffixIcon: _focoObservacao.hasFocus
                                            ? IconButton(
                                                tooltip: 'Fechar teclado',
                                                onPressed:
                                                    _focoObservacao.unfocus,
                                                icon: Icon(
                                                    Icons
                                                        .keyboard_hide_outlined,
                                                    color: cs.primary),
                                              )
                                            : const SizedBox.square(
                                                dimension: 48),
                                        hintText: edicao.pizza
                                            ? 'Ex.: bem assada, cortar em 8'
                                            : 'Ex.: sem cebola, molho à parte',
                                        filled: true,
                                        fillColor: VisualAtendimento.superficie(
                                            context),
                                        contentPadding:
                                            const EdgeInsets.all(14),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                                color: cs.outlineVariant)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        );
      },
    );
  }

  Widget _resumoProduto() {
    final cs = Theme.of(context).colorScheme;
    final quantidade = edicao.original.quantidade ?? 1;
    final textoQuantidade = quantidade == quantidade.roundToDouble()
        ? quantidade.toStringAsFixed(0)
        : quantidade.toString().replaceAll('.', ',');
    final podeEditarQuantidade =
        widget.mostrarControleQuantidade && _permiteEditarQuantidade;
    return ColoredBox(
      color: VisualAtendimento.superficie(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            Row(
              children: [
                _iconeSecao(
                    edicao.pizza
                        ? Icons.local_pizza_outlined
                        : Icons.fastfood_outlined,
                    cs.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        edicao.pizza
                            ? 'Pizza ${edicao.cardapio.tamanhosPizza!.nomedotamanho}'
                            : edicao.original.nome,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                          '$textoQuantidade×  ${edicao.valorUnitario.obterReal()} cada',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            if (podeEditarQuantidade) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text('Quantidade',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton.outlined(
                    tooltip: 'Diminuir quantidade',
                    onPressed: quantidade <= 1
                        ? null
                        : () => edicao.definirQuantidade(quantidade - 1),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      textoQuantidade,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Aumentar quantidade',
                    onPressed: () => edicao.definirQuantidade(quantidade + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconeSecao(IconData icone, Color cor) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icone, size: 23, color: cor),
      );

  Widget _secaoEditavel({
    required Key chave,
    required String titulo,
    required String tooltip,
    required IconData icone,
    required Color cor,
    required List<Widget> resumo,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: VisualAtendimento.superficie(context),
      child: InkWell(
        key: chave,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _iconeSecao(icone, cor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 6),
                      child: Text(titulo,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700)),
                    ),
                    DefaultTextStyle.merge(
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.4),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: resumo),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: tooltip,
                onPressed: onTap,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(48),
                  foregroundColor: cor,
                  backgroundColor: cor.withValues(alpha: 0.10),
                  side: BorderSide(color: cor.withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.edit_outlined, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _secaoSabores() => _secaoEditavel(
        chave: const Key('alterar_sabores_pizza'),
        titulo:
            'Sabores da pizza (${edicao.cardapio.saboresPizzaSelecionados.length})',
        tooltip: 'Alterar tamanho e sabores',
        icone: Icons.local_pizza_outlined,
        cor: VisualAtendimento.azul(context),
        resumo: [
          for (final sabor in edicao.cardapio.saboresPizzaSelecionados)
            Text(
                '${sabor.imprimirCodigoProdutoPreparo == 'Sim' && sabor.codigo.isNotEmpty ? '${sabor.codigo} - ' : ''}(1/${edicao.cardapio.saboresPizzaSelecionados.length}) ${sabor.nome}'),
        ],
        onTap: () => _abrirEtapa(),
      );

  bool _grupoMontagemCardapio(ModeloOpcoesPacotes opcao) {
    if (opcao.tipo == 8) return true;
    final selecionados =
        edicao.produto.retornarDadosPorID([opcao.id], false, '0');
    return selecionados.any((dado) =>
        dado.montagemCardapio != null ||
        ((dado.idCategoriaCardapio ?? '').trim().isNotEmpty &&
            dado.idCategoriaCardapio != '0'));
  }

  Widget _secaoOpcoes(ModeloOpcoesPacotes opcao) {
    final selecionados =
        edicao.produto.retornarDadosPorID([opcao.id], false, '0');
    final titulo = switch (opcao.id) {
      _ when _grupoMontagemCardapio(opcao) => 'Ingredientes do Cardápio',
      6 => 'Bordas',
      7 => 'Adicionais',
      8 => 'Itens para retirar',
      _ => opcao.titulo,
    };
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Divider(height: 1, thickness: 1, color: cs.outlineVariant),
        _secaoEditavel(
          chave: ValueKey('abrir_edicao_opcao_${opcao.id}'),
          titulo: '$titulo (${selecionados.length})',
          tooltip: 'Editar ${titulo.toLowerCase()}',
          icone: switch (opcao.id) {
            _ when _grupoMontagemCardapio(opcao) =>
              Icons.restaurant_menu_rounded,
            6 => Icons.donut_large_outlined,
            8 => Icons.remove_circle_outline,
            _ => Icons.tune,
          },
          cor: switch (opcao.id) {
            7 => VisualAtendimento.verde(context),
            8 => cs.error,
            _ => cs.primary,
          },
          resumo: [
            Text(_grupoMontagemCardapio(opcao)
                ? _resumoMontagem(selecionados)
                : selecionados.isEmpty
                    ? 'Nenhum selecionado'
                    : selecionados
                        .map((d) =>
                            '${opcao.id == 7 ? '${d.quantidade ?? 1}x ' : ''}${d.nome}')
                        .join(', ')),
          ],
          onTap: () => _abrirEtapa(idOpcao: opcao.id),
        ),
      ],
    );
  }

  String _resumoMontagem(List selecionados) {
    final alterados = selecionados.where((dado) {
      final montagem = dado.montagemCardapio;
      return montagem != null &&
          (montagem.acao != AcaoIngredienteCardapio.normal ||
              montagem.separado == true);
    }).toList();
    if (alterados.isEmpty) return 'Montagem padrão';
    return alterados
        .map((dado) => dado.montagemCardapio?.detalheVisualizacao == null
            ? dado.nome
            : '${dado.montagemCardapio!.nomeOriginal}: ${dado.montagemCardapio!.detalheVisualizacao}')
        .join(', ');
  }
}
