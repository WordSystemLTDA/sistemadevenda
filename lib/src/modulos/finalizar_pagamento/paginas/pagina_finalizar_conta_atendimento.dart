import 'dart:math' as math;

import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/uteis/nome_exibicao_produto.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
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
  final _servicoPagamento = Modular.get<ServicoFinalizarPagamento>();
  final _valorPagamento = TextEditingController();
  final _valorRecebido = TextEditingController();

  Modeloworddadoscardapio? _dados;
  List<BancoPixModelo> _formas = const [];
  final Set<String> _selecionados = {};
  ModoRecebimentoAtendimento _modo = ModoRecebimentoAtendimento.contaInteira;
  int _quantidadePessoas = 2;
  int _pagamentoSelecionado = 1;
  DateTime _vencimento = DateTime.now().add(const Duration(days: 1));
  bool _carregando = true;
  bool _pagando = false;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _valorPagamento.dispose();
    _valorRecebido.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
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
      var formas = <BancoPixModelo>[
        BancoPixModelo(id: '1', nome: 'Dinheiro'),
        BancoPixModelo(id: '2', nome: 'Conta'),
        BancoPixModelo(id: '3', nome: 'Débito'),
        BancoPixModelo(id: '4', nome: 'Crédito'),
      ];
      try {
        final bancos = await _servicoPagamento.listarBancos();
        final adicionais = [
          (5, bancos.ativoBancoPix, bancos.nomeBancoPix),
          (6, bancos.ativoBancoOpcao2, bancos.nomeBancoOpcao2),
          (7, bancos.ativoBancoOpcao3, bancos.nomeBancoOpcao3),
          (8, bancos.ativoBancoOpcao4, bancos.nomeBancoOpcao4),
          (9, bancos.ativoBancoOpcao5, bancos.nomeBancoOpcao5),
        ];
        formas.addAll(adicionais
            .where((item) => item.$2 == 'Sim' && item.$3.trim().isNotEmpty)
            .map((item) =>
                BancoPixModelo(id: '${item.$1}', nome: item.$3.trim())));
      } catch (_) {
        // As quatro formas padrão continuam disponíveis se a consulta falhar.
      }
      if (!mounted) return;
      if (atendimento.id == null || atendimento.id != widget.idAtendimento) {
        throw StateError('Atendimento não encontrado.');
      }
      if (!['Andamento', 'Fechamento'].contains(atendimento.status)) {
        throw StateError('Esta conta não está mais aberta para recebimento.');
      }
      _dados = atendimento;
      _formas = formas;
      _quantidadePessoas = math.max(2, atendimento.quantidadePessoas ?? 2);
      _removerSelecoesInvalidas();
      _sincronizarCamposValor(forcar: true);
    } catch (erro) {
      if (!mounted) return;
      _erro = erro is StateError
          ? erro.message.toString()
          : 'Não foi possível carregar a conta.';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
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

  int get _valorPagamentoCentavos =>
      _modo == ModoRecebimentoAtendimento.contaInteira
          ? math.max(0, centavosMonetarios(_valorPagamento.text))
          : _valorSugeridoCentavos;

  void _sincronizarCamposValor({bool forcar = false}) {
    final texto = _textoValor(_valorSugeridoCentavos);
    if (forcar || _modo != ModoRecebimentoAtendimento.contaInteira) {
      _valorPagamento.text = texto;
    }
    if (forcar || _pagamentoSelecionado == 1) {
      _valorRecebido.text = texto;
    }
  }

  String _textoValor(int centavos) =>
      valorDosCentavos(centavos).toStringAsFixed(2).replaceAll('.', ',');

  void _removerSelecoesInvalidas() {
    final validas = <String>{};
    final produtos = _dados?.produtos ?? const <Modelowordprodutos>[];
    for (var indice = 0; indice < produtos.length; indice++) {
      if (saldoProdutoEmCentavos(produtos[indice]) > 0) {
        validas.add(_chaveProduto(produtos[indice], indice));
      }
    }
    _selecionados.removeWhere((chave) => !validas.contains(chave));
  }

  void _alterarModo(ModoRecebimentoAtendimento modo) {
    if (_pagando || modo == _modo) return;
    setState(() {
      _modo = modo;
      _selecionados.clear();
      _sincronizarCamposValor(forcar: true);
    });
  }

  void _alterarPessoas(int diferenca) {
    if (_pagando) return;
    setState(() {
      _quantidadePessoas =
          (_quantidadePessoas + diferenca).clamp(2, 99).toInt();
      _sincronizarCamposValor(forcar: true);
    });
  }

  void _alternarProduto(Modelowordprodutos produto, int indice) {
    if (_pagando || saldoProdutoEmCentavos(produto) <= 0) return;
    final chave = _chaveProduto(produto, indice);
    setState(() {
      if (!_selecionados.add(chave)) _selecionados.remove(chave);
      _sincronizarCamposValor(forcar: true);
    });
  }

  void _selecionarPagamento(int id) {
    if (_pagando) return;
    if (id == 2 && (_dados?.idCliente ?? '0') == '0') {
      _mostrarMensagem(
        'Vincule um cliente à ${widget.tipo.nome.toLowerCase()} antes de lançar em Conta.',
        erro: true,
      );
      return;
    }
    setState(() {
      _pagamentoSelecionado = id;
      _sincronizarCamposValor(forcar: id == 1);
    });
  }

  Future<void> _escolherVencimento() async {
    final hoje = DateTime.now();
    final primeiraData = DateTime(hoje.year, hoje.month, hoje.day + 1);
    final data = await showDatePicker(
      context: context,
      initialDate:
          _vencimento.isBefore(primeiraData) ? primeiraData : _vencimento,
      firstDate: primeiraData,
      lastDate: DateTime(hoje.year + 5),
      helpText: 'Vencimento da conta',
    );
    if (data != null && mounted) setState(() => _vencimento = data);
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

  Future<void> _receber() async {
    if (_pagando || _dados == null) return;
    final valorCentavos = _valorPagamentoCentavos;
    if (_modo == ModoRecebimentoAtendimento.porProduto &&
        _selecionados.isEmpty) {
      _mostrarMensagem('Selecione pelo menos um produto para receber.',
          erro: true);
      return;
    }
    if (valorCentavos <= 0) {
      _mostrarMensagem('Informe um valor de pagamento maior que zero.',
          erro: true);
      return;
    }
    if (valorCentavos > _saldoCentavos) {
      _mostrarMensagem('O pagamento não pode superar o saldo da conta.',
          erro: true);
      return;
    }

    var valorRecebidoCentavos = valorCentavos;
    var trocoCentavos = 0;
    if (_pagamentoSelecionado == 1) {
      valorRecebidoCentavos = centavosMonetarios(_valorRecebido.text);
      if (valorRecebidoCentavos < valorCentavos) {
        _mostrarMensagem('O valor recebido em dinheiro é insuficiente.',
            erro: true);
        return;
      }
      trocoCentavos = valorRecebidoCentavos - valorCentavos;
    }

    String? forma;
    for (final item in _formas) {
      if (item.id == '$_pagamentoSelecionado') {
        forma = item.nome;
        break;
      }
    }
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_outlined),
        title: const Text('Confirmar recebimento'),
        content: Text(
          '${forma ?? 'Pagamento'} de '
          '${valorDosCentavos(valorCentavos).obterReal()} será lançado nesta conta.'
          '${trocoCentavos > 0 ? '\nTroco: ${valorDosCentavos(trocoCentavos).obterReal()}.' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _pagando = true);
    final resultado = await _servicoPagamento.pagarContaAtendimento(
      id: widget.idAtendimento,
      idComanda: widget.idComanda,
      idMesa: widget.idMesa,
      cliente: _dados!.idCliente ?? '0',
      tipo: widget.tipo,
      valorLancamento: valorDosCentavos(valorRecebidoCentavos),
      valorOriginal: valorDosCentavos(_totalCentavos),
      valorAPagar: valorDosCentavos(valorCentavos),
      troco: valorDosCentavos(trocoCentavos),
      pagamentoSelecionado: _pagamentoSelecionado,
      quantidadePessoas: _modo == ModoRecebimentoAtendimento.porPessoa
          ? _quantidadePessoas
          : 1,
      vencimento: _pagamentoSelecionado == 2 ? _vencimento : DateTime.now(),
      produtosParaFinalizar: _modo == ModoRecebimentoAtendimento.porProduto
          ? _produtosSelecionados
          : const [],
      modoProdutoParcial: _modo == ModoRecebimentoAtendimento.porProduto,
      valorTaxaServico: _dados!.valorTaxaServico ?? '0',
      valorDesconto: _dados!.valorDesconto ?? '0',
      valorAcrescimo: _dados!.valorAcrescimo ?? '0',
    );
    if (!mounted) return;
    setState(() => _pagando = false);
    if (!resultado.sucesso) {
      _mostrarMensagem(resultado.mensagem, erro: true);
      // Se a conexão caiu depois do commit, a releitura mostra o lançamento
      // confirmado e impede que o usuário repita um valor já recebido.
      await _carregar();
      return;
    }
    if (resultado.finalizou) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.check_circle_rounded,
              size: 48, color: VisualAtendimento.verde(context)),
          title: const Text('Conta finalizada'),
          content: Text(
              'O pagamento foi concluído e a ${widget.tipo.nome.toLowerCase()} foi liberada.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Concluir')),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
      return;
    }

    _mostrarMensagem('Pagamento lançado. A conta continua em aberto.');
    _selecionados.clear();
    await _carregar();
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
            Text('Recebimentos e fechamento',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: _corpo(),
      bottomNavigationBar: _dados == null || _erro != null
          ? null
          : _BarraRecebimento(
              pagando: _pagando,
              valor: valorDosCentavos(_valorPagamentoCentavos),
              onPressed: _receber,
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
          if (_modo == ModoRecebimentoAtendimento.porProduto) ...[
            const SizedBox(height: 18),
            const _TituloSecao(
                icone: Icons.inventory_2_outlined,
                titulo: 'Selecione os produtos'),
            const SizedBox(height: 8),
            ..._cardsProdutos(),
          ],
          const SizedBox(height: 18),
          const _TituloSecao(
              icone: Icons.account_balance_wallet_outlined,
              titulo: 'Forma de pagamento'),
          const SizedBox(height: 10),
          _FormasPagamento(
            formas: _formas,
            selecionado: _pagamentoSelecionado,
            onChanged: _selecionarPagamento,
          ),
          if (_modo == ModoRecebimentoAtendimento.contaInteira) ...[
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('valor_pagamento_conta'),
              controller: _valorPagamento,
              enabled: !_pagando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor deste pagamento',
                prefixText: 'R\$ ',
                helperText: 'Você pode receber a conta em mais de uma forma.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {
                  if (_pagamentoSelecionado == 1) {
                    _valorRecebido.text = _valorPagamento.text;
                  }
                });
              },
            ),
          ],
          if (_pagamentoSelecionado == 1) ...[
            const SizedBox(height: 14),
            TextField(
              key: const ValueKey('valor_recebido_dinheiro'),
              controller: _valorRecebido,
              enabled: !_pagando,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Valor recebido em dinheiro',
                prefixText: 'R\$ ',
                helperText: _trocoCentavos > 0
                    ? 'Troco: ${valorDosCentavos(_trocoCentavos).obterReal()}'
                    : 'Informe um valor maior para calcular o troco.',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
          if (_pagamentoSelecionado == 2) ...[
            const SizedBox(height: 14),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant)),
              leading: const Icon(Icons.event_outlined),
              title: const Text('Vencimento da conta'),
              subtitle: Text(
                '${_vencimento.day.toString().padLeft(2, '0')}/'
                '${_vencimento.month.toString().padLeft(2, '0')}/'
                '${_vencimento.year}',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _escolherVencimento,
            ),
          ],
          if ((dados.nomelancamento ?? []).isNotEmpty) ...[
            const SizedBox(height: 22),
            const _TituloSecao(
                icone: Icons.receipt_long_outlined,
                titulo: 'Movimentos realizados'),
            const SizedBox(height: 8),
            _HistoricoPagamentos(dados: dados),
          ],
        ],
      ),
      if (_carregando || _pagando)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.25),
            child: const Center(child: CircularProgressIndicator()),
          ),
        ),
    ]);
  }

  int get _trocoCentavos => math.max(
      0, centavosMonetarios(_valorRecebido.text) - _valorPagamentoCentavos);

  List<Widget> _cardsProdutos() {
    final produtos = _dados?.produtos ?? const <Modelowordprodutos>[];
    if (produtos.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text('Nenhum produto disponível para recebimento.'),
        ),
      ];
    }
    return [
      for (var indice = 0; indice < produtos.length; indice++) ...[
        _CardProdutoPagamento(
          produto: produtos[indice],
          selecionado:
              _selecionados.contains(_chaveProduto(produtos[indice], indice)),
          onTap: () => _alternarProduto(produtos[indice], indice),
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
        'Receba tudo ou informe uma parte'
      ),
      (
        ModoRecebimentoAtendimento.porPessoa,
        Icons.groups_2_outlined,
        'Por pessoa',
        'Divide sem perder centavos'
      ),
      (
        ModoRecebimentoAtendimento.porProduto,
        Icons.inventory_2_outlined,
        'Por produtos',
        'Escolha os itens deste pagamento'
      ),
    ];
    return LayoutBuilder(builder: (context, limites) {
      final largura = limites.maxWidth >= 720
          ? (limites.maxWidth - 20) / 3
          : limites.maxWidth;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final opcao in opcoes)
            SizedBox(
              width: largura,
              child: _OpcaoModo(
                icone: opcao.$2,
                titulo: opcao.$3,
                descricao: opcao.$4,
                selecionado: modo == opcao.$1,
                onTap: () => onChanged(opcao.$1),
              ),
            ),
        ],
      );
    });
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
            Text('Cota atual: ${valorAtual.obterReal()}',
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

class _FormasPagamento extends StatelessWidget {
  final List<BancoPixModelo> formas;
  final int selecionado;
  final ValueChanged<int> onChanged;

  const _FormasPagamento({
    required this.formas,
    required this.selecionado,
    required this.onChanged,
  });

  IconData _icone(int id) => switch (id) {
        1 => Icons.payments_outlined,
        2 => Icons.event_note_outlined,
        3 => Icons.credit_card_outlined,
        4 => Icons.credit_score_outlined,
        _ => Icons.qr_code_2_rounded,
      };

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final forma in formas)
            ChoiceChip(
              avatar: Icon(_icone(int.tryParse(forma.id) ?? 0), size: 18),
              label: Text(forma.nome),
              selected: selecionado == int.tryParse(forma.id),
              onSelected: (_) => onChanged(int.tryParse(forma.id) ?? 1),
            ),
        ],
      );
}

class _CardProdutoPagamento extends StatelessWidget {
  final Modelowordprodutos produto;
  final bool selecionado;
  final VoidCallback onTap;

  const _CardProdutoPagamento({
    required this.produto,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saldo = saldoProdutoEmCentavos(produto);
    final pago = saldo <= 0;
    return Material(
      color: selecionado ? cs.primaryContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: selecionado ? cs.primary : cs.outlineVariant,
            width: selecionado ? 1.5 : 1),
      ),
      child: InkWell(
        onTap: pago ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(
              pago
                  ? Icons.check_circle_rounded
                  : selecionado
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
              color: pago
                  ? VisualAtendimento.verde(context)
                  : selecionado
                      ? cs.primary
                      : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomeExibicaoProduto(produto),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${produto.quantidade ?? 1} un. • Código ${produto.codigo}',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ]),
            ),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(valorDosCentavos(saldo).obterReal(),
                  style: TextStyle(
                      color: pago ? cs.onSurfaceVariant : cs.primary,
                      fontWeight: FontWeight.w800)),
              if (pago)
                Text('Pago',
                    style: TextStyle(
                        fontSize: 12, color: VisualAtendimento.verde(context))),
            ]),
          ]),
        ),
      ),
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

class _BarraRecebimento extends StatelessWidget {
  final bool pagando;
  final double valor;
  final VoidCallback onPressed;

  const _BarraRecebimento({
    required this.pagando,
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
          key: const ValueKey('confirmar_pagamento_conta'),
          onPressed: pagando || valor <= 0 ? null : onPressed,
          icon: pagando
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.verified_outlined),
          label: Text(
            pagando ? 'Confirmando...' : 'Receber ${valor.obterReal()}',
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
