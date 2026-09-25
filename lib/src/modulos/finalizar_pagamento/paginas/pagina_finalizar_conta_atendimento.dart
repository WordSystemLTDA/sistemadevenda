import 'dart:math' as math;

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/dialogo_senha_cancelamento.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/fluxo_finalizacao_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_acrescimos_descontos_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaFinalizarContaAtendimento extends StatefulWidget {
  final String idAtendimento;
  final String idComanda;
  final String idMesa;
  final TipoCardapio tipo;

  const PaginaFinalizarContaAtendimento({
    super.key,
    required this.idAtendimento,
    required this.idComanda,
    required this.idMesa,
    required this.tipo,
  });

  @override
  State<PaginaFinalizarContaAtendimento> createState() =>
      _PaginaFinalizarContaAtendimentoState();
}

class _PaginaFinalizarContaAtendimentoState
    extends State<PaginaFinalizarContaAtendimento> {
  final _servicoCardapio = Modular.get<ServicoCardapio>();
  final Set<String> _selecionados = {};
  final Set<String> _conferidos = {};

  Modeloworddadoscardapio? _dados;
  ModoRecebimentoAtendimento _modo = ModoRecebimentoAtendimento.contaInteira;
  int _quantidadePessoas = 2;
  bool _carregando = true;
  bool _avancando = false;
  bool _cancelandoItem = false;
  String? _erro;

  Server get _server => Modular.get<Server>();
  UsuarioProvedor get _usuario => Modular.get<UsuarioProvedor>();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<bool> _carregar({bool concluirSeFinalizada = false}) async {
    var contaFinalizada = false;
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final atendimento = await _servicoCardapio.listarPorId(
        widget.idAtendimento,
        widget.tipo,
        'Sim',
      );
      if (!mounted) return false;
      if (atendimento.id == null || atendimento.id != widget.idAtendimento) {
        throw StateError('Atendimento não encontrado.');
      }
      if (atendimento.status == 'Finalizada' && concluirSeFinalizada) {
        contaFinalizada = true;
      } else if (!['Andamento', 'Fechamento'].contains(atendimento.status)) {
        throw StateError('Esta conta não está mais aberta para recebimento.');
      }
      if (!contaFinalizada) {
        setState(() {
          _dados = atendimento;
          _quantidadePessoas =
              math.max(2, atendimento.quantidadePessoas ?? _quantidadePessoas);
          _removerChavesInvalidas();
        });
      }
    } catch (erro) {
      if (!mounted) return false;
      setState(() {
        _erro = erro is StateError
            ? erro.message.toString()
            : 'Não foi possível carregar a conta.';
      });
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
    if (contaFinalizada && mounted) Navigator.pop(context, true);
    return contaFinalizada;
  }

  int get _totalCentavos => centavosMonetarios(_dados?.valorTotal);
  int get _pagoCentavos => centavosMonetarios(_dados?.somaValorHistorico);
  int get _saldoCentavos => math.max(0, _totalCentavos - _pagoCentavos);

  String _chaveProduto(Modelowordprodutos produto, int indice) =>
      produto.iditensvenda?.trim().isNotEmpty == true
          ? produto.iditensvenda!
          : '${produto.id}-$indice';

  List<Modelowordprodutos> get _produtosSelecionados {
    final produtos = _dados?.produtos ?? const <Modelowordprodutos>[];
    return [
      for (var indice = 0; indice < produtos.length; indice++)
        if (_selecionados.contains(_chaveProduto(produtos[indice], indice)))
          produtos[indice],
    ];
  }

  int get _valorSugeridoCentavos {
    switch (_modo) {
      case ModoRecebimentoAtendimento.contaInteira:
        return _saldoCentavos;
      case ModoRecebimentoAtendimento.porPessoa:
        return parcelaAtualEmCentavos(
          totalCentavos: _totalCentavos,
          pagoCentavos: _pagoCentavos,
          pessoas: _quantidadePessoas,
        );
      case ModoRecebimentoAtendimento.porProduto:
        return math.min(
          _saldoCentavos,
          totalProdutosSelecionadosEmCentavos(_produtosSelecionados),
        );
    }
  }

  void _removerChavesInvalidas() {
    final validas = <String>{};
    final produtos = _dados?.produtos ?? const <Modelowordprodutos>[];
    for (var indice = 0; indice < produtos.length; indice++) {
      validas.add(_chaveProduto(produtos[indice], indice));
    }
    _selecionados.removeWhere((chave) => !validas.contains(chave));
    _conferidos.removeWhere((chave) => !validas.contains(chave));
  }

  void _alterarModo(ModoRecebimentoAtendimento modo) {
    if (_avancando || _cancelandoItem || modo == _modo) return;
    setState(() {
      _modo = modo;
      if (modo != ModoRecebimentoAtendimento.porProduto) {
        _selecionados.clear();
      }
    });
  }

  void _alterarPessoas(int diferenca) {
    if (_avancando || _cancelandoItem) return;
    setState(() {
      _quantidadePessoas =
          (_quantidadePessoas + diferenca).clamp(2, 99).toInt();
    });
  }

  void _alternarProduto(Modelowordprodutos produto, int indice) {
    if (_avancando ||
        _cancelandoItem ||
        _modo != ModoRecebimentoAtendimento.porProduto ||
        saldoProdutoEmCentavos(produto) <= 0) {
      return;
    }
    final chave = _chaveProduto(produto, indice);
    setState(() {
      if (!_selecionados.add(chave)) _selecionados.remove(chave);
    });
  }

  void _alternarConferencia(Modelowordprodutos produto, int indice) {
    if (_avancando || _cancelandoItem) return;
    final chave = _chaveProduto(produto, indice);
    setState(() {
      if (!_conferidos.add(chave)) _conferidos.remove(chave);
    });
  }

  void _mostrarMensagem(String mensagem, {bool erro = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor: erro ? cs.error : VisualAtendimento.verde(context),
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _adicionarProdutos() async {
    if (_avancando || _cancelandoItem || _dados == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PaginaCardapio(
        tipo: widget.tipo,
        id: widget.idAtendimento,
        idComanda: _dados!.idComanda ?? widget.idComanda,
        idMesa: _dados!.idMesa ?? widget.idMesa,
        idCliente: _dados!.idCliente ?? '0',
        nomeAtendimento: _dados!.nome,
        retornarParaFinalizacao: true,
      ),
    ));
    if (mounted) await _carregar();
  }

  Future<void> _avancar() async {
    if (_avancando || _cancelandoItem || _dados == null) return;
    if (_modo == ModoRecebimentoAtendimento.porProduto &&
        _selecionados.isEmpty) {
      _mostrarMensagem('Selecione pelo menos um produto para receber.',
          erro: true);
      return;
    }
    if (_valorSugeridoCentavos <= 0) {
      _mostrarMensagem('Não há valor disponível para este recebimento.',
          erro: true);
      return;
    }

    final descontoAtual = centavosMonetarios(_dados!.valorDesconto);
    final acrescimoAtual = centavosMonetarios(_dados!.valorAcrescimo);
    final valorBase =
        math.max(0, _totalCentavos - acrescimoAtual + descontoAtual);
    final fluxo = FluxoFinalizacaoAtendimento(
      idAtendimento: widget.idAtendimento,
      idComanda: _dados!.idComanda ?? widget.idComanda,
      idMesa: _dados!.idMesa ?? widget.idMesa,
      idCliente: _dados!.idCliente ?? '0',
      titulo: _dados!.nome ?? widget.tipo.nome,
      tipo: widget.tipo,
      modo: _modo,
      quantidadePessoas: _quantidadePessoas,
      produtosSelecionados: List.unmodifiable(_produtosSelecionados),
      valorBaseCentavos: valorBase,
      valorPagoCentavos: _pagoCentavos,
      valorDescontoCentavos: descontoAtual,
      valorAcrescimoCentavos: acrescimoAtual,
      valorTaxaServico: _dados!.valorTaxaServico ?? '0',
    );

    setState(() => _avancando = true);
    final resultado = await Navigator.of(context)
        .push<ResultadoFluxoAtendimento>(MaterialPageRoute(
      builder: (_) => PaginaAcrescimosDescontosAtendimento(fluxo: fluxo),
    ));
    if (!mounted) return;
    setState(() => _avancando = false);
    if (resultado == ResultadoFluxoAtendimento.finalizou) {
      final impressaoSalva = await _salvarComprovanteFinalizacao();
      if (!mounted) return;
      if (!impressaoSalva) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            icon: Icon(Icons.print_disabled_outlined,
                color: Theme.of(context).colorScheme.error),
            title: const Text('Conta finalizada'),
            content: const Text(
              'O pagamento foi concluído, mas não foi possível salvar o '
              'comprovante de consumo para impressão no caixa.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendi'),
              ),
            ],
          ),
        );
        if (!mounted) return;
      }
      Navigator.pop(context, true);
      return;
    }
    if (resultado != null) {
      _selecionados.clear();
      final finalizada = await _carregar(
        concluirSeFinalizada: resultado == ResultadoFluxoAtendimento.recarregar,
      );
      if (finalizada || !mounted) return;
      if (mounted && _erro == null) {
        _mostrarMensagem(resultado == ResultadoFluxoAtendimento.registrado
            ? 'Pagamento registrado. Confira o saldo atualizado.'
            : 'Conta atualizada. Confira os valores antes de tentar novamente.');
      }
    }
  }

  Future<bool> _salvarComprovanteFinalizacao() async {
    var atendimento = _dados;
    if (atendimento == null) return false;

    try {
      // A releitura final inclui a última forma de pagamento e os valores já
      // confirmados pelo servidor. Se ela falhar, os dados conferidos antes do
      // pagamento ainda permitem emitir o comprovante de consumo.
      atendimento = await _servicoCardapio.listarFinalizadoParaImpressao(
        widget.idAtendimento,
        widget.tipo,
      );
    } catch (_) {
      atendimento = _dados;
    }

    final produtos = atendimento?.produtos ?? const <Modelowordprodutos>[];
    if (atendimento == null || produtos.isEmpty) return false;
    final abertura = DateTime.tryParse(atendimento.dataAbertura ?? '');
    final permanencia = abertura == null
        ? ''
        : ConfigSistema.formatarHora(DateTime.now().difference(abertura));
    final mensagens = Impressao.prepararComprovanteDeConsumo(
      tipoTela: widget.tipo,
      agruparPorDestino: false,
      produtos: produtos,
      nomelancamento: atendimento.nomelancamento ?? const [],
      somaValorHistorico: atendimento.somaValorHistorico ?? '0',
      celularEmpresa: atendimento.celularEmpresa ?? '',
      cnpjEmpresa: atendimento.cnpjEmpresa ?? '',
      enderecoEmpresa: atendimento.enderecoEmpresa ?? '',
      nomeEmpresa: atendimento.nomeEmpresa ?? '',
      numeroPedido: atendimento.numeroPedido ?? '0',
      total: atendimento.valorTotal ?? '0',
      local: widget.tipo == TipoCardapio.mesa
          ? (atendimento.nomeMesa ?? atendimento.nome ?? '')
          : (atendimento.nome ?? ''),
      permanencia: permanencia,
      valorentrega: atendimento.valorentrega ?? '0',
      valortaxadeservico: atendimento.valorTaxaServico ?? '0',
      valordesconto: atendimento.valorDesconto ?? '0',
      valoracrescimo: atendimento.valorAcrescimo ?? '0',
      tipodeentrega: atendimento.tipodeentrega ?? '',
      observacaoDoPedido: atendimento.observacaoDoPedido ?? '',
      comanda: atendimento.nome ?? '',
      nomeCliente: nomeClienteAtendimento(
        atendimento.nomeCliente,
        atendimento.observacaoDoPedido,
      ),
    );
    if (mensagens.isEmpty) return false;

    try {
      // A fila persistente libera a tela sem aguardar a impressora e recupera
      // automaticamente a solicitação se o servidor do caixa estiver offline.
      await _server.enviarImpressoes(mensagens);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _podeExcluirProduto(Modelowordprodutos produto) {
    return !_cancelandoItem &&
        widget.tipo != TipoCardapio.delivery &&
        _dados?.status == 'Andamento' &&
        (produto.iditensvenda ?? '').trim().isNotEmpty &&
        centavosMonetarios(produto.valorPago) <= 0;
  }

  bool _temDestinoConfigurado(Modelowordprodutos produto) {
    final destino = produto.destinoDeImpressao;
    if (destino == null) return false;
    return destino.nomedopc?.trim().isNotEmpty == true ||
        destino.nomeDaImpressora.trim().isNotEmpty ||
        destino.nome.trim().isNotEmpty;
  }

  String _nomeDestinoCancelamento(Modelowordprodutos produto) {
    final destino = produto.destinoDeImpressao;
    if (_temDestinoConfigurado(produto) && destino != null) {
      final nome = destino.nomeDaImpressora.trim().isNotEmpty
          ? destino.nomeDaImpressora.trim()
          : destino.nome.trim();
      return nome.isEmpty ? 'destino do produto' : nome;
    }
    return 'Impressora do Caixa';
  }

  Future<void> _cancelarItem(Modelowordprodutos produto) async {
    final dados = _dados;
    if (_cancelandoItem || dados == null) return;
    if (!_podeExcluirProduto(produto)) {
      _mostrarMensagem('Este item não pode ser excluído agora.', erro: true);
      return;
    }

    final senha = await pedirSenhaCancelamentoItem(
      context: context,
      nomeItem: produto.nome,
      nomeDestino: _nomeDestinoCancelamento(produto),
    );
    if (!mounted || senha == null) return;

    setState(() => _cancelandoItem = true);
    try {
      final resposta = await _servicoCardapio.cancelarItemFinalizado(
        tipo: widget.tipo,
        atendimento: dados,
        produto: produto,
        idMesa: dados.idMesa ?? widget.idMesa,
        idComanda: dados.idComanda ?? widget.idComanda,
        senhaAdmin: senha,
      );
      if (!mounted) return;
      if (!resposta.sucesso) {
        _mostrarMensagem(resposta.mensagem, erro: true);
        return;
      }

      final mensagens = Impressao.prepararCancelamentoDeItem(
        produto: produto,
        destinoCaixa: resposta.destinoCaixa,
        comanda: '${widget.tipo.nome}: ${dados.nome ?? ''}',
        numeroPedido: dados.numeroPedido ?? '0',
        nomeCliente: dados.nomeCliente ?? '',
        nomeEmpresa: dados.nomeEmpresa ?? _usuario.usuario?.nomeEmpresa ?? '',
        tipodeentrega: dados.tipodeentrega ?? '',
        local: widget.tipo == TipoCardapio.mesa
            ? (dados.nomeMesa ?? dados.nome ?? '')
            : (dados.nome ?? ''),
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

      await _carregar();
      if (!mounted) return;
      final mensagem = impressaoEnviada
          ? (resposta.mensagem.isEmpty ? 'Item cancelado.' : resposta.mensagem)
          : 'Item cancelado, mas não foi possível salvar a impressão.';
      _mostrarMensagem(mensagem);
    } catch (_) {
      _mostrarMensagem('Não foi possível cancelar este item.', erro: true);
    } finally {
      if (mounted) setState(() => _cancelandoItem = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: VisualAtendimento.superficie(context),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Finalizar Conta',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            Text('Conferência e tipo de recebimento',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: _corpo(),
      bottomNavigationBar: _dados == null || _erro != null
          ? null
          : _BarraAvancar(
              processando: _avancando || _cancelandoItem,
              valor: valorDosCentavos(_valorSugeridoCentavos),
              onPressed: _avancar,
            ),
    );
  }

  Widget _corpo() {
    if (_carregando && _dados == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, size: 48),
            const SizedBox(height: 12),
            Text(_erro!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ]),
        ),
      );
    }

    final dados = _dados!;
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 124),
        children: [
          _ResumoConta(
            titulo: dados.nome ?? widget.tipo.nome,
            cliente: nomeClienteAtendimento(
                dados.nomeCliente, dados.observacaoDoPedido),
            total: valorDosCentavos(_totalCentavos),
            pago: valorDosCentavos(_pagoCentavos),
            saldo: valorDosCentavos(_saldoCentavos),
          ),
          const SizedBox(height: 18),
          const _TituloSecao(
              icone: Icons.tune_rounded, titulo: 'Como deseja receber?'),
          const SizedBox(height: 10),
          _ModosRecebimento(modo: _modo, onChanged: _alterarModo),
          if (_modo == ModoRecebimentoAtendimento.porPessoa) ...[
            const SizedBox(height: 12),
            _ControlePessoas(
              quantidade: _quantidadePessoas,
              onMenos: () => _alterarPessoas(-1),
              onMais: () => _alterarPessoas(1),
              valorAtual: valorDosCentavos(_valorSugeridoCentavos),
            ),
          ],
          const SizedBox(height: 18),
          OutlinedButton.icon(
            key: const ValueKey('adicionar_produtos_finalizacao'),
            onPressed: _adicionarProdutos,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Adicionar mais produtos',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
          const SizedBox(height: 18),
          _TituloSecao(
            icone: Icons.inventory_2_outlined,
            titulo: _modo == ModoRecebimentoAtendimento.porProduto
                ? 'Selecione os produtos'
                : 'Confira os produtos da conta',
          ),
          const SizedBox(height: 4),
          Text(
            _modo == ModoRecebimentoAtendimento.porProduto
                ? 'Marque os produtos que este cliente deseja pagar.'
                : 'A conferência é opcional e não altera o recebimento.',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          ..._cardsProdutos(),
          if ((dados.nomelancamento ?? []).isNotEmpty) ...[
            const SizedBox(height: 18),
            const _TituloSecao(
                icone: Icons.receipt_long_outlined,
                titulo: 'Movimentos realizados'),
            const SizedBox(height: 8),
            _HistoricoPagamentos(dados: dados),
          ],
        ],
      ),
      if (_carregando || _avancando || _cancelandoItem)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
    ]);
  }

  List<Widget> _cardsProdutos() {
    final produtos = _dados?.produtos ?? const <Modelowordprodutos>[];
    if (produtos.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Nenhum produto lançado nesta conta.'),
        ),
      ];
    }
    return [
      for (var indice = 0; indice < produtos.length; indice++) ...[
        CardProdutoAcompanhar(
          key: ValueKey(
              'produto_finalizacao_${_chaveProduto(produtos[indice], indice)}'),
          item: produtos[indice],
          dados: _dados,
          idComanda: _dados?.idComanda ?? widget.idComanda,
          idComandaPedido: widget.idAtendimento,
          idMesa: _dados?.idMesa ?? widget.idMesa,
          value: '',
          tipo: widget.tipo,
          setarQuantidade: (_) {},
          cabecalhoAdaptavel: true,
          destacado:
              _selecionados.contains(_chaveProduto(produtos[indice], indice)),
          corDestaque:
              _conferidos.contains(_chaveProduto(produtos[indice], indice))
                  ? Color.alphaBlend(
                      VisualAtendimento.verde(context).withValues(alpha: 0.14),
                      Theme.of(context).colorScheme.surface,
                    )
                  : null,
          corBordaDestaque:
              _conferidos.contains(_chaveProduto(produtos[indice], indice))
                  ? VisualAtendimento.verde(context)
                  : null,
          rodape: _ControlesProdutoFinalizacao(
            produto: produtos[indice],
            modoSelecao: _modo == ModoRecebimentoAtendimento.porProduto,
            selecionado:
                _selecionados.contains(_chaveProduto(produtos[indice], indice)),
            conferido:
                _conferidos.contains(_chaveProduto(produtos[indice], indice)),
            podeExcluir: _podeExcluirProduto(produtos[indice]),
            onTap: () => _alternarProduto(produtos[indice], indice),
            onConferir: () => _alternarConferencia(produtos[indice], indice),
            onExcluir: () => _cancelarItem(produtos[indice]),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _ResumoConta extends StatelessWidget {
  final String titulo;
  final String cliente;
  final double total;
  final double pago;
  final double saldo;

  const _ResumoConta({
    required this.titulo,
    required this.cliente,
    required this.total,
    required this.pago,
    required this.saldo,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verde = VisualAtendimento.verde(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          cs.primaryContainer,
          cs.primaryContainer.withValues(alpha: 0.45),
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(Icons.point_of_sale_rounded, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ]),
          ),
        ]),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(child: _ValorResumo(label: 'Total', valor: total)),
          Expanded(child: _ValorResumo(label: 'Recebido', valor: pago)),
        ]),
        const SizedBox(height: 14),
        Divider(color: cs.outlineVariant),
        const SizedBox(height: 8),
        Text('Saldo a receber', style: TextStyle(color: cs.onSurfaceVariant)),
        Text(saldo.obterReal(),
            style: TextStyle(
                color: verde, fontSize: 30, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

class _ValorResumo extends StatelessWidget {
  final String label;
  final double valor;
  const _ValorResumo({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(valor.obterReal(),
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      );
}

class _TituloSecao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  const _TituloSecao({required this.icone, required this.titulo});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ]);
}

class _ModosRecebimento extends StatelessWidget {
  final ModoRecebimentoAtendimento modo;
  final ValueChanged<ModoRecebimentoAtendimento> onChanged;

  const _ModosRecebimento({required this.modo, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final opcoes = [
      (
        ModoRecebimentoAtendimento.contaInteira,
        Icons.payments_outlined,
        'Conta inteira',
        'Receba todo o saldo da conta'
      ),
      (
        ModoRecebimentoAtendimento.porPessoa,
        Icons.groups_2_outlined,
        'Por pessoa',
        'Informe quantas pessoas vão dividir'
      ),
      (
        ModoRecebimentoAtendimento.porProduto,
        Icons.inventory_2_outlined,
        'Por produtos',
        'Escolha os itens deste pagamento'
      ),
    ];
    return Column(children: [
      for (var indice = 0; indice < opcoes.length; indice++) ...[
        _OpcaoModo(
          icone: opcoes[indice].$2,
          titulo: opcoes[indice].$3,
          descricao: opcoes[indice].$4,
          selecionado: modo == opcoes[indice].$1,
          onTap: () => onChanged(opcoes[indice].$1),
        ),
        if (indice < opcoes.length - 1) const SizedBox(height: 10),
      ],
    ]);
  }
}

class _OpcaoModo extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final bool selecionado;
  final VoidCallback onTap;

  const _OpcaoModo({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selecionado ? cs.primaryContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: selecionado ? cs.primary : cs.outlineVariant,
            width: selecionado ? 1.6 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(icone, color: selecionado ? cs.primary : cs.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(descricao,
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  ]),
            ),
            if (selecionado) Icon(Icons.check_circle, color: cs.primary),
          ]),
        ),
      ),
    );
  }
}

class _ControlePessoas extends StatelessWidget {
  final int quantidade;
  final VoidCallback onMenos;
  final VoidCallback onMais;
  final double valorAtual;

  const _ControlePessoas({
    required this.quantidade,
    required this.onMenos,
    required this.onMais,
    required this.valorAtual,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant)),
      child: Row(children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quantidade de pessoas',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Text('Valor por pessoa: ${valorAtual.obterReal()}',
                style: TextStyle(color: cs.primary)),
          ]),
        ),
        IconButton.outlined(
            onPressed: quantidade > 2 ? onMenos : null,
            icon: const Icon(Icons.remove)),
        SizedBox(
          width: 42,
          child: Text('$quantidade',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ),
        IconButton.filled(onPressed: onMais, icon: const Icon(Icons.add)),
      ]),
    );
  }
}

class _ControlesProdutoFinalizacao extends StatelessWidget {
  final Modelowordprodutos produto;
  final bool modoSelecao;
  final bool selecionado;
  final bool conferido;
  final bool podeExcluir;
  final VoidCallback onTap;
  final VoidCallback onConferir;
  final VoidCallback onExcluir;

  const _ControlesProdutoFinalizacao({
    required this.produto,
    required this.modoSelecao,
    required this.selecionado,
    required this.conferido,
    required this.podeExcluir,
    required this.onTap,
    required this.onConferir,
    required this.onExcluir,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final verde = VisualAtendimento.verde(context);
    final pago = saldoProdutoEmCentavos(produto) <= 0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final formato = RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        );
        final acoes = <Widget>[
          if (podeExcluir)
            OutlinedButton.icon(
              key: ValueKey('excluir_${produto.iditensvenda ?? produto.id}'),
              onPressed: onExcluir,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Excluir Item'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                foregroundColor: cs.error,
                side: BorderSide(color: cs.error),
                shape: formato,
              ),
            ),
          OutlinedButton.icon(
            key: ValueKey('conferir_${produto.iditensvenda ?? produto.id}'),
            onPressed: onConferir,
            icon: Icon(conferido
                ? Icons.check_circle_rounded
                : Icons.check_circle_outline_rounded),
            label: Text(conferido ? 'Conferido' : 'Conferir'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: conferido ? verde : cs.primary,
              side: BorderSide(color: conferido ? verde : cs.outlineVariant),
              shape: formato,
            ),
          ),
        ];

        return Column(children: [
          if (modoSelecao) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                key: ValueKey(
                    'selecionar_${produto.iditensvenda ?? produto.id}'),
                onPressed: pago ? null : onTap,
                icon: Icon(pago
                    ? Icons.check_circle_rounded
                    : selecionado
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded),
                label: Text(pago
                    ? 'Pago'
                    : selecionado
                        ? 'Selecionado'
                        : 'Selecionar para pagar'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 46),
                  shape: formato,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          if (acoes.length == 1)
            SizedBox(width: double.infinity, child: acoes.first)
          else
            Row(children: [
              Expanded(child: acoes.first),
              const SizedBox(width: 8),
              Expanded(child: acoes.last),
            ]),
        ]);
      },
    );
  }
}

class _HistoricoPagamentos extends StatelessWidget {
  final Modeloworddadoscardapio dados;
  const _HistoricoPagamentos({required this.dados});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outlineVariant)),
      child: Column(children: [
        for (var indice = 0;
            indice < (dados.nomelancamento ?? []).length;
            indice++) ...[
          ListTile(
            dense: true,
            leading: const Icon(Icons.check_circle_outline_rounded),
            title: Text(dados.nomelancamento![indice].nome),
            trailing: Text(
              numeroMonetario(dados.nomelancamento![indice].valor).obterReal(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (indice < dados.nomelancamento!.length - 1)
            const Divider(height: 1),
        ],
      ]),
    );
  }
}

class _BarraAvancar extends StatelessWidget {
  final bool processando;
  final double valor;
  final VoidCallback onPressed;

  const _BarraAvancar({
    required this.processando,
    required this.valor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant)),
          boxShadow: [
            BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, -4)),
          ],
        ),
        child: FilledButton.icon(
          key: const ValueKey('avancar_finalizacao_atendimento'),
          onPressed: processando || valor <= 0 ? null : onPressed,
          icon: processando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.arrow_forward_rounded),
          label: Text(
            processando ? 'Aguarde...' : 'Avançar • ${valor.obterReal()}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
