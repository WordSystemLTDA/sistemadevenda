import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

enum AlteracaoDelivery { cancelar, entrega, pagamento }

class AlterarPedidoDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  final PedidoDelivery pedido;
  final AlteracaoDelivery alteracao;
  const AlterarPedidoDelivery(
      {super.key,
      required this.servico,
      required this.pedido,
      required this.alteracao});
  @override
  State<AlterarPedidoDelivery> createState() => _AlterarPedidoDeliveryState();
}

class _AlterarPedidoDeliveryState extends State<AlterarPedidoDelivery> {
  final _senha = TextEditingController(), _motivo = TextEditingController();
  late final _taxa = TextEditingController(
      text: widget.pedido.taxaEntrega.toStringAsFixed(2).replaceAll('.', ','));
  late String _tipo = widget.pedido.tipoEntrega;
  String? _endereco, _mov, _banco, _erro;
  bool _carregando = true, _salvando = false, _carregamentoFalhou = false;
  List<Map<String, dynamic>> _enderecos = [], _pagamentos = [];
  final Map<String, String> _bancos = {
    '1': 'Dinheiro',
    '3': 'Cartão de débito',
    '4': 'Cartão de crédito'
  };
  ConfigDelivery? _config;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  @override
  void dispose() {
    _senha.dispose();
    _motivo.dispose();
    _taxa.dispose();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      if (widget.alteracao == AlteracaoDelivery.entrega) {
        _config = await widget.servico.configuracao();
        final dados = await widget.servico.consultar(
            'enderecos_clientes/listar_por_cliente.php',
            {'cliente': widget.pedido.cliente, 'pesquisa': ''});
        _enderecos = [
          for (final e in dados as List) Map<String, dynamic>.from(e as Map)
        ];
        _endereco = _enderecos
            .where((e) => '${e['id']}' == widget.pedido.texto('idendereco'))
            .firstOrNull?['id']
            ?.toString();
        _endereco ??= _enderecos
            .where((e) => e['padrao'] == 'Sim')
            .firstOrNull?['id']
            ?.toString();
      } else if (widget.alteracao == AlteracaoDelivery.pagamento) {
        final res = await widget.servico.acao('pagamentos', widget.pedido);
        _pagamentos = [
          for (final p in res['dados']['pagamentos'] as List)
            Map<String, dynamic>.from(p as Map)
        ];
        final bancos = await widget.servico.consultar(
            'tela_nfe_saida/listar_bancos.php',
            {'id_empresa': widget.servico.usuario.usuario?.empresa});
        for (final (forma, sufixo) in [
          ('5', 'Pix'),
          ('6', 'Opcao2'),
          ('7', 'Opcao3'),
          ('8', 'Opcao4'),
          ('9', 'Opcao5')
        ]) {
          if (bancos['ativoBanco$sufixo'] == 'Sim') {
            final id = '${bancos['idBanco$sufixo'] ?? '0'}';
            if (id != '0') _bancos[forma] = '${bancos['nomeBanco$sufixo']}';
          }
        }
        if (_pagamentos.length == 1) _mov = '${_pagamentos.first['id']}';
      }
    } catch (_) {
      _carregamentoFalhou = true;
      _erro = 'Não foi possível carregar os dados. Feche e tente novamente.';
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  void _atualizarTaxa() {
    final e = _enderecos.where((e) => '${e['id']}' == _endereco).firstOrNull;
    _taxa.text =
        (_tipo == '1' ? _config?.taxaEntrega(e?['valortaxabairro']) ?? 0 : 0)
            .toStringAsFixed(2)
            .replaceAll('.', ',');
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      switch (widget.alteracao) {
        case AlteracaoDelivery.cancelar:
          if (_senha.text.trim().isEmpty || _motivo.text.trim().isEmpty) {
            throw StateError('Informe a senha Admin e o motivo.');
          }
          await widget.servico.acao('cancelar', widget.pedido,
              {'senha': _senha.text, 'motivo': _motivo.text.trim()});
        case AlteracaoDelivery.entrega:
          if (_tipo == '1' && _endereco == null) {
            throw StateError('Selecione o endereço da entrega.');
          }
          final taxa = valorDelivery(_taxa.text);
          if (taxa < 0) throw StateError('Informe uma taxa válida.');
          await widget.servico.acao('entrega', widget.pedido, {
            'tipo': _tipo,
            'endereco': _endereco ?? '0',
            'taxa': _tipo == '1' ? taxa.toStringAsFixed(2) : '0'
          });
        case AlteracaoDelivery.pagamento:
          if (_mov == null || _banco == null) {
            throw StateError(
                'Selecione o lançamento e a nova forma de pagamento.');
          }
          final mov = _pagamentos.firstWhere((p) => '${p['id']}' == _mov);
          await widget.servico.acao('alterarPagamento', widget.pedido, {
            'movimentacao': _mov,
            'banco': _banco,
            'valorOriginal': mov['valor']
          });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e is StateError
            ? e.message.toString()
            : 'Não foi possível confirmar. Consulte o pedido antes de tentar novamente.');
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titulo = switch (widget.alteracao) {
      AlteracaoDelivery.cancelar => 'Cancelar Venda',
      AlteracaoDelivery.entrega => 'Mudar Tipo de Entrega',
      AlteracaoDelivery.pagamento => 'Alterar Forma de Pagamento',
    };
    return PopScope(
        canPop: !_salvando,
        child: AlertDialog(
          scrollable: true,
          title: Text(titulo),
          content: SizedBox(
              width: 460,
              child: AbsorbPointer(
                  absorbing: _salvando,
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                            'Pedido #${widget.pedido.numero} · ${widget.pedido.nome}'),
                        const SizedBox(height: 16),
                        if (_carregando) const LinearProgressIndicator(),
                        if (!_carregando) ...[
                          if (widget.alteracao ==
                              AlteracaoDelivery.cancelar) ...[
                            TextField(
                                controller: _senha,
                                obscureText: true,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: const InputDecoration(
                                    labelText: 'Senha Admin de cancelamento',
                                    prefixIcon: Icon(Icons.lock_outline))),
                            const SizedBox(height: 16),
                            TextField(
                                controller: _motivo,
                                maxLength: 250,
                                minLines: 2,
                                maxLines: 4,
                                decoration: const InputDecoration(
                                    labelText: 'Motivo do cancelamento')),
                          ],
                          if (widget.alteracao ==
                              AlteracaoDelivery.entrega) ...[
                            SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                      value: '1', label: Text('Entrega')),
                                  ButtonSegment(
                                      value: '2', label: Text('Retirada')),
                                  ButtonSegment(
                                      value: '3', label: Text('No local')),
                                ],
                                selected: {
                                  _tipo
                                },
                                showSelectedIcon: false,
                                onSelectionChanged: (v) => setState(() {
                                      _tipo = v.single;
                                      _atualizarTaxa();
                                    })),
                            if (_tipo == '1') ...[
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                  initialValue: _endereco,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Endereço de entrega'),
                                  items: [
                                    for (final e in _enderecos)
                                      DropdownMenuItem(
                                          value: '${e['id']}',
                                          child: Text(
                                              '${e['endereco']}, ${e['numero']}',
                                              overflow: TextOverflow.ellipsis))
                                  ],
                                  onChanged: (v) => setState(() {
                                        _endereco = v;
                                        _atualizarTaxa();
                                      })),
                              const SizedBox(height: 16),
                              TextField(
                                  controller: _taxa,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  decoration: const InputDecoration(
                                      labelText: 'Taxa de entrega',
                                      prefixText: 'R\$ ')),
                            ],
                          ],
                          if (widget.alteracao ==
                              AlteracaoDelivery.pagamento) ...[
                            if (_pagamentos.isEmpty)
                              const Text(
                                  'Nenhum lançamento disponível para alteração.'),
                            if (_pagamentos.isNotEmpty) ...[
                              DropdownButtonFormField<String>(
                                  initialValue: _mov,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Pagamento registrado'),
                                  items: [
                                    for (final p in _pagamentos)
                                      DropdownMenuItem(
                                          value: '${p['id']}',
                                          child: Text(
                                              '${p['documento']} · ${valorDelivery(p['valor']).obterReal()}',
                                              overflow: TextOverflow.ellipsis))
                                  ],
                                  onChanged: (v) => setState(() => _mov = v)),
                              const SizedBox(height: 16),
                              DropdownButtonFormField<String>(
                                  initialValue: _banco,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                      labelText: 'Nova forma de pagamento'),
                                  items: [
                                    for (final b in _bancos.entries)
                                      DropdownMenuItem(
                                          value: b.key, child: Text(b.value))
                                  ],
                                  onChanged: (v) => setState(() => _banco = v)),
                            ],
                          ],
                        ],
                        if (_erro != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(_erro!,
                                  style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error))),
                      ]))),
          actions: [
            TextButton(
                onPressed: _salvando ? null : () => Navigator.pop(context),
                child: const Text('Voltar')),
            FilledButton(
              onPressed: _salvando || _carregando || _carregamentoFalhou ? null : _salvar,
                child: Text(_salvando ? 'Confirmando...' : 'Confirmar')),
          ],
        ));
  }
}
