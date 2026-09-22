import 'dart:async';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gravador_voz.dart';
import 'lote_pedido_voz.dart';
import 'pedido_falado.dart';
import 'servico_pedido_voz.dart';

/// O rascunho fica nesta janela até a confirmação explícita do operador.
class DialogoComandaVoz extends StatefulWidget {
  final String atendimento;
  final ServicoPedidoVoz servico;
  final GravadorVoz gravador;
  const DialogoComandaVoz(
      {super.key,
      required this.atendimento,
      required this.servico,
      required this.gravador});
  @override
  State<DialogoComandaVoz> createState() => _DialogoComandaVozState();
}

class _DialogoComandaVozState extends State<DialogoComandaVoz>
    with WidgetsBindingObserver {
  final _texto = TextEditingController();
  bool _ocupado = true, _pronto = false, _gravando = false, _iniciando = false;
  bool _verificacaoPendente = false;
  int _segundos = 0, _operacao = 0;
  String? _erro;
  LotePedidoVoz? _resultado;
  Timer? _timer;
  final _historico = <String>[];
  String _pergunta = '';

  void _guardarHistorico(String texto) {
    if (texto.trim().isEmpty) return;
    _historico.add(texto.trim());
    while (_historico.length > 12 || _historico.join().length > 8000) {
      _historico.removeAt(0);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
  }

  void _falha(Object erro) {
    if (!mounted) return;
    setState(() {
      _ocupado = false;
      _erro = erro is FalhaPedidoVoz
          ? erro.mensagem
          : erro is MissingPluginException
              ? 'Atualize o aplicativo para habilitar o microfone. Você também pode digitar o pedido.'
              : erro is PlatformException
                  ? 'Confira a permissão do microfone nos ajustes do aparelho.'
                  : 'Não foi possível interpretar o pedido. Tente novamente.';
    });
  }

  Future<void> _verificar() async {
    if (_verificacaoPendente) return;
    _verificacaoPendente = true;
    setState(() {
      _ocupado = true;
      _erro = null;
    });
    try {
      await widget.servico.verificar();
      if (!widget.servico.suportaLote) {
        throw const FalhaPedidoVoz(
            'Atualize a API para habilitar a comanda eletrônica e por voz.');
      }
      if (mounted) {
        setState(() {
          _pronto = true;
          _ocupado = false;
        });
      }
    } catch (erro) {
      _falha(erro);
    } finally {
      _verificacaoPendente = false;
    }
  }

  Future<void> _iniciar() async {
    if (_ocupado || _gravando || _iniciando) return;
    final operacao = ++_operacao;
    setState(() {
      _ocupado = true;
      _iniciando = true;
      _erro = null;
    });
    try {
      await widget.gravador.iniciar();
      if (!mounted || operacao != _operacao) {
        await widget.gravador.cancelar();
        return;
      }
      setState(() {
        _ocupado = false;
        _gravando = true;
        _segundos = 0;
      });
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segundos++);
        if (_segundos >= 60) {
          _interromper('Tempo encerrado. Grave até 60 segundos por vez.');
        }
      });
    } catch (erro) {
      if (operacao == _operacao) _falha(erro);
    } finally {
      if (mounted) setState(() => _iniciando = false);
    }
  }

  Future<void> _interpretar({bool audio = false}) async {
    if (_ocupado || _iniciando || (!audio && _texto.text.trim().isEmpty)) {
      return;
    }
    final operacao = ++_operacao;
    final texto = _texto.text.trim();
    _timer?.cancel();
    setState(() {
      _ocupado = true;
      _gravando = false;
      _erro = null;
    });
    try {
      final caminho = audio ? await widget.gravador.concluir() : null;
      if (!mounted || operacao != _operacao) return;
      final resultado = await widget.servico.interpretarLote(
          caminho: caminho,
          texto: audio ? null : texto,
          rascunho: _resultado?.rascunho,
          contexto: {'historico': _historico, 'pergunta': _pergunta});
      if (!mounted || operacao != _operacao) return;
      _historico.clear();
      _pergunta = '';
      setState(() {
        _resultado = resultado;
        _ocupado = false;
        _texto.clear();
      });
    } catch (erro) {
      if (operacao == _operacao) {
        if (erro is EsclarecimentoPedidoVoz) {
          _guardarHistorico(erro.texto);
          _pergunta = erro.mensagem;
          _texto.clear();
        }
        _falha(erro);
      }
    }
  }

  Future<void> _interromper(String motivo) async {
    ++_operacao;
    _timer?.cancel();
    if (mounted) setState(() => _gravando = false);
    _falha(FalhaPedidoVoz(motivo));
    try {
      await widget.gravador.cancelar();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final saiu =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if ((_gravando || (_ocupado && !_iniciando && _pronto)) &&
            (saiu || state == AppLifecycleState.inactive) ||
        _iniciando && saiu) {
      _interromper(
          'Pedido interrompido. Confira o rascunho e tente novamente.');
    }
  }

  @override
  void dispose() {
    ++_operacao;
    _timer?.cancel();
    _texto.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.servico.dispose();
    unawaited(widget.gravador.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final resultado = _resultado;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Icon(Icons.mic_rounded, color: tema.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text('Pedido por voz',
                            style: tema.textTheme.titleLarge)),
                    IconButton(
                        tooltip: 'Fechar pedido por voz',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ]),
                  Text(widget.atendimento, style: tema.textTheme.titleSmall),
                  const SizedBox(height: 12),
                  const Text(
                      'Fale os produtos e as opções. Confira o rascunho antes de adicionar ao carrinho.'),
                  if (_pronto) ...[
                    const SizedBox(height: 12),
                    if (_gravando) ...[
                      Text('Gravando: ${_segundos}s / 60s',
                          style: TextStyle(color: tema.colorScheme.error)),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: _segundos / 60),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                          onPressed: () => _interpretar(audio: true),
                          icon: const Icon(Icons.stop),
                          label: const Text('Concluir gravação')),
                    ] else ...[
                      OutlinedButton.icon(
                          onPressed: _ocupado || _iniciando ? null : _iniciar,
                          icon: const Icon(Icons.mic),
                          label: Text(resultado == null
                              ? 'Gravar pedido'
                              : 'Corrigir ou acrescentar por voz')),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _texto,
                          enabled: !_ocupado,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 4000,
                          decoration: InputDecoration(
                              labelText: resultado == null
                                  ? 'Ou digite o pedido'
                                  : 'Correção ou novo item',
                              hintText: resultado == null
                                  ? 'Duas marmitas e uma água'
                                  : 'Na segunda marmita, tire o feijão',
                              border: const OutlineInputBorder(),
                              counterText: ''),
                          onSubmitted: (_) => _interpretar()),
                      Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                              onPressed: _ocupado ? null : () => _interpretar(),
                              icon: const Icon(Icons.auto_fix_high),
                              label: const Text('Interpretar texto'))),
                    ],
                  ],
                  if (_ocupado) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(_iniciando
                        ? 'Abrindo microfone...'
                        : _pronto
                            ? 'Interpretando e conferindo o cardápio...'
                            : 'Verificando serviço de voz...')
                  ],
                  if (_erro != null) ...[
                    const SizedBox(height: 12),
                    Text(_erro!,
                        style: TextStyle(color: tema.colorScheme.error)),
                    if (!_pronto)
                      TextButton(
                          onPressed: _ocupado ? null : _verificar,
                          child: const Text('Tentar novamente')),
                  ],
                  if (resultado != null) ...[
                    const SizedBox(height: 16),
                    Text('Conferir pedido', style: tema.textTheme.titleMedium),
                    if (resultado.texto.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(resultado.texto,
                              style: tema.textTheme.bodySmall)),
                    for (var indice = 0;
                        indice < resultado.itens.length;
                        indice++)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(
                                          '${indice + 1}. ${resultado.itens[indice].quantidade?.toStringAsFixed(0)}x ${resultado.itens[indice].nome}',
                                          style: tema.textTheme.titleSmall),
                                      Text((double.parse(resultado
                                                  .itens[indice].valorVenda) *
                                              (resultado.itens[indice]
                                                      .quantidade ??
                                                  1))
                                          .obterReal()),
                                      for (final grupo in resultado
                                              .itens[indice]
                                              .opcoesPacotesListaFinal ??
                                          [])
                                        for (final dado in grupo.dados ?? [])
                                          Text(
                                              '${dado.quantidade != null && dado.quantidade > 1 ? '${dado.quantidade}x ' : ''}${dado.nome}',
                                              style: tema.textTheme.bodySmall),
                                    ])),
                                IconButton(
                                    tooltip: 'Remover item ${indice + 1}',
                                    onPressed: _ocupado || _gravando
                                        ? null
                                        : () => setState(() => _resultado =
                                            resultado.remover(indice)),
                                    icon: const Icon(Icons.delete_outline)),
                              ])),
                    if (resultado.itens.isEmpty)
                      const Text(
                          'Rascunho vazio. Grave ou digite um novo pedido.'),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                        onPressed:
                            _ocupado || _gravando || resultado.itens.isEmpty
                                ? null
                                : () => Navigator.pop(context, resultado),
                        icon: const Icon(Icons.add_shopping_cart),
                        label: const Text('Confirmar e adicionar ao carrinho')),
                  ],
                ])),
      ),
    );
  }
}
