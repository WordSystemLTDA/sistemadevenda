import 'dart:developer' as developer;

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/essencial/widgets/linha_valor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_opcoes_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class PaginaEditarProdutoCarrinho extends StatefulWidget {
  final EdicaoProdutoCarrinho edicao;
  final Future<ModeloConfigBigchef?> Function() carregarConfiguracao;
  final Future<bool> Function(Modelowordprodutos) aoSalvar;

  const PaginaEditarProdutoCarrinho({
    super.key,
    required this.edicao,
    required this.carregarConfiguracao,
    required this.aoSalvar,
  });

  @override
  State<PaginaEditarProdutoCarrinho> createState() =>
      _PaginaEditarProdutoCarrinhoState();
}

class _PaginaEditarProdutoCarrinhoState
    extends State<PaginaEditarProdutoCarrinho> {
  EdicaoProdutoCarrinho get edicao => widget.edicao;
  late final TextEditingController _observacao;
  bool _salvando = false;
  bool _iniciando = false;
  bool _permitirSair = false;
  String? _erroConfiguracao;

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
      final configuracao =
          edicao.pizza ? await widget.carregarConfiguracao() : null;
      if (!mounted) return;
      if (edicao.pizza && configuracao == null) {
        throw StateError('Configuração indisponível.');
      }
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

  Future<void> _abrirEtapa({int? idOpcao}) async {
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
    final erro = edicao.validar();
    if (erro != null) {
      _avisar(erro);
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _salvando = true);
    try {
      final produto = await edicao.concluir();
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
    } catch (_) {
      if (mounted) {
        _avisar(
            'Não foi possível salvar. Confira se o carrinho ainda está aberto e tente novamente.');
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
    edicao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([edicao, edicao.produto]),
      builder: (context, _) {
        final erro = _iniciando ? null : _erroConfiguracao ?? edicao.erro;
        final carregando = _iniciando || edicao.carregando;
        return PopScope(
          canPop: !_salvando && (_permitirSair || !edicao.alterado),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) _confirmarSaida();
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Editar Produto'),
              backgroundColor: cs.inversePrimary,
            ),
            bottomNavigationBar: erro != null || carregando
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LinhaValor(
                            descricao: const Text('Total do item'),
                            valor: Text(edicao.total.obterReal(),
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            key: const Key('salvar_edicao_produto'),
                            onPressed: _salvando ? null : _salvar,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 48),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: _salvando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.check_rounded),
                            label: Text(
                                _salvando ? 'Salvando...' : 'Salvar alterações',
                                textAlign: TextAlign.center),
                          ),
                        ],
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
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            ListTile(
                              leading: Icon(
                                  edicao.pizza
                                      ? Icons.local_pizza_outlined
                                      : Icons.fastfood_outlined,
                                  color: cs.primary),
                              title: Text(
                                  edicao.pizza
                                      ? 'Pizza ${edicao.cardapio.tamanhosPizza!.nomedotamanho}'
                                      : edicao.original.nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                  '${(edicao.original.quantidade ?? 1).toStringAsFixed(0)}x · ${edicao.valorUnitario.obterReal()} cada'),
                            ),
                            const Divider(height: 1),
                            if (edicao.pizza)
                              ExpansionTile(
                                key: const PageStorageKey('editar_sabores'),
                                initiallyExpanded: true,
                                leading: const Icon(Icons.local_pizza_outlined),
                                title: Text(
                                    'Sabores da pizza (${edicao.cardapio.saboresPizzaSelecionados.length})'),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                expandedCrossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  for (final sabor in edicao
                                      .cardapio.saboresPizzaSelecionados)
                                    Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Text(
                                            '${sabor.imprimirCodigoProdutoPreparo == 'Sim' && sabor.codigo.isNotEmpty ? '${sabor.codigo} - ' : ''}(1/${edicao.cardapio.saboresPizzaSelecionados.length}) ${sabor.nome}')),
                                  OutlinedButton.icon(
                                    key: const Key('alterar_sabores_pizza'),
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 18),
                                    label: const Text('Alterar sabores'),
                                    onPressed: () => _abrirEtapa(),
                                  ),
                                ],
                              ),
                            for (final opcao in edicao.opcoes)
                              if ((opcao.dados?.isNotEmpty ?? false) ||
                                  (opcao.produtos?.isNotEmpty ?? false))
                                _secaoOpcoes(opcao),
                            const Divider(height: 1),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: TextField(
                                key: const Key('observacao_edicao_produto'),
                                controller: _observacao,
                                minLines: 2,
                                maxLines: 5,
                                onChanged: (texto) =>
                                    setState(() => edicao.observacao = texto),
                                decoration: const InputDecoration(
                                  labelText: 'Observação',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(),
                                ),
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

  Widget _secaoOpcoes(ModeloOpcoesPacotes opcao) {
    final selecionados =
        edicao.produto.retornarDadosPorID([opcao.id], false, '0');
    final titulo = switch (opcao.id) {
      6 => 'Bordas',
      7 => 'Adicionais',
      8 => 'Itens para retirar',
      _ => opcao.titulo,
    };
    return ListTile(
      key: ValueKey('abrir_edicao_opcao_${opcao.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Icon(switch (opcao.id) {
        6 => Icons.donut_large_outlined,
        8 => Icons.remove_circle_outline,
        _ => Icons.tune,
      }),
      title: Text('$titulo (${selecionados.length})'),
      subtitle: Text(selecionados.isEmpty
          ? 'Nenhum selecionado'
          : selecionados
              .map((d) =>
                  '${opcao.id == 7 ? '${d.quantidade ?? 1}x ' : ''}${d.nome}')
              .join(', ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _abrirEtapa(idOpcao: opcao.id),
    );
  }
}
