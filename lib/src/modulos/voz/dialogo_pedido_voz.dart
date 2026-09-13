import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'gravador_voz.dart';
import 'pedido_falado.dart';
import 'servico_pedido_voz.dart';

enum _EtapaVoz { verificando, pronta, iniciando, gravando, interpretando, erro }

class DialogoPedidoVoz extends StatefulWidget {
  final String atendimento;
  final ServicoPedidoVoz servico;
  final GravadorVoz gravador;
  const DialogoPedidoVoz(
      {super.key,
      required this.atendimento,
      required this.servico,
      required this.gravador});

  @override
  State<DialogoPedidoVoz> createState() => _DialogoPedidoVozState();
}

class _DialogoPedidoVozState extends State<DialogoPedidoVoz>
    with WidgetsBindingObserver {
  _EtapaVoz _etapa = _EtapaVoz.verificando;
  String? _erro;
  Timer? _tempo;
  int _segundos = 0;
  int _operacao = 0;
  bool _interrompido = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _verificar();
  }

  Future<void> _verificar() async {
    setState(() {
      _etapa = _EtapaVoz.verificando;
      _erro = null;
    });
    try {
      await widget.servico.verificar();
      if (mounted) setState(() => _etapa = _EtapaVoz.pronta);
    } catch (erro) {
      _falha(erro);
    }
  }

  void _falha(Object erro) {
    if (!mounted) return;
    setState(() {
      _etapa = _EtapaVoz.erro;
      _erro = erro is FalhaPedidoVoz
          ? erro.mensagem
          : 'Não foi possível preparar o pedido por voz. Nenhum item foi enviado.';
    });
  }

  Future<void> _iniciar() async {
    if (_etapa != _EtapaVoz.pronta) return;
    final operacao = ++_operacao;
    _interrompido = false;
    setState(() => _etapa = _EtapaVoz.iniciando);
    try {
      await widget.gravador.iniciar();
      if (!mounted || operacao != _operacao) {
        await widget.gravador.cancelar();
        return;
      }
      unawaited(HapticFeedback.lightImpact());
      setState(() {
        _etapa = _EtapaVoz.gravando;
        _segundos = 0;
      });
      _tempo = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _segundos++);
        if (_segundos >= 60) {
          _interromper(
              'Tempo de gravação encerrado. Grave um pedido de até 60 segundos.');
        }
      });
    } catch (erro) {
      _falha(erro);
    }
  }

  Future<void> _concluir() async {
    if (_etapa != _EtapaVoz.gravando) return;
    final operacao = ++_operacao;
    _tempo?.cancel();
    setState(() => _etapa = _EtapaVoz.interpretando);
    try {
      final caminho = await widget.gravador.concluir();
      if (!mounted || operacao != _operacao) return;
      final resultado = await widget.servico.interpretar(caminho);
      if (!mounted || operacao != _operacao || _interrompido) return;
      Navigator.pop(context, resultado.item);
    } catch (erro) {
      if (operacao == _operacao) _falha(erro);
    }
  }

  Future<void> _interromper(String motivo) async {
    ++_operacao;
    _interrompido = true;
    _tempo?.cancel();
    _falha(FalhaPedidoVoz(motivo));
    try {
      await widget.gravador.cancelar();
    } catch (_) {/* Ja encerrado pelo sistema. */}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.inactive) &&
        (_etapa == _EtapaVoz.gravando || _etapa == _EtapaVoz.interpretando)) {
      _interromper('Pedido por voz interrompido. Nenhum item foi enviado.');
    }
  }

  @override
  void dispose() {
    ++_operacao;
    _tempo?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    widget.servico.dispose();
    unawaited(widget.gravador.dispose().catchError((Object _) {}));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final gravando = _etapa == _EtapaVoz.gravando;
    final ocupado = [
      _EtapaVoz.verificando,
      _EtapaVoz.iniciando,
      _EtapaVoz.interpretando
    ].contains(_etapa);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.mic_rounded, color: cs.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                      child: Text('Pedido por voz',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700))),
                  IconButton(
                      tooltip: 'Cancelar pedido por voz',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ]),
                const SizedBox(height: 8),
                Text(widget.atendimento,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 20),
                if (_etapa == _EtapaVoz.pronta) ...[
                  const Text(
                      'O áudio será enviado à OpenAI para interpretar o pedido. Ao concluir, os itens serão enviados ao preparo.'),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                      onPressed: _iniciar,
                      icon: const Icon(Icons.mic),
                      label: const Text('Gravar pedido')),
                ],
                if (gravando) ...[
                  Row(children: [
                    Icon(Icons.fiber_manual_record, color: cs.error, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Gravando',
                            style: TextStyle(fontWeight: FontWeight.w600))),
                    Text('00:${_segundos.toString().padLeft(2, '0')} / 01:00'),
                  ]),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                      value: _segundos / 60, color: cs.error),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                      onPressed: _concluir,
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Concluir e enviar')),
                ],
                if (ocupado) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(switch (_etapa) {
                    _EtapaVoz.interpretando =>
                      'Interpretando o pedido e conferindo o cardápio...',
                    _EtapaVoz.iniciando => 'Abrindo microfone...',
                    _ => 'Verificando serviço de voz...',
                  }),
                ],
                if (_erro != null) ...[
                  Text(_erro!, style: TextStyle(color: cs.error)),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                      onPressed: _verificar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente')),
                ],
              ]),
        ),
      ),
    );
  }
}
