import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/badge_valor_oculto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaAcompanharPedido extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;

  const PaginaAcompanharPedido({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    required this.tipo,
  });

  @override
  State<PaginaAcompanharPedido> createState() => _PaginaAcompanharPedidoState();
}

class _PaginaAcompanharPedidoState extends State<PaginaAcompanharPedido>
    with WidgetsBindingObserver {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ServicoConfigBigchef servicoConfigBigchef =
      Modular.get<ServicoConfigBigchef>();
  final Server _server = Modular.get<Server>();
  final UsuarioProvedor _usuario = Modular.get<UsuarioProvedor>();

  Modeloworddadoscardapio? dados;
  ModeloConfigBigchef? _configBigchef;
  bool _carregando = false;
  bool _abrindoEdicao = false;
  bool _cancelandoItem = false;
  final Map<String, Modelowordprodutos> _edicoesLocais = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server.addListener(_aoReceberEventoSocket);
    listarComandasPedidos();
    _carregarConfiguracao();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.removeListener(_aoReceberEventoSocket);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      listarComandasPedidos();
    }
  }

  void _aoReceberEventoSocket() {
    if (!mounted || _carregando) return;
    listarComandasPedidos();
  }

  Future<void> listarComandasPedidos() async {
    if (_carregando) return;
    _carregando = true;
    try {
      final value = await servicoCardapio.listarPorId(
          widget.idComandaPedido ?? '0', widget.tipo, 'Sim');
      if (!mounted) return;
      setState(() {
        dados = _aplicarEdicoesLocais(value);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível atualizar os itens do pedido.')));
    } finally {
      _carregando = false;
    }
  }

  Future<void> _carregarConfiguracao() async {
    final config = await servicoConfigBigchef.listar();
    if (!mounted) return;
    setState(() => _configBigchef = config);
  }

  String get _nomeTipo => widget.tipo.nome;

  IconData get _iconeTipo {
    if (widget.tipo == TipoCardapio.mesa) return Icons.table_restaurant_rounded;
    return Icons.receipt_long_rounded;
  }

  int _totalItens(List<Modelowordprodutos> produtos) {
    var total = 0.0;
    for (final p in produtos) {
      total += (p.quantidade ?? 0);
    }
    return total.toInt();
  }

  double _valorTotal(List<Modelowordprodutos> produtos) {
    var total = 0.0;
    for (final p in produtos) {
      total += (double.tryParse(p.valorVenda) ?? 0) * (p.quantidade ?? 0);
    }
    return total;
  }

  Modeloworddadoscardapio _aplicarEdicoesLocais(
      Modeloworddadoscardapio atendimento) {
    final produtos = atendimento.produtos;
    if (_edicoesLocais.isEmpty || produtos == null || produtos.isEmpty) {
      return atendimento;
    }
    final copia = Modeloworddadoscardapio.fromMap(atendimento.toMap());
    final atualizados = copia.produtos ?? <Modelowordprodutos>[];
    var alterou = false;
    for (var i = 0; i < atualizados.length; i++) {
      final idItem = atualizados[i].iditensvenda ?? '';
      final editado = _edicoesLocais[idItem];
      if (idItem.isEmpty || editado == null) continue;
      atualizados[i] = Modelowordprodutos.fromMap(editado.toMap());
      alterou = true;
    }
    if (alterou) {
      copia.valorTotal = _valorTotal(atualizados).toStringAsFixed(2);
    }
    return copia;
  }

  void _registrarEdicaoLocal(Modelowordprodutos produto) {
    final idItem = produto.iditensvenda ?? '';
    if (idItem.isEmpty || dados == null) return;
    _edicoesLocais[idItem] = Modelowordprodutos.fromMap(produto.toMap());
    if (mounted) {
      setState(() => dados = _aplicarEdicoesLocais(dados!));
    }
  }

  void _removerEdicaoLocal(String idItem) {
    if (idItem.isEmpty) return;
    _edicoesLocais.remove(idItem);
  }

  bool _ehPizza(Modelowordprodutos item) => (item.opcoesPacotesListaFinal ?? [])
      .any((opcao) => opcao.id == 9 || opcao.id == 10);

  bool _podeEditarProduto(Modelowordprodutos item,
      [ModeloConfigBigchef? configuracao]) {
    final config = configuracao ?? _configBigchef;
    if (config == null || dados?.status != 'Andamento') return false;
    if (_ehPizza(item)) {
      return config.permiteEditarQuantidadeAposFinalizar ||
          config.permiteEditarObservacaoAposFinalizar ||
          config.permiteEditarSaborPizzaAposFinalizar ||
          config.permiteEditarBordaAposFinalizar ||
          config.permiteEditarAdicionalAposFinalizar;
    }
    return config.permiteEditarQuantidadeAposFinalizar ||
        config.permiteEditarObservacaoAposFinalizar;
  }

  bool _podeExcluirProduto(Modelowordprodutos item) {
    return !_cancelandoItem &&
        (widget.tipo == TipoCardapio.comanda ||
            widget.tipo == TipoCardapio.mesa) &&
        dados?.status == 'Andamento' &&
        (item.iditensvenda ?? '').isNotEmpty;
  }

  Future<void> _abrirEdicaoProduto(Modelowordprodutos item) async {
    if (_abrindoEdicao || dados == null) return;
    setState(() => _abrindoEdicao = true);
    try {
      final config = _configBigchef ?? await servicoConfigBigchef.listar();
      if (!mounted) return;
      if (config == null || !_podeEditarProduto(item, config)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Edição bloqueada pela configuração do App Garçom.')));
        return;
      }
      final original = Modelowordprodutos.fromMap(item.toMap());
      final edicao = EdicaoProdutoCarrinho(
        item: original,
        servico: Modular.get<ServicoProduto>(),
        categorias: Modular.get<ServicosCategoria>(),
        usuario: _usuario,
      );
      final idMesa = widget.idMesa ?? dados!.idMesa ?? '0';
      final idComanda = widget.idComanda ?? dados!.idComanda ?? '0';
      final idCliente = dados!.idCliente ?? '0';
      final salvo = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaginaEditarProdutoCarrinho(
          edicao: edicao,
          edicaoAposFinalizar: true,
          mostrarControleQuantidade:
              config.permiteEditarQuantidadeAposFinalizar,
          carregarConfiguracao: () async => config,
          aoSalvar: (produto) async {
            final mensagens = Impressao.prepararComprovanteDePedido(
              produtos: [produto],
              comanda: '${widget.tipo.nome}: ${dados!.nome ?? ''}',
              numeroPedido: dados!.numeroPedido ?? '0',
              nomeCliente: dados!.nomeCliente ?? '',
              nomeEmpresa:
                  dados!.nomeEmpresa ?? _usuario.usuario?.nomeEmpresa ?? '',
              tipodeentrega: dados!.tipodeentrega ?? '',
              local: widget.tipo == TipoCardapio.mesa
                  ? (dados!.nomeMesa ?? dados!.nome ?? '')
                  : (dados!.nome ?? ''),
              tipoTela: widget.tipo,
            );
            final resposta = await servicoCardapio.editarProdutoFinalizado(
              tipo: widget.tipo,
              atendimento: dados!,
              produto: produto,
              idMesa: idMesa,
              idComanda: idComanda,
              idCliente: idCliente,
              impressoes: mensagens,
            );
            if (resposta.$1) {
              _registrarEdicaoLocal(produto);
              if (Sincronizador.instancia == null && mensagens.isNotEmpty) {
                await _server.enviarImpressoes(mensagens);
              }
            }
            return resposta.$1;
          },
        ),
      ));
      if (!mounted || salvo != true) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Produto atualizado e enviado para conferência.')));
      await listarComandasPedidos();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Não foi possível editar este produto.')));
      }
    } finally {
      if (mounted) setState(() => _abrindoEdicao = false);
    }
  }

  bool _temDestinoConfigurado(Modelowordprodutos item) {
    final destino = item.destinoDeImpressao;
    if (destino == null) return false;
    return destino.nomedopc?.trim().isNotEmpty == true ||
        destino.nomeDaImpressora.trim().isNotEmpty ||
        destino.nome.trim().isNotEmpty;
  }

  String _nomeDestinoCancelamento(Modelowordprodutos item) {
    final destino = item.destinoDeImpressao;
    if (_temDestinoConfigurado(item) && destino != null) {
      final nome = destino.nomeDaImpressora.trim().isNotEmpty
          ? destino.nomeDaImpressora.trim()
          : destino.nome.trim();
      return nome.isEmpty ? 'destino do produto' : nome;
    }
    return 'Impressora do Caixa';
  }

  Future<String?> _pedirSenhaCancelamento(Modelowordprodutos item) {
    final controller = TextEditingController();
    var erro = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final cs = Theme.of(dialogContext).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              icon: Icon(Icons.delete_outline_rounded, color: cs.error),
              title: const Text('Excluir Item'),
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.nome,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Digite a senha Admin para confirmar o cancelamento.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.errorContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined, color: cs.error, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Será impresso em: ${_nomeDestinoCancelamento(item)}',
                            style: TextStyle(
                              color: cs.onErrorContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Senha Admin',
                      errorText: erro.isEmpty ? null : erro,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) {
                      final senha = controller.text.trim();
                      if (senha.isEmpty) {
                        setDialogState(() => erro = 'Informe a senha Admin.');
                        return;
                      }
                      Navigator.pop(dialogContext, senha);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                FilledButton.icon(
                  onPressed: () {
                    final senha = controller.text.trim();
                    if (senha.isEmpty) {
                      setDialogState(() => erro = 'Informe a senha Admin.');
                      return;
                    }
                    Navigator.pop(dialogContext, senha);
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirmar exclusão'),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.error,
                    foregroundColor: cs.onError,
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  Future<void> _cancelarItemFinalizado(Modelowordprodutos item) async {
    if (_cancelandoItem || dados == null) return;
    if (!_podeExcluirProduto(item)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Este item nao pode ser cancelado agora.')));
      return;
    }

    final senha = await _pedirSenhaCancelamento(item);
    if (!mounted || senha == null) return;

    setState(() => _cancelandoItem = true);
    try {
      final idMesa = widget.idMesa ?? dados!.idMesa ?? '0';
      final idComanda = widget.idComanda ?? dados!.idComanda ?? '0';
      final resposta = await servicoCardapio.cancelarItemFinalizado(
        tipo: widget.tipo,
        atendimento: dados!,
        produto: item,
        idMesa: idMesa,
        idComanda: idComanda,
        senhaAdmin: senha,
      );

      if (!mounted) return;
      if (!resposta.sucesso) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(resposta.mensagem)));
        return;
      }

      final mensagens = Impressao.prepararCancelamentoDeItem(
        produto: item,
        destinoCaixa: resposta.destinoCaixa,
        comanda: '${widget.tipo.nome}: ${dados!.nome ?? ''}',
        numeroPedido: dados!.numeroPedido ?? '0',
        nomeCliente: dados!.nomeCliente ?? '',
        nomeEmpresa: dados!.nomeEmpresa ?? _usuario.usuario?.nomeEmpresa ?? '',
        tipodeentrega: dados!.tipodeentrega ?? '',
        local: widget.tipo == TipoCardapio.mesa
            ? (dados!.nomeMesa ?? dados!.nome ?? '')
            : (dados!.nome ?? ''),
        tipoTela: widget.tipo,
      );
      var impressaoEnviada = true;
      if (mensagens.isNotEmpty) {
        try {
          await _server.enviarImpressoes(mensagens);
        } catch (_) {
          impressaoEnviada = false;
        }
      }

      _removerEdicaoLocal(item.iditensvenda ?? '');
      await listarComandasPedidos();
      if (!mounted) return;
      final mensagem = impressaoEnviada
          ? (resposta.mensagem.isEmpty ? 'Item cancelado.' : resposta.mensagem)
          : 'Item cancelado, mas não foi possível salvar a impressão.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(mensagem)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível cancelar este item.')));
    } finally {
      if (mounted) setState(() => _cancelandoItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (dados == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: _construirAppBar(cs),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final produtos = dados!.produtos ?? <Modelowordprodutos>[];
    final totalItens = _totalItens(produtos);
    final valorTotal = _valorTotal(produtos);

    return Scaffold(
      extendBody: true,
      backgroundColor: cs.surface,
      appBar: _construirAppBar(cs),
      body: RefreshIndicator(
        onRefresh: listarComandasPedidos,
        child: produtos.isEmpty
            ? _EstadoVazio(cs: cs)
            : ListView(
                padding: EdgeInsets.fromLTRB(
                  12,
                  12,
                  12,
                  MediaQuery.paddingOf(context).bottom +
                      MediaQuery.textScalerOf(context).scale(72),
                ),
                children: [
                  _HeroCard(
                    cs: cs,
                    icone: _iconeTipo,
                    rotulo: _nomeTipo.toUpperCase(),
                    titulo: dados!.nome ?? '',
                    subtitulo: dados!.nomeCliente ?? 'Sem cliente',
                    numeroPedido: dados!.numeroPedido,
                  ),
                  const SizedBox(height: 14),
                  _ResumoChips(
                      cs: cs, totalItens: totalItens, valorTotal: valorTotal),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt_rounded,
                            size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'ITENS DO PEDIDO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...produtos.map((item) {
                    return CardProdutoAcompanhar(
                      item: item,
                      dados: dados,
                      idComanda: widget.idComanda ?? '0',
                      idComandaPedido: widget.idComandaPedido ?? '0',
                      idMesa: widget.idMesa ?? '0',
                      setarQuantidade: (increase) {},
                      value: '',
                      tipo: widget.tipo,
                      podeEditar: _podeEditarProduto(item),
                      onEditar: () => _abrirEdicaoProduto(item),
                      podeExcluir: _podeExcluirProduto(item),
                      onExcluir: () => _cancelarItemFinalizado(item),
                    );
                  }),
                ],
              ),
      ),
      bottomNavigationBar: produtos.isEmpty
          ? null
          : _RodapeTotal(
              cs: cs, valorTotal: valorTotal, totalItens: totalItens),
    );
  }

  PreferredSizeWidget _construirAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: cs.inversePrimary,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconeTipo, color: cs.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detalhes da $_nomeTipo',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1),
              ),
              Text(
                'Acompanhamento do pedido',
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: listarComandasPedidos,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ColorScheme cs;
  final IconData icone;
  final String rotulo;
  final String titulo;
  final String subtitulo;
  final String? numeroPedido;

  const _HeroCard({
    required this.cs,
    required this.icone,
    required this.rotulo,
    required this.titulo,
    required this.subtitulo,
    this.numeroPedido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            cs.primaryContainer,
            cs.primaryContainer.withValues(alpha: 0.6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cs.onPrimaryContainer, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      rotulo,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                    if (numeroPedido != null && numeroPedido!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '#$numeroPedido',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 14,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitulo.isEmpty ? 'Sem cliente' : subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoChips extends StatelessWidget {
  final ColorScheme cs;
  final int totalItens;
  final double valorTotal;

  const _ResumoChips(
      {required this.cs, required this.totalItens, required this.valorTotal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Chip(
            cs: cs,
            icone: Icons.shopping_bag_outlined,
            rotulo: 'Itens',
            valor: totalItens.toString(),
          ),
        ),
        if (usuarioProvedor
                .usuario?.configuracoes?.habilitarVerValorTotalNoApp ==
            'Sim') ...[
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: _Chip(
              cs: cs,
              icone: Icons.payments_outlined,
              rotulo: 'Total parcial',
              valor: valorTotal.obterReal(),
              destaque: true,
            ),
          ),
        ]
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final ColorScheme cs;
  final IconData icone;
  final String rotulo;
  final String valor;
  final bool destaque;

  const _Chip({
    required this.cs,
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: destaque ? cs.secondaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icone,
              size: 18,
              color: destaque ? cs.onSecondaryContainer : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: destaque
                        ? cs.onSecondaryContainer.withValues(alpha: 0.85)
                        : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: destaque ? cs.onSecondaryContainer : cs.onSurface,
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

class _RodapeTotal extends StatelessWidget {
  final ColorScheme cs;
  final double valorTotal;
  final int totalItens;

  const _RodapeTotal(
      {required this.cs, required this.valorTotal, required this.totalItens});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_outlined,
                  color: cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total ($totalItens ${totalItens == 1 ? "item" : "itens"})',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                if (usuarioProvedor
                        .usuario?.configuracoes?.habilitarVerValorTotalNoApp ==
                    'Sim') ...[
                  Text(
                    valorTotal.obterReal(),
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: cs.primary,
                        letterSpacing: 0.2),
                  ),
                ] else ...[
                  BadgeValorOculto(
                    compact: false,
                    label: 'Valor total oculto',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final ColorScheme cs;
  const _EstadoVazio({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined,
                size: 52, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Nenhum item lançado',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Os itens aparecerão aqui assim que forem lançados.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
