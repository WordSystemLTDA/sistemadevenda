import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:flutter_modular/flutter_modular.dart';

Future<bool?> receberDelivery(
        BuildContext context, ServicoDelivery servico, String id,
        {bool confirmarRecorrente = false}) =>
    showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PagamentoDelivery(
            servico: servico,
            id: id,
            confirmarRecorrente: confirmarRecorrente));

class _PagamentoDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  final String id;
  final bool confirmarRecorrente;
  const _PagamentoDelivery(
      {required this.servico,
      required this.id,
      this.confirmarRecorrente = false});
  @override
  State<_PagamentoDelivery> createState() => _PagamentoDeliveryState();
}

class _PagamentoDeliveryState extends State<_PagamentoDelivery> {
  final _valor = TextEditingController();
  PedidoDelivery? _pedido;
  PagamentoRecorrente? _recorrencia;
  final _chavePagamento = ServicosRecorrentes.novaChave();
  Map<int, String> _formas = {
    1: 'Dinheiro',
    3: 'Cartão de débito',
    4: 'Cartão de crédito'
  };
  int _forma = 1;
  bool _carregando = true, _salvando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _valor.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _erro = null;
      _carregando = true;
    });
    try {
      final pedido = await widget.servico.pedido(widget.id);
      final recorrencia = await widget.servico.pagamentoRecorrente(widget.id);
      final bancos =
          await widget.servico.consultar('tela_nfe_saida/listar_bancos.php', {
        'id_empresa': widget.servico.usuario.usuario?.empresa,
      });
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _recorrencia = recorrencia;
        _valor.text = pedido.restante.toStringAsFixed(2).replaceAll('.', ',');
        _formas = {
          1: 'Dinheiro',
          if (recorrencia != null) 2: 'Em conta',
          3: 'Cartão de débito',
          4: 'Cartão de crédito',
          if (bancos['ativoBancoPix'] == 'Sim')
            5: '${bancos['nomeBancoPix'] ?? 'Pix'}',
          for (var i = 2; i <= 5; i++)
            if (bancos['ativoBancoOpcao$i'] == 'Sim')
              i + 4: '${bancos['nomeBancoOpcao$i']}',
        };
        if (recorrencia?.mensal == true) {
          _forma = 2;
        } else if (recorrencia?.definida == true &&
            _formas.containsKey(recorrencia!.forma)) {
          _forma = recorrencia.forma;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _erro = 'Não foi possível consultar o pagamento.');
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _salvar() async {
    if (_salvando || _pedido == null) return;
    final valor = valorDelivery(_valor.text);
    if (valor <= 0 || !valor.isFinite) {
      setState(() => _erro = 'Informe um valor válido.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      final atual = await widget.servico.pedido(widget.id);
      if ((atual.restante - _pedido!.restante).abs() > .009 ||
          atual.encerrado) {
        throw StateError(
            'O saldo do pedido mudou. Feche e abra o pagamento novamente.');
      }
      final vencimento = _recorrencia?.vencimento;
      final resposta = await widget.servico.pagar(atual, _forma, valor,
          chavePagamento: _chavePagamento,
          confirmarRecorrente: widget.confirmarRecorrente,
          dataLancamento: vencimento == null
              ? null
              : DateFormat('yyyy-MM-dd').format(vencimento),
          parcelasLista: _forma == 2 && vencimento != null
              ? [
                  ParcelasModelo(
                      parcela: '1',
                      valor: valor.toStringAsFixed(2),
                      vencimento: DateFormat('yyyy-MM-dd').format(vencimento))
                ]
              : const []);
      final preparo = resposta['preparoRecorrente'];
      if (preparo is Map &&
          preparo['enviar'] == true &&
          '${preparo['chave'] ?? ''}'.isNotEmpty) {
        final server = Modular.get<Server>();
        try {
          final configuracao = await widget.servico.configuracao();
          if (configuracao.imprimirPreparo) {
            await ImpressaoDelivery.imprimir(widget.servico, server, atual,
                preparo: true,
                config: configuracao,
                chaveRecorrente: '${preparo['chave']}');
          }
        } catch (erro) {
          server.avisarFalhaImpressao(erro);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is StateError
            ? e.message.toString()
            : 'Pagamento sem confirmação. Confira os lançamentos antes de tentar novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pedido = _pedido;
    final troco = pedido != null && _forma == 1
        ? valorDelivery(_valor.text) - pedido.restante
        : 0.0;
    return PopScope(
        canPop: !_salvando,
        child: AlertDialog(
          scrollable: true,
          title: const Text('Receber pagamento'),
          content: SizedBox(
              width: 420,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_carregando) const LinearProgressIndicator(),
                    if (pedido != null) ...[
                      Text('Pedido #${pedido.numero} · ${pedido.nome}'),
                      const SizedBox(height: 12),
                      Text('Total ${pedido.total.obterReal()}'),
                      Text('Recebido ${pedido.pago.obterReal()}'),
                      const SizedBox(height: 8),
                      Text('A receber ${pedido.restante.obterReal()}',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 20),
                      if (_recorrencia != null) ...[
                        Text(_recorrencia!.resumo),
                        if (_recorrencia!.vencimento != null && _forma == 2)
                          Text(
                              'Vencimento: ${DateFormat('dd/MM/yyyy').format(_recorrencia!.vencimento!)}'),
                        const SizedBox(height: 12),
                      ],
                      DropdownButtonFormField<int>(
                          initialValue: _forma,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Forma de pagamento',
                              border: OutlineInputBorder()),
                          items: [
                            for (final f in _formas.entries)
                              DropdownMenuItem(
                                  value: f.key, child: Text(f.value))
                          ],
                          onChanged: _salvando || _recorrencia?.mensal == true
                              ? null
                              : (v) => setState(() => _forma = v!)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _valor,
                          enabled: !_salvando,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          decoration: InputDecoration(
                              labelText: _forma == 2
                                  ? 'Valor em conta'
                                  : 'Valor recebido',
                              prefixText: 'R\$ ',
                              border: OutlineInputBorder())),
                      if (troco > .009)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text('Troco ${troco.obterReal()}')),
                    ],
                    if (_erro != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_erro!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))),
                    if (_erro != null && pedido == null)
                      TextButton.icon(
                          onPressed: _carregar,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente')),
                  ])),
          actions: [
            TextButton(
                onPressed: _salvando ? null : () => Navigator.pop(context),
                child: const Text('Fechar')),
            FilledButton.icon(
                onPressed: _carregando ||
                        _salvando ||
                        pedido == null ||
                        pedido.restante <= .009
                    ? null
                    : _salvar,
                icon: const Icon(Icons.check),
                label: Text(_salvando
                    ? 'Confirmando...'
                    : _forma == 2
                        ? 'Lançar em Conta'
                        : 'Confirmar'))
          ],
        ));
  }
}
