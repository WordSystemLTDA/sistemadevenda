import 'dart:convert';
import 'dart:math' as math;

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'servico_transferencias.dart';

String _real(String valor) => (double.tryParse(valor) ?? 0).obterReal();

Future<void> abrirTransferencia(BuildContext context, AlvoTransferencia origem,
    {AlvoTransferencia? destino}) async {
  final confirmado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DialogoTransferencia(
          servico: Modular.get<ServicoTransferencias>(),
          origem: origem,
          destino: destino));
  if (confirmado != true) return;
  final server = Modular.get<Server>();
  for (final tipo in ['Mesa', 'Comanda']) {
    server.write(jsonEncode({'tipo': tipo}));
  }
  await Modular.get<ProvedorComanda>().listarComandas('');
  await Modular.get<ProvedorMesas>().listarMesas('');
}

Future<void> abrirHistoricoTransferencias(
        BuildContext context, AlvoTransferencia alvo) =>
    showDialog<void>(
        context: context,
        builder: (_) => HistoricoTransferencias(
            servico: Modular.get<ServicoTransferencias>(), alvo: alvo));

class AreaTransferencia extends StatelessWidget {
  final AlvoTransferencia alvo;
  final Widget child;
  final void Function(AlvoTransferencia origem, AlvoTransferencia destino)?
      aoSoltar;
  const AreaTransferencia(
      {super.key, required this.alvo, required this.child, this.aoSoltar});

  @override
  Widget build(BuildContext context) => DragTarget<AlvoTransferencia>(
      onWillAcceptWithDetails: (detalhes) =>
          detalhes.data.id != alvo.id &&
          detalhes.data.tipo == alvo.tipo &&
          alvo.motivo.isEmpty,
      onAcceptWithDetails: (detalhes) {
        if (aoSoltar != null) {
          aoSoltar!(detalhes.data, alvo);
        } else {
          abrirTransferencia(context, detalhes.data, destino: alvo);
        }
      },
      builder: (context, candidatos, rejeitados) {
        final destacado = candidatos.isNotEmpty;
        final conteudo = Stack(children: [
          child,
          if (destacado)
            Positioned.fill(
                child: IgnorePointer(
                    child: DecoratedBox(
              decoration: BoxDecoration(
                  color: VisualAtendimento.azul(context).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: VisualAtendimento.azul(context), width: 2)),
            ))),
        ]);
        if (!alvo.podeArrastar) return conteudo;
        return LongPressDraggable<AlvoTransferencia>(
            data: alvo,
            maxSimultaneousDrags: 1,
            delay: const Duration(milliseconds: 450),
            feedbackOffset: const Offset(0, -30),
            feedback: Material(
                elevation: 6,
                borderRadius: BorderRadius.circular(8),
                color: VisualAtendimento.superficie(context),
                child: SizedBox(
                    width: math.min(260, MediaQuery.sizeOf(context).width - 48),
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Icon(Icons.drive_file_move_outline,
                              color: VisualAtendimento.azul(context)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(alvo.nome,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700))),
                        ])))),
            childWhenDragging: Opacity(opacity: .35, child: conteudo),
            child: conteudo);
      });
}

class DialogoTransferencia extends StatefulWidget {
  final ServicoTransferencias servico;
  final AlvoTransferencia origem;
  final AlvoTransferencia? destino;
  const DialogoTransferencia(
      {super.key, required this.servico, required this.origem, this.destino});
  @override
  State<DialogoTransferencia> createState() => _DialogoTransferenciaState();
}

class _DialogoTransferenciaState extends State<DialogoTransferencia> {
  List<AlvoTransferencia> recursos = [];
  AlvoTransferencia? origem, destino;
  bool carregando = true, enviando = false, pendente = false;
  String? erro;
  String busca = '';
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      carregando = true;
      erro = null;
      origem = null;
      destino = null;
    });
    try {
      await widget.servico.iniciar();
      final anterior = await widget.servico.pendente();
      if (!mounted) return;
      if (anterior != null) {
        setState(() {
          pendente = true;
          origem = anterior.origem;
          destino = anterior.destino;
        });
        return;
      }
      pendente = false;
      final lista = await widget.servico.listar(widget.origem.tipo);
      if (!mounted) return;
      recursos = lista;
      if (!widget.origem.livre) {
        final atual = lista.where((e) => e.id == widget.origem.id).firstOrNull;
        if (atual == null ||
            atual.atendimento != widget.origem.atendimento ||
            !atual.podeArrastar) {
          throw FalhaTransferencia(atual?.motivo.isNotEmpty == true
              ? atual!.motivo
              : 'O atendimento de origem mudou. Atualize a lista antes de transferir.');
        }
        origem = atual;
      }
      final alvo = widget.destino;
      if (alvo != null) {
        final atual = lista.where((e) => e.id == alvo.id).firstOrNull;
        if (atual == null ||
            atual.atendimento != alvo.atendimento ||
            atual.livre != alvo.livre) {
          throw const FalhaTransferencia(
              'O destino mudou. Atualize a lista antes de transferir.');
        }
        if (atual.motivo.isNotEmpty) throw FalhaTransferencia(atual.motivo);
        await widget.servico.validarPendencias(origem!, atual);
        destino = atual;
      }
    } catch (e) {
      if (mounted)
        setState(() => erro = e is FalhaTransferencia
            ? e.mensagem
            : 'Nao foi possivel carregar a transferencia.');
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _confirmar() async {
    if (enviando || origem == null || destino == null) return;
    setState(() {
      enviando = true;
      erro = null;
    });
    try {
      if (pendente) {
        await widget.servico.verificarPendente();
      } else {
        await widget.servico.confirmar(origem!, destino!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        erro = e is FalhaTransferencia
            ? e.mensagem
            : 'Nao foi possivel concluir a transferencia.';
        pendente = e is FalhaTransferencia && e.pendente;
        if (!pendente) destino = null;
      });
    } finally {
      if (mounted) setState(() => enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final candidatos = recursos
        .where((e) =>
            (origem == null ? e.podeArrastar : e.id != origem!.id) &&
            normalizarBusca(e.nome).contains(normalizarBusca(busca)))
        .toList();
    return PopScope(
        canPop: !enviando,
        child: Dialog(
            insetPadding: const EdgeInsets.all(20),
            child: SizedBox(
                width: 520,
                height: math.min(600, MediaQuery.sizeOf(context).height * .8),
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      child: Row(children: [
                        const Icon(Icons.drive_file_move_outline),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                pendente
                                    ? 'Transferencia pendente'
                                    : 'Transferir / Juntar',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700))),
                        IconButton(
                            tooltip: 'Fechar',
                            onPressed:
                                enviando ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ])),
                  const Divider(height: 1),
                  if (carregando)
                    const Expanded(
                        child: Center(child: CircularProgressIndicator()))
                  else if (erro != null && !pendente)
                    Expanded(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.info_outline, color: cs.error),
                                  const SizedBox(height: 12),
                                  Text(erro!, textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  OutlinedButton.icon(
                                      onPressed: _carregar,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Atualizar')),
                                ])))
                  else if (destino == null) ...[
                    if (origem != null)
                      ListTile(
                          dense: true,
                          title: const Text('Origem'),
                          subtitle: Text(origem!.nome,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                    Padding(
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                            decoration: InputDecoration(
                                labelText: origem == null
                                    ? 'Buscar origem'
                                    : 'Buscar destino',
                                prefixIcon: const Icon(Icons.search),
                                border: const OutlineInputBorder()),
                            onChanged: (valor) =>
                                setState(() => busca = valor))),
                    Expanded(
                        child: candidatos.isEmpty
                            ? const Center(
                                child: Text('Nenhum atendimento disponivel.'))
                            : ListView.separated(
                                itemCount: candidatos.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final alvo = candidatos[i];
                                  return ListTile(
                                      enabled: alvo.motivo.isEmpty,
                                      leading: Icon(alvo.tipo == 'mesa'
                                          ? Icons.table_restaurant_outlined
                                          : Icons.receipt_long_outlined),
                                      title: Text(alvo.nome),
                                      subtitle: Text(alvo.motivo.isNotEmpty
                                          ? alvo.motivo
                                          : alvo.livre
                                              ? 'Livre'
                                              : 'Em atendimento'),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () => setState(() {
                                            if (origem == null) {
                                              origem = alvo;
                                              busca = '';
                                            } else {
                                              destino = alvo;
                                            }
                                          }));
                                })),
                  ] else ...[
                    Expanded(
                        child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ResumoTransferencia(
                                      rotulo: 'Origem',
                                      alvo: origem!,
                                      mostrarValor:
                                          widget.servico.mostrarValores),
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 12),
                                      child: Icon(Icons.arrow_downward)),
                                  _ResumoTransferencia(
                                      rotulo: 'Destino',
                                      alvo: destino!,
                                      mostrarValor:
                                          widget.servico.mostrarValores),
                                  const SizedBox(height: 20),
                                  if (widget.servico.mostrarValores)
                                    Text(
                                        'Total no destino: ${_real(((double.tryParse(origem!.total) ?? 0) + (double.tryParse(destino!.total) ?? 0)).toString())}',
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 12),
                                  Text(pendente
                                      ? 'O resultado ainda precisa de confirmacao do servidor.'
                                      : 'Todos os pedidos irao para ${destino!.nome}. ${origem!.nome} ficara livre.'),
                                  const SizedBox(height: 8),
                                  const Text(
                                      'Os itens nao serao impressos novamente. Avise a cozinha sobre a troca de destino.'),
                                  if (erro != null) ...[
                                    const SizedBox(height: 12),
                                    Text(erro!,
                                        style: TextStyle(color: cs.error))
                                  ],
                                ]))),
                    Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FilledButton.icon(
                                  onPressed: enviando ? null : _confirmar,
                                  icon: enviando
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2))
                                      : Icon(
                                          pendente ? Icons.sync : Icons.check),
                                  label: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Text(pendente
                                          ? 'Verificar transferencia'
                                          : destino!.livre
                                              ? 'Confirmar transferencia'
                                              : 'Confirmar uniao'))),
                              if (!pendente)
                                TextButton(
                                    onPressed: enviando
                                        ? null
                                        : () => setState(() => destino = null),
                                    child:
                                        const Text('Escolher outro destino')),
                            ])),
                  ],
                ]))));
  }
}

class _ResumoTransferencia extends StatelessWidget {
  final String rotulo;
  final AlvoTransferencia alvo;
  final bool mostrarValor;
  const _ResumoTransferencia(
      {required this.rotulo, required this.alvo, required this.mostrarValor});
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(rotulo,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12)),
        const SizedBox(height: 4),
        Text(alvo.nome,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        Text(alvo.livre ? 'Livre' : 'Atendimento #${alvo.atendimento}'),
        if (mostrarValor) Text(_real(alvo.total)),
      ]);
}

class HistoricoTransferencias extends StatefulWidget {
  final ServicoTransferencias servico;
  final AlvoTransferencia alvo;
  const HistoricoTransferencias(
      {super.key, required this.servico, required this.alvo});
  @override
  State<HistoricoTransferencias> createState() =>
      _HistoricoTransferenciasState();
}

class _HistoricoTransferenciasState extends State<HistoricoTransferencias> {
  final List<Map<String, dynamic>> itens = [];
  bool carregando = true, mais = true;
  String? erro;
  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      carregando = true;
      erro = null;
    });
    try {
      await widget.servico.iniciar();
      final resultado = await widget.servico.historico(widget.alvo,
          antes: itens.isEmpty ? null : itens.last['id'].toString());
      if (mounted)
        setState(() {
          itens.addAll(resultado);
          mais = resultado.length == 50;
        });
    } catch (e) {
      if (mounted) setState(() => erro = e.toString());
    } finally {
      if (mounted) setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SizedBox(
          width: 520,
          height: math.min(600, MediaQuery.sizeOf(context).height * .8),
          child: Column(children: [
            ListTile(
                title: const Text('Historico de transferencias'),
                subtitle: Text(widget.alvo.nome),
                trailing: IconButton(
                    tooltip: 'Fechar',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close))),
            const Divider(height: 1),
            Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
              for (final item in itens) ...[
                Text('${item['nome_origem']} → ${item['nome_destino']}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    'Atendimentos #${item['atendimento_origem']} / #${item['atendimento_destino']}'),
                Text('${item['criado_em']} · Usuario #${item['usuario']}'),
                if (widget.servico.mostrarValores)
                  Text(
                      'Transferido: ${_real(item['total_origem'].toString())}'),
                if ((item['observacao_origem'] ?? '').toString().isNotEmpty)
                  Text(item['observacao_origem'].toString()),
                const Divider(height: 24),
              ],
              if (!carregando && erro == null && itens.isEmpty)
                const Text('Nenhuma transferencia registrada.'),
              if (erro != null) Text(erro!),
              if (carregando)
                const Center(child: CircularProgressIndicator())
              else if (mais || erro != null)
                TextButton.icon(
                    onPressed: _carregar,
                    icon: const Icon(Icons.refresh),
                    label: Text(
                        erro == null ? 'Carregar mais' : 'Tentar novamente')),
            ])),
          ])));
}
