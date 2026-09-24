import 'package:app/src/essencial/api/socket/monitor_atualizacao_tela.dart';
import 'dart:async';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/essencial/widgets/atalhos_pendencias_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/busca_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/filtros_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/menu_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/acoes_menu_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/pendencias_sincronizacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaDelivery extends StatefulWidget {
  final ProvedorDelivery? provedor;
  final Future<bool> Function(PedidoDelivery pedido)? receberPedido;
  const PaginaDelivery({super.key, this.provedor, this.receberPedido});
  @override
  State<PaginaDelivery> createState() => _PaginaDeliveryState();
}

class _PaginaDeliveryState extends State<PaginaDelivery>
    with WidgetsBindingObserver {
  late final _provedor = widget.provedor ?? Modular.get<ProvedorDelivery>();
  final _busca = TextEditingController();
  Timer? _debounce;
  late final MonitorAtualizacaoTela _monitorAtualizacao;
  StreamSubscription<PedidoDelivery>? _atualizacoes;
  bool _rotaAberta = false,
      _ativo = true,
      _processandoLote = false,
      _modoSelecao = false;
  int _progressoLote = 0, _totalLote = 0;
  String? _ocupado, _excluindo;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _atualizacoes = ServicoDelivery.pedidosAtualizados.listen((pedido) {
      if (!mounted) return;
      _provedor.atualizarPedido(pedido);
    });
    _provedor.listar();
    _monitorAtualizacao = MonitorAtualizacaoTela(
      atualizar: () => _provedor.listar(mostrarCarregamento: false),
      estaAtiva: () =>
          mounted &&
          _ativo &&
          !_rotaAberta &&
          !_processandoLote &&
          _ocupado == null &&
          ModalRoute.of(context)?.isCurrent != false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ativo = state == AppLifecycleState.resumed;
    if (_ativo &&
        !_rotaAberta &&
        !_processandoLote &&
        _ocupado == null &&
        !_provedor.carregando) {
      _provedor.listar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _monitorAtualizacao.dispose();
    _debounce?.cancel();
    _atualizacoes?.cancel();
    _busca.dispose();
    super.dispose();
  }

  Future<void> _abrir(Widget pagina) async {
    _rotaAberta = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
    } finally {
      _rotaAberta = false;
      if (mounted) await _provedor.listar();
    }
  }

  Future<void> _cardapio(PedidoDelivery pedido) => _abrir(PaginaCardapio(
        tipo: TipoCardapio.delivery,
        id: pedido.id,
        idCliente: pedido.cliente,
        tipodeentrega: pedido.tipoEntrega,
        nomeAtendimento: 'Delivery #${pedido.numero}',
        deliveryDireto: pedido.salvoNoAparelho,
      ));

  Future<void> _retomarLocal(PedidoDelivery pedido) async {
    if (_ocupado != null || _rotaAberta) return;
    if (pedido.aguardandoSincronizacao) {
      final sync = Sincronizador.instancia;
      if (sync != null) {
        await _abrir(PendenciasSincronizacao(sincronizador: sync));
      }
      return;
    }
    if (!pedido.produtosConfirmadosLocal || pedido.possuiRascunhoLocal) {
      await _cardapio(pedido);
      return;
    }
    if (pedido.restante <= .009) {
      setState(() => _ocupado = pedido.id);
      try {
        await _provedor.servico.concluir(pedido);
        await _provedor.servico.confirmar(pedido.id);
        _mensagem(
            'Pedido salvo no aparelho. A sincronização será feita ao conectar.');
      } catch (erro) {
        _mensagem(erro is StateError
            ? erro.message.toString()
            : 'Não foi possível confirmar o pedido salvo.');
      } finally {
        if (mounted) {
          setState(() => _ocupado = null);
          await _provedor.listar();
        }
      }
      return;
    }
    final cardapio = Modular.get<ProvedorCardapio>();
    cardapio.tipo = TipoCardapio.delivery;
    cardapio.id = pedido.id;
    cardapio.idCliente = pedido.cliente;
    cardapio.tipodeentrega = pedido.tipoEntrega;
    final pagamento = Modular.get<ProvedorFinalizarPagamento>();
    pagamento.idVenda = pedido.id;
    pagamento.valor = pedido.restante;
    pagamento.definirContextoDelivery(
        recorrenteVinculado: false,
        pagamentoParcial: pedido.possuiPagamentoRegistrado,
        pedido: pedido);
    await _abrir(PaginaSelecionarPagamento(
        totalReceber: pedido.restante,
        desconto: valorDelivery(pedido.dados['valorDesconto']),
        acrescimo: pedido.texto('valorAcrescimo', '0'),
        descontoPercentual: '0',
        totalPedido: pedido.total.toStringAsFixed(2)));
  }

  Future<bool> _receberNoFluxoNormal(PedidoDelivery pedido) async {
    if (widget.receberPedido != null) {
      return widget.receberPedido!(pedido);
    }

    final cardapio = Modular.get<ProvedorCardapio>();
    cardapio.tipo = TipoCardapio.delivery;
    cardapio.id = pedido.id;
    cardapio.idCliente = pedido.cliente;
    cardapio.tipodeentrega = pedido.tipoEntrega;

    final pagamento = Modular.get<ProvedorFinalizarPagamento>();
    pagamento.idVenda = pedido.id;
    pagamento.valor = pedido.restante;
    pagamento.definirContextoDelivery(
      recorrenteVinculado: pedido.recorrenteVinculado,
      pagamentoParcial: pedido.possuiPagamentoRegistrado,
      pedido: pedido,
      recebimentoObrigatorio: true,
    );

    _rotaAberta = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      final recebeu = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(
            name: ProvedorFinalizarPagamento.rotaRecebimentoObrigatorioDelivery,
          ),
          builder: (_) => const PaginaFinalizarAcrescimo(),
        ),
      );
      return recebeu == true;
    } finally {
      _rotaAberta = false;
      pagamento.encerrarRecebimentoObrigatorioDelivery();
    }
  }

  Future<void> _excluirRascunho(PedidoDelivery pedido) async {
    if (_ocupado != null || _rotaAberta || pedido.aguardandoSincronizacao) {
      return;
    }
    final cs = Theme.of(context).colorScheme;
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.delete_outline_rounded, color: cs.error),
        title: const Text('Excluir rascunho?'),
        content: Text(
          pedido.possuiPagamentoRegistrado
              ? 'Este rascunho possui pagamento registrado. O pedido, os itens e o pagamento salvo neste aparelho serão excluídos. Esta ação não pode ser desfeita.'
              : 'O pedido e todos os itens salvos neste aparelho serão excluídos. Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('Excluir'),
            style: FilledButton.styleFrom(
              backgroundColor: cs.error,
              foregroundColor: cs.onError,
            ),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() {
      _ocupado = pedido.id;
      _excluindo = pedido.id;
    });
    try {
      await _provedor.servico.excluirRascunho(pedido.id);
      _provedor.removerPedido(pedido.id);
    } catch (erro) {
      _mensagem(erro is StateError
          ? erro.message.toString()
          : 'Não foi possível excluir o rascunho.');
    } finally {
      if (mounted) {
        setState(() {
          _ocupado = null;
          _excluindo = null;
        });
        await _provedor.listar();
      }
    }
  }

  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _menu(PedidoDelivery pedido, EtapaDelivery etapa) async {
    if (pedido.salvoNoAparelho) return _retomarLocal(pedido);
    if (_ocupado != null || _rotaAberta) return;
    _rotaAberta = true;
    try {
      final acao = await mostrarMenuPedidoDelivery(context, pedido, etapa);
      if (acao == null || !mounted) return;
      setState(() => _ocupado = pedido.id);
      final atual = await _provedor.servico.pedido(pedido.id);
      if (!mounted) return;
      await executarAcaoDelivery(context, _provedor.servico, atual, acao);
    } catch (e) {
      _mensagem(e is StateError
          ? e.message.toString()
          : 'Não foi possível confirmar a ação. Atualize o pedido antes de tentar novamente.');
    } finally {
      _rotaAberta = false;
      if (mounted) {
        setState(() => _ocupado = null);
        await _provedor.listar();
      }
    }
  }

  Future<Map<String, dynamic>?> _selecionarEntregador(
      {int quantidade = 1}) async {
    List<Map<String, dynamic>> iniciais;
    try {
      iniciais = await _provedor.servico.entregadores();
    } catch (_) {
      _mensagem('Não foi possível consultar os entregadores. Tente novamente.');
      return null;
    }
    if (!mounted) return null;
    if (iniciais.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.delivery_dining_outlined),
          title: const Text('Nenhum entregador ativo'),
          content: const Text(
            'A etapa de destino está configurada para exigir um entregador, mas não existe entregador ativo disponível. Ative ou cadastre um entregador, ou desative essa exigência na configuração da etapa.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      return null;
    }
    var usarIniciais = true;
    return buscarDelivery(
      context,
      titulo: quantidade == 1
          ? 'Selecionar entregador'
          : 'Entregador para $quantidade pedidos',
      buscar: (termo) async {
        if (usarIniciais && termo.trim().isEmpty) {
          usarIniciais = false;
          return iniciais;
        }
        return _provedor.servico.entregadores(termo);
      },
      nome: (e) => '${e['nomecompleto'] ?? e['nome']}',
      detalhe: (e) => '${e['telefone'] ?? ''}',
    );
  }

  Future<bool> _avancar(
    PedidoDelivery pedido,
    EtapaDelivery origem,
    EtapaDelivery? destino, {
    bool atualizarAoFinal = true,
    bool gerenciarOcupado = true,
    bool atualizarProvedor = true,
    bool exibirFalha = true,
    ConfigDelivery? configuracao,
    String entregadorSelecionado = '',
  }) async {
    if (pedido.salvoNoAparelho) {
      await _retomarLocal(pedido);
      return false;
    }
    if (_ocupado != null) return false;
    if (pedido.quantidade == 0) {
      await _cardapio(pedido);
      return false;
    }
    if (gerenciarOcupado) setState(() => _ocupado = pedido.id);
    bool alterado = false;
    try {
      var atual = await _provedor.servico.pedido(pedido.id);
      if (!mounted) return false;
      if (!atual.podeAvancar(origem) || atual.etapa != origem.id) {
        throw StateError(
            'O pedido foi atualizado em outro aparelho. Confira a etapa atual.');
      }
      final alvo = destino ?? origem;
      final config = configuracao ?? await _provedor.servico.configuracao();
      if (!mounted) return false;
      var precisaRevalidar = false;
      if (config.exigePagamento(atual, alvo)) {
        final recebeu = await _receberNoFluxoNormal(atual);
        if (recebeu != true || !mounted) return false;
        atual = await _provedor.servico.pedido(pedido.id);
        if (atual.restante > .009) {
          if (exibirFalha) {
            _mensagem(
                'Pagamento parcial registrado. Falta ${atual.restante.obterReal()}.');
          }
          return false;
        }
        if (atual.etapa != origem.id || !atual.podeAvancar(origem)) {
          throw StateError('O pedido foi atualizado. Confira a etapa atual.');
        }
      }
      if (!mounted) return false;
      String entregador = config.entregadorFixo.isNotEmpty
              ? config.entregadorFixo
              : entregadorSelecionado,
          taxa = atual.texto('valordaentrega', '0');
      if (atual.tipoEntrega == '1' &&
          alvo.selecionarEntregador &&
          entregador.isEmpty) {
        final res = await _selecionarEntregador();
        if (res == null || !mounted) return false;
        entregador = '${res['id']}';
        precisaRevalidar = true;
      }
      // O servidor também revalida a etapa e o total na gravação. Uma nova
      // consulta aqui só é necessária quando houve espera em outro diálogo.
      final conferido =
          precisaRevalidar ? await _provedor.servico.pedido(pedido.id) : atual;
      if (!conferido.podeAvancar(origem) ||
          conferido.etapa != origem.id ||
          (conferido.total - atual.total).abs() > .009 ||
          config.exigePagamento(conferido, alvo)) {
        throw StateError('O pedido mudou. Confira os dados antes de avançar.');
      }
      final etapaImprimePreparo = ['1', '4'].contains(alvo.impressao);
      final imprimirPreparo =
          etapaImprimePreparo && config.imprimirPreparoSeparado;
      final imprimirComprovante = ['2', '4'].contains(alvo.impressao) ||
          (etapaImprimePreparo &&
              config.imprimirPreparoNoComprovanteConsumacao);
      final mensagens = imprimirPreparo || imprimirComprovante
          ? await ImpressaoDelivery.prepararMensagens(
              _provedor.servico, conferido.comEtapa(alvo.id),
              preparo: imprimirPreparo,
              ambos: imprimirPreparo && imprimirComprovante,
              config: config)
          : <String>[];
      if (!mounted) return false;
      var preparoPersistido = false;
      if (alvo.impressao == '3' && !conferido.encerrado) {
        await _provedor.servico.concluir(conferido);
      }
      if (destino != null) {
        final res = await _provedor.servico.avancar(conferido, alvo,
            entregador: entregador, valorEntrega: taxa, impressoes: mensagens);
        if (valorDeliverySim(res['ativarselecaoentregador']) &&
            entregador.isEmpty) {
          throw StateError(
              'Esta etapa exige um entregador. Confira a configuração do Delivery.');
        }
        preparoPersistido = res['impressao_persistida'] == true;
        alterado = true;
        if (atualizarProvedor) {
          _provedor.moverPedidoParaEtapa(conferido, alvo.id);
          _provedor.servico
              .notificarPedidoAtualizado(conferido.comEtapa(alvo.id));
        }
      }
      if (mensagens.isNotEmpty) {
        await ImpressaoDelivery.enviarPreparadas(
            Modular.get<Server>(), mensagens,
            preparoPersistido: preparoPersistido);
      }
      return destino != null || alvo.impressao == '3';
    } catch (e) {
      if (exibirFalha) {
        _mensagem(alterado
            ? 'Etapa atualizada, mas há uma pendência. Confira o pedido e a fila de impressão.'
            : e is StateError
                ? e.message.toString()
                : 'Não foi possível confirmar a alteração. Atualize o Delivery.');
      }
      return alterado;
    } finally {
      if (mounted && gerenciarOcupado) {
        setState(() => _ocupado = null);
        if (atualizarAoFinal) await _provedor.listar();
      }
    }
  }

  Future<EtapaDelivery?> _selecionarDestinoLote(
    List<PedidoDelivery> pedidos,
    EtapaDelivery origem,
    EtapaDelivery proxima,
    List<EtapaDelivery> etapas,
    ConfigDelivery config,
  ) async {
    final indiceOrigem = etapas.indexWhere((etapa) => etapa.id == origem.id);
    if (indiceOrigem < 0) return null;
    final destinos = etapas.skip(indiceOrigem + 1).toList(growable: false);
    if (destinos.isEmpty) return null;

    String? bloqueio(EtapaDelivery etapa) {
      if (etapa.impressao == '3' &&
          pedidos.any((pedido) => config.exigePagamento(pedido, etapa))) {
        return 'Há pedidos sem pagamento completo. Receba esses pedidos antes de concluir.';
      }
      return null;
    }

    Widget opcao(BuildContext dialogContext, EtapaDelivery etapa,
        {required String titulo, String? subtitulo, required IconData icone}) {
      final motivo = bloqueio(etapa);
      return ListTile(
        key: ValueKey('destino-lote-${etapa.id}'),
        enabled: motivo == null,
        leading: Icon(icone),
        title: Text(titulo),
        subtitle: Text(motivo ?? subtitulo ?? etapa.nome),
        trailing: Icon(motivo == null
            ? Icons.chevron_right_rounded
            : Icons.lock_outline_rounded),
        onTap:
            motivo == null ? () => Navigator.pop(dialogContext, etapa) : null,
      );
    }

    return showDialog<EtapaDelivery>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(pedidos.length == 1
            ? 'Mover 1 pedido'
            : 'Mover ${pedidos.length} pedidos'),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              opcao(
                dialogContext,
                proxima,
                titulo: 'Avançar',
                subtitulo: 'Próxima etapa: ${proxima.nome}',
                icone: Icons.arrow_forward_rounded,
              ),
              if (destinos.length > 1) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    'Ou escolha uma etapa mais adiante',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                for (final etapa in destinos.skip(1))
                  opcao(
                    dialogContext,
                    etapa,
                    titulo: etapa.nome,
                    icone: Icons.view_kanban_outlined,
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<Set<String>> _avancarLote(
    List<PedidoDelivery> pedidos,
    EtapaDelivery origem,
    EtapaDelivery? proxima,
    List<EtapaDelivery> etapas,
  ) async {
    if (_ocupado != null ||
        _rotaAberta ||
        _processandoLote ||
        pedidos.isEmpty ||
        proxima == null) {
      return const {};
    }
    setState(() => _processandoLote = true);
    var iniciouMovimento = false;
    final movidosDaOrigem = <String>{};
    final chegaramAoDestino = <String>{};
    try {
      final config = await _provedor.servico.configuracao();
      if (!mounted) return const {};
      final destino = await _selecionarDestinoLote(
          pedidos, origem, proxima, etapas, config);
      if (destino == null || !mounted) return const {};

      final confirmou = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.playlist_add_check_circle_outlined),
          title: const Text('Confirmar movimentação'),
          content: Text(
            'Mover ${pedidos.length} ${pedidos.length == 1 ? 'pedido' : 'pedidos'} de ${origem.nome} para ${destino.nome}?\n\nO aplicativo passará pelas etapas intermediárias e manterá todas as regras de pagamento, entregador e impressão.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Mover pedidos'),
            ),
          ],
        ),
      );
      if (confirmou != true || !mounted) return const {};

      final indiceOrigem = etapas.indexWhere((etapa) => etapa.id == origem.id);
      final indiceDestino =
          etapas.indexWhere((etapa) => etapa.id == destino.id);
      if (indiceOrigem < 0 || indiceDestino <= indiceOrigem) {
        throw StateError('A etapa de destino não está mais disponível.');
      }
      final caminho = etapas.sublist(indiceOrigem + 1, indiceDestino + 1);

      String entregadorLote = config.entregadorFixo;
      final quantidadeEntregas =
          pedidos.where((pedido) => pedido.tipoEntrega == '1').length;
      final exigeEntregador = entregadorLote.isEmpty &&
          quantidadeEntregas > 0 &&
          caminho.any((etapa) => etapa.selecionarEntregador);
      if (exigeEntregador) {
        final entregador =
            await _selecionarEntregador(quantidade: quantidadeEntregas);
        if (entregador == null || !mounted) return const {};
        entregadorLote = '${entregador['id']}';
      }

      iniciouMovimento = true;
      setState(() {
        _progressoLote = 0;
        _totalLote = pedidos.length;
      });
      for (var indicePedido = 0;
          indicePedido < pedidos.length;
          indicePedido++) {
        if (!mounted) break;
        final pedido = pedidos[indicePedido];
        var atual = pedido;
        var etapaAtual = origem;
        var chegou = true;
        for (final etapaDestino in caminho) {
          var avancou = await _avancar(
            atual,
            etapaAtual,
            etapaDestino,
            atualizarAoFinal: false,
            gerenciarOcupado: false,
            atualizarProvedor: false,
            exibirFalha: false,
            configuracao: config,
            entregadorSelecionado: entregadorLote,
          );
          PedidoDelivery? confirmadoNoServidor;
          if (!avancou) {
            // Se a conexão caiu depois da gravação, a resposta pode ter sido
            // perdida mesmo com o pedido já movido. Confere antes de tratá-lo
            // como falha para não deixar cards para trás indevidamente.
            try {
              confirmadoNoServidor = await _provedor.servico.pedido(pedido.id);
              avancou = confirmadoNoServidor.etapa == etapaDestino.id;
            } catch (_) {
              avancou = false;
            }
          }
          if (!avancou) {
            chegou = false;
            break;
          }
          movidosDaOrigem.add(pedido.id);
          atual = confirmadoNoServidor ?? atual.comEtapa(etapaDestino.id);
          etapaAtual = etapaDestino;
        }
        if (chegou) chegaramAoDestino.add(pedido.id);
        if (mounted) {
          setState(() => _progressoLote = indicePedido + 1);
        }
        await Future<void>.delayed(Duration.zero);
      }
      if (mounted) {
        final pendentes = pedidos.length - chegaramAoDestino.length;
        _mensagem(pendentes == 0
            ? '${chegaramAoDestino.length} ${chegaramAoDestino.length == 1 ? 'pedido movido' : 'pedidos movidos'} para ${destino.nome}.'
            : '${chegaramAoDestino.length} chegaram a ${destino.nome}. $pendentes não chegaram ao destino; confira os pedidos que permaneceram selecionados.');
      }
      return movidosDaOrigem;
    } catch (erro) {
      _mensagem(erro is StateError
          ? erro.message.toString()
          : 'Não foi possível mover os pedidos. Atualize o Delivery e tente novamente.');
      return movidosDaOrigem;
    } finally {
      if (mounted) {
        try {
          if (iniciouMovimento) await _provedor.listar();
        } finally {
          if (mounted) {
            setState(() {
              _processandoLote = false;
              _progressoLote = 0;
              _totalLote = 0;
            });
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
          title: const Text('Delivery'),
          backgroundColor: cs.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar pedidos',
                onPressed: _ocupado == null && !_processandoLote
                    ? _provedor.listar
                    : null,
                icon: const Icon(Icons.refresh)),
          ]),
      floatingActionButton: _AcoesFlutuantesDelivery(
        habilitado: _ocupado == null && !_processandoLote,
        onNovoPedido: () =>
            _abrir(PaginaNovoDelivery(servico: _provedor.servico)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: ListenableBuilder(
          listenable: _provedor,
          builder: (context, child) {
            final filtros = Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                      controller: _busca,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                          hintText: 'Pedido, cliente ou telefone',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _busca.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _debounce?.cancel();
                                    _busca.clear();
                                    _provedor.pesquisa = '';
                                    _provedor.listar();
                                  }),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onChanged: (v) {
                        setState(() {});
                        _debounce?.cancel();
                        _provedor.pesquisa = v.trim();
                        _debounce = Timer(const Duration(milliseconds: 350),
                            _provedor.listar);
                      },
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        _provedor.listar();
                      },
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const ValueKey('modo-selecao-delivery'),
                      tooltip: _modoSelecao
                          ? 'Sair da seleção de pedidos'
                          : 'Selecionar pedidos para avançar',
                      isSelected: _modoSelecao,
                      selectedIcon: const Icon(Icons.close_rounded),
                      onPressed: _ocupado == null && !_processandoLote
                          ? () => setState(() {
                                _modoSelecao = !_modoSelecao;
                              })
                          : null,
                      icon: const Icon(Icons.checklist_rounded),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                        tooltip: 'Filtrar período e entrega',
                        icon: const Icon(Icons.tune),
                        onPressed: _ocupado == null && !_processandoLote
                            ? () async {
                                final aplicar = await showDialog<bool>(
                                    context: context,
                                    builder: (_) =>
                                        FiltrosDelivery(provedor: _provedor));
                                if (mounted && aplicar == true) {
                                  _provedor.listar();
                                }
                              }
                            : null),
                  ])),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${DateFormat('dd/MM').format(_provedor.periodo.start)} - ${DateFormat('dd/MM').format(_provedor.periodo.end)} · ${_provedor.horaInicio.substring(0, 5)}',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12))),
                    Text(
                        '${_provedor.etapas.fold<int>(0, (s, e) => s + e.pedidos.length)} pedidos',
                        style: const TextStyle(fontSize: 12)),
                  ])),
              SizedBox(
                  height: 2,
                  child: _provedor.carregando
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null),
              if (_provedor.erro != null)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Expanded(
                          child: Text(_provedor.erro!,
                              style: TextStyle(color: cs.error))),
                      IconButton(
                          tooltip: 'Tentar novamente',
                          onPressed: _provedor.listar,
                          icon: const Icon(Icons.refresh)),
                    ])),
            ]);
            if (_provedor.etapas.isEmpty) {
              return Column(children: [
                filtros,
                Expanded(
                    child: Center(
                        child: _provedor.carregando
                            ? const CircularProgressIndicator()
                            : Text(_provedor.erro == null
                                ? 'Nenhuma etapa de Delivery cadastrada'
                                : 'Delivery indisponível')))
              ]);
            }
            return _CarrosselDelivery(
              etapas: _provedor.etapas,
              filtros: filtros,
              atualizar: _provedor.listar,
              ocupado: _processandoLote ? '__lote__' : _ocupado,
              excluindo: _excluindo,
              abrir: (p) => p.salvoNoAparelho
                  ? _retomarLocal(p)
                  : _abrir(PaginaDetalhesDelivery(
                      servico: _provedor.servico, id: p.id)),
              avancar: _avancar,
              avancarLote: _avancarLote,
              progressoLote: _progressoLote,
              totalLote: _totalLote,
              modoSelecao: _modoSelecao,
              encerrarSelecao: () {
                if (mounted) setState(() => _modoSelecao = false);
              },
              excluir: _excluirRascunho,
              opcoes: _menu,
              config: _provedor.config,
            );
          }),
    );
  }
}

class _CarrosselDelivery extends StatefulWidget {
  final List<EtapaDelivery> etapas;
  final Widget filtros;
  final String? ocupado, excluindo;
  final bool modoSelecao;
  final int progressoLote, totalLote;
  final ConfigDelivery? config;
  final VoidCallback encerrarSelecao;
  final Future<void> Function() atualizar;
  final Future<void> Function(PedidoDelivery) abrir;
  final Future<void> Function(PedidoDelivery, EtapaDelivery) opcoes;
  final Future<void> Function(PedidoDelivery) excluir;
  final Future<bool> Function(PedidoDelivery, EtapaDelivery, EtapaDelivery?)
      avancar;
  final Future<Set<String>> Function(
    List<PedidoDelivery>,
    EtapaDelivery,
    EtapaDelivery?,
    List<EtapaDelivery>,
  ) avancarLote;
  const _CarrosselDelivery(
      {required this.etapas,
      required this.filtros,
      required this.atualizar,
      required this.abrir,
      required this.avancar,
      required this.avancarLote,
      required this.progressoLote,
      required this.totalLote,
      required this.modoSelecao,
      required this.encerrarSelecao,
      required this.excluir,
      required this.opcoes,
      this.ocupado,
      this.excluindo,
      this.config});
  @override
  State<_CarrosselDelivery> createState() => _CarrosselDeliveryState();
}

class _CarrosselDeliveryState extends State<_CarrosselDelivery>
    with TickerProviderStateMixin {
  late TabController _abas =
      TabController(length: widget.etapas.length, vsync: this);
  final _produtosExpandidos = <String>{};
  final _selecionados = <String>{};

  bool _podeSelecionar(
    PedidoDelivery pedido,
    EtapaDelivery etapa,
    EtapaDelivery? destino,
  ) =>
      !pedido.salvoNoAparelho &&
      pedido.quantidade > 0 &&
      pedido.podeAvancar(etapa) &&
      destino != null;

  void _alternarSelecao(String id, [bool? selecionar]) {
    setState(() {
      if (selecionar ?? !_selecionados.contains(id)) {
        _selecionados.add(id);
      } else {
        _selecionados.remove(id);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CarrosselDelivery old) {
    super.didUpdateWidget(old);
    if (old.modoSelecao && !widget.modoSelecao) {
      _selecionados.clear();
    }
    if (old.etapas.map((e) => e.id).join(',') !=
        widget.etapas.map((e) => e.id).join(',')) {
      final id = old.etapas[_abas.index].id;
      final indice = widget.etapas.indexWhere((e) => e.id == id);
      final anterior = _abas;
      _abas = TabController(
          length: widget.etapas.length,
          vsync: this,
          initialIndex: indice < 0 ? 0 : indice);
      WidgetsBinding.instance.addPostFrameCallback((_) => anterior.dispose());
    }
    final disponiveis = <String>{};
    for (var i = 0; i < widget.etapas.length; i++) {
      final etapa = widget.etapas[i];
      final destino = etapa.impressao != '3' && i + 1 < widget.etapas.length
          ? widget.etapas[i + 1]
          : null;
      disponiveis.addAll(etapa.pedidos
          .where((pedido) => _podeSelecionar(pedido, etapa, destino))
          .map((pedido) => pedido.id));
    }
    _selecionados.removeWhere((id) => !disponiveis.contains(id));
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Material(
        color: cs.inversePrimary,
        child: TabBar(
          controller: _abas,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final e in widget.etapas)
              Tab(text: '${e.nome} (${e.pedidos.length})')
          ],
        ),
      ),
      widget.filtros,
      Expanded(
          child: TabBarView(controller: _abas, children: [
        for (var i = 0; i < widget.etapas.length; i++)
          Builder(builder: (_) {
            final etapa = widget.etapas[i];
            final destino =
                etapa.impressao != '3' && i + 1 < widget.etapas.length
                    ? widget.etapas[i + 1]
                    : null;
            final selecionaveis = etapa.pedidos
                .where((pedido) => _podeSelecionar(pedido, etapa, destino))
                .toList();
            final idsSelecionaveis = selecionaveis.map((p) => p.id).toSet();
            final selecionadosEtapa =
                _selecionados.intersection(idsSelecionaveis);
            final todosSelecionados = selecionaveis.isNotEmpty &&
                selecionadosEtapa.length == selecionaveis.length;
            return Column(children: [
              if (widget.modoSelecao && selecionaveis.isNotEmpty)
                _BarraSelecaoDelivery(
                  etapa: etapa,
                  quantidadeSelecionada: selecionadosEtapa.length,
                  quantidadeDisponivel: selecionaveis.length,
                  todosSelecionados: todosSelecionados,
                  ocupado: widget.ocupado != null,
                  progresso: widget.progressoLote,
                  totalProgresso: widget.totalLote,
                  aoSelecionarTodos: () => setState(() {
                    if (todosSelecionados) {
                      _selecionados.removeAll(idsSelecionaveis);
                    } else {
                      _selecionados.addAll(idsSelecionaveis);
                    }
                  }),
                  aoAvancar: selecionadosEtapa.isEmpty
                      ? null
                      : () async {
                          final escolhidos = [
                            for (final pedido in selecionaveis)
                              if (selecionadosEtapa.contains(pedido.id)) pedido,
                          ];
                          final avancados = await widget.avancarLote(
                            escolhidos,
                            etapa,
                            destino,
                            widget.etapas,
                          );
                          if (mounted && avancados.isNotEmpty) {
                            _selecionados.removeAll(avancados);
                            if (_selecionados.isEmpty) {
                              widget.encerrarSelecao();
                            } else {
                              setState(() {});
                            }
                          }
                        },
                ),
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: widget.atualizar,
                      child: ListView.builder(
                          key: PageStorageKey('delivery-${etapa.id}'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 170),
                          itemCount:
                              etapa.pedidos.isEmpty ? 1 : etapa.pedidos.length,
                          itemBuilder: (_, j) {
                            if (etapa.pedidos.isEmpty) {
                              return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 64),
                                  child: Column(children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 42, color: cs.outline),
                                    const SizedBox(height: 12),
                                    const Text('Nenhum pedido nesta etapa'),
                                  ]));
                            }
                            final p = etapa.pedidos[j];
                            final idade = p.abertura == null
                                ? ''
                                : '${DateTime.now().difference(p.abertura!).inMinutes.clamp(0, 99999)} min';
                            final label = p.salvoNoAparelho
                                ? p.aguardandoSincronizacao
                                    ? 'Ver sincronização'
                                    : 'Continuar pedido'
                                : p.quantidade == 0
                                    ? 'Adicionar produtos'
                                    : widget.config?.exigePagamento(
                                                p, destino ?? etapa) ==
                                            true
                                        ? 'Receber ${p.restante.obterReal()}'
                                        : etapa.impressao == '3'
                                            ? 'Concluir pedido'
                                            : etapa.botao;
                            final podeAvancar = p.salvoNoAparelho ||
                                p.podeAvancar(etapa) && destino != null;
                            final selecionavel =
                                _podeSelecionar(p, etapa, destino);
                            final selecionado = _selecionados.contains(p.id);
                            final podeExcluirRascunho =
                                p.salvoNoAparelho && !p.aguardandoSincronizacao;
                            final excluindo = widget.excluindo == p.id;
                            final avancando =
                                widget.ocupado == p.id && !excluindo;
                            final produtos = p.produtos;
                            final podeMostrarProdutos =
                                p.quantidade > 0 && produtos.isNotEmpty;
                            final produtosAbertos =
                                _produtosExpandidos.contains(p.id);
                            return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: widget.modoSelecao && selecionado
                                    ? cs.primaryContainer.withValues(alpha: .28)
                                    : cs.surfaceContainerLowest,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(
                                        color: widget.modoSelecao && selecionado
                                            ? cs.primary
                                            : cs.outlineVariant,
                                        width: widget.modoSelecao && selecionado
                                            ? 1.5
                                            : 1)),
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: widget.ocupado == null
                                        ? widget.modoSelecao
                                            ? selecionavel
                                                ? () => _alternarSelecao(p.id)
                                                : null
                                            : () => widget.abrir(p)
                                        : null,
                                    child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                if (widget.modoSelecao &&
                                                    selecionavel) ...[
                                                  Checkbox(
                                                    key: ValueKey(
                                                        'selecionar-delivery-${p.id}'),
                                                    value: selecionado,
                                                    onChanged: widget.ocupado !=
                                                            null
                                                        ? null
                                                        : (valor) =>
                                                            _alternarSelecao(
                                                                p.id, valor),
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                    materialTapTargetSize:
                                                        MaterialTapTargetSize
                                                            .shrinkWrap,
                                                  ),
                                                  const SizedBox(width: 4),
                                                ],
                                                Expanded(
                                                    child: Text('#${p.numero}',
                                                        style: TextStyle(
                                                            color: cs.primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold))),
                                                Icon(
                                                    p.tipoEntrega == '1'
                                                        ? Icons.delivery_dining
                                                        : Icons
                                                            .shopping_bag_outlined,
                                                    size: 18,
                                                    color: cs.onSurfaceVariant),
                                                const SizedBox(width: 5),
                                                Text(p.nomeEntrega,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: cs
                                                            .onSurfaceVariant)),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                    tooltip:
                                                        'Opções do pedido #${p.numero}',
                                                    onPressed: widget.ocupado ==
                                                                null &&
                                                            !widget.modoSelecao
                                                        ? () => widget.opcoes(
                                                            p, etapa)
                                                        : null,
                                                    icon: const Icon(
                                                        Icons.more_vert,
                                                        size: 20)),
                                              ]),
                                              const SizedBox(height: 10),
                                              if (p.salvoNoAparelho)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 8),
                                                  child: Text(
                                                    p.texto('estadoSincronizacao') ==
                                                            'conflito'
                                                        ? 'Sincronização precisa de conferência'
                                                        : p.aguardandoSincronizacao
                                                            ? 'Salvo no aparelho · aguardando sincronização'
                                                            : 'Rascunho salvo no aparelho',
                                                    style: TextStyle(
                                                        color: cs.primary,
                                                        fontWeight:
                                                            FontWeight.w600),
                                                  ),
                                                ),
                                              if (etapa.impressao == '3')
                                                Text('Concluído',
                                                    style: TextStyle(
                                                        color: cs.primary,
                                                        fontSize: 12)),
                                              Text(p.nome,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              if (p.tipoEntrega == '1' &&
                                                  p.endereco.isNotEmpty)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(p.endereco,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: cs
                                                                .onSurfaceVariant))),
                                              const SizedBox(height: 12),
                                              Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        '${p.quantidade} itens${idade.isEmpty ? '' : ' · $idade'}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: cs
                                                                .onSurfaceVariant))),
                                                Text(p.total.obterReal(),
                                                    style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ]),
                                              if (p.tipoEntrega == '1')
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Text(
                                                      'Entrega: ${p.taxaEntrega.obterReal()}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: cs
                                                              .onSurfaceVariant)),
                                                ),
                                              if (podeMostrarProdutos) ...[
                                                const SizedBox(height: 10),
                                                _BotaoPreviewProdutos(
                                                  aberto: produtosAbertos,
                                                  quantidade: produtos.length,
                                                  onTap: () => setState(() {
                                                    if (produtosAbertos) {
                                                      _produtosExpandidos
                                                          .remove(p.id);
                                                    } else {
                                                      _produtosExpandidos
                                                          .add(p.id);
                                                    }
                                                  }),
                                                ),
                                                AnimatedCrossFade(
                                                  firstChild:
                                                      const SizedBox.shrink(),
                                                  secondChild:
                                                      _PreviewProdutosPedido(
                                                          produtos: produtos),
                                                  crossFadeState:
                                                      produtosAbertos
                                                          ? CrossFadeState
                                                              .showSecond
                                                          : CrossFadeState
                                                              .showFirst,
                                                  duration: const Duration(
                                                      milliseconds: 180),
                                                  firstCurve:
                                                      Curves.easeOutCubic,
                                                  secondCurve:
                                                      Curves.easeOutCubic,
                                                  sizeCurve:
                                                      Curves.easeOutCubic,
                                                ),
                                              ],
                                              if (p.pago > 0)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        p.restante <= .009
                                                            ? 'Pagamento registrado'
                                                            : 'A receber ${p.restante.obterReal()}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                cs.primary))),
                                              if (podeAvancar) ...[
                                                const SizedBox(height: 12),
                                                Row(children: [
                                                  if (podeExcluirRascunho) ...[
                                                    Expanded(
                                                      flex: 5,
                                                      child:
                                                          OutlinedButton.icon(
                                                        key: ValueKey(
                                                            'excluir-delivery-${p.id}'),
                                                        onPressed: widget
                                                                        .ocupado !=
                                                                    null ||
                                                                widget
                                                                    .modoSelecao
                                                            ? null
                                                            : () => widget
                                                                .excluir(p),
                                                        icon: excluindo
                                                            ? const SizedBox(
                                                                width: 18,
                                                                height: 18,
                                                                child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2),
                                                              )
                                                            : const Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                size: 19,
                                                              ),
                                                        label: Text(excluindo
                                                            ? 'Excluindo...'
                                                            : 'Excluir'),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              cs.error,
                                                          side: BorderSide(
                                                              color: cs.error),
                                                          minimumSize:
                                                              const Size(0, 60),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                  ],
                                                  Expanded(
                                                    flex: podeExcluirRascunho
                                                        ? 8
                                                        : 1,
                                                    child: FilledButton.icon(
                                                      onPressed: widget
                                                                      .ocupado !=
                                                                  null ||
                                                              widget.modoSelecao
                                                          ? null
                                                          : () => widget.avancar(
                                                              p,
                                                              etapa,
                                                              etapa.impressao ==
                                                                      '3'
                                                                  ? null
                                                                  : destino),
                                                      icon: avancando
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2))
                                                          : const Icon(
                                                              Icons
                                                                  .arrow_forward,
                                                              size: 18),
                                                      label: Text(
                                                          avancando
                                                              ? 'Aguarde...'
                                                              : label,
                                                          textAlign:
                                                              TextAlign.center),
                                                      style: FilledButton.styleFrom(
                                                          minimumSize:
                                                              const Size(0, 60),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8))),
                                                    ),
                                                  ),
                                                ]),
                                              ],
                                            ]))));
                          }))),
            ]);
          })
      ])),
    ]);
  }
}

class _BarraSelecaoDelivery extends StatelessWidget {
  final EtapaDelivery etapa;
  final int quantidadeSelecionada;
  final int quantidadeDisponivel;
  final bool todosSelecionados;
  final bool ocupado;
  final int progresso, totalProgresso;
  final VoidCallback aoSelecionarTodos;
  final Future<void> Function()? aoAvancar;

  const _BarraSelecaoDelivery({
    required this.etapa,
    required this.quantidadeSelecionada,
    required this.quantidadeDisponivel,
    required this.todosSelecionados,
    required this.ocupado,
    required this.progresso,
    required this.totalProgresso,
    required this.aoSelecionarTodos,
    required this.aoAvancar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final podeAvancar = !ocupado && aoAvancar != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Material(
        color: cs.primaryContainer.withValues(alpha: .22),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: cs.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: LayoutBuilder(builder: (context, constraints) {
            final compacto = constraints.maxWidth < 500;
            final parcialmenteSelecionado =
                quantidadeSelecionada > 0 && !todosSelecionados;
            return Row(
              children: [
                Expanded(
                  flex: compacto ? 4 : 5,
                  child: OutlinedButton.icon(
                    key: ValueKey('selecionar-todos-delivery-${etapa.id}'),
                    onPressed: ocupado ? null : aoSelecionarTodos,
                    icon: Icon(
                      todosSelecionados
                          ? Icons.check_box_rounded
                          : parcialmenteSelecionado
                              ? Icons.indeterminate_check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                      size: 19,
                    ),
                    label: Text(compacto
                        ? 'Todos ($quantidadeDisponivel)'
                        : 'Selecionar todos ($quantidadeDisponivel)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: compacto ? 6 : 5,
                  child: FilledButton.icon(
                    key: ValueKey('avancar-selecionados-delivery-${etapa.id}'),
                    onPressed: podeAvancar ? () => aoAvancar!.call() : null,
                    icon: ocupado
                        ? totalProgresso > 0
                            ? const SizedBox.square(
                                dimension: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.hourglass_top_rounded, size: 19)
                        : const Icon(Icons.arrow_forward_rounded, size: 19),
                    label: Text(
                      ocupado
                          ? totalProgresso > 0
                              ? 'Movendo $progresso/$totalProgresso'
                              : 'Preparando...'
                          : compacto
                              ? 'Mover ($quantidadeSelecionada)'
                              : 'Mover selecionados ($quantidadeSelecionada)',
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

class _BotaoPreviewProdutos extends StatelessWidget {
  final bool aberto;
  final int quantidade;
  final VoidCallback onTap;
  const _BotaoPreviewProdutos(
      {required this.aberto, required this.quantidade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            Icon(Icons.receipt_long_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              aberto
                  ? 'Ocultar itens'
                  : 'Ver itens ($quantidade ${quantidade == 1 ? 'item' : 'itens'})',
              style: TextStyle(
                  color: cs.primary, fontSize: 13, fontWeight: FontWeight.w600),
            )),
            Icon(
              aberto
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: cs.primary,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PreviewProdutosPedido extends StatelessWidget {
  final List<Modelowordprodutos> produtos;
  const _PreviewProdutosPedido({required this.produtos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final produto in produtos)
            _LinhaPreviewProduto(produto: produto),
        ],
      ),
    );
  }
}

class _LinhaPreviewProduto extends StatelessWidget {
  final Modelowordprodutos produto;
  const _LinhaPreviewProduto({required this.produto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dados = DadosImpressaoPreparo.produto(produto);
    final detalhes = _detalhes(dados);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_formatarQuantidade(produto.quantidade)}x',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _texto(dados['nome']).isEmpty
                    ? produto.nome
                    : _texto(dados['nome']),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (detalhes.isNotEmpty) ...[
                const SizedBox(height: 2),
                for (final detalhe in detalhes)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detalhe,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            valorDelivery(produto.valorTotalVendas ?? produto.valorVenda)
                .obterReal(),
            style: TextStyle(
                color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ]),
    );
  }

  List<String> _detalhes(Map<String, dynamic> dados) {
    final linhas = <String>[];
    for (final opcao in [
      ..._lista(dados['opcoesPacotesListaFinal']),
      ..._lista(dados['opcoesPacotes']),
    ]) {
      final titulo = _texto(opcao['titulo']);
      final partes = <String>[
        for (final dado in _lista(opcao['dados'])) _nomeDado(dado).trim(),
        for (final produto in _lista(opcao['produtos']))
          _texto(produto['nome']).trim(),
      ]..removeWhere((parte) => parte.isEmpty);
      if (partes.isEmpty) continue;
      linhas.add('${titulo.isEmpty ? 'Opções' : titulo}: ${partes.join(', ')}');
    }
    final observacao = _texto(dados['observacao']).trim();
    if (observacao.isNotEmpty) linhas.add('Obs: $observacao');
    return linhas;
  }

  String _nomeDado(Map<String, dynamic> dado) {
    final nome = _texto(dado['nome']);
    final quantidade = dado['quantidade'];
    final qtd = quantidade is num
        ? quantidade.toInt()
        : int.tryParse((quantidade ?? '').toString()) ?? 0;
    return qtd > 1 ? '${qtd}x $nome' : nome;
  }
}

List<Map<String, dynamic>> _lista(Object? valor) {
  if (valor is! List) return const [];
  return [
    for (final item in valor)
      if (item is Map) Map<String, dynamic>.from(item)
  ];
}

String _texto(Object? valor) => valor?.toString() ?? '';

String _formatarQuantidade(double? valor) {
  final quantidade = valor ?? 1;
  if (quantidade == quantidade.roundToDouble()) {
    return quantidade.toInt().toString();
  }
  return quantidade.toStringAsFixed(2).replaceAll('.', ',');
}

class _BotaoNovoPedido extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onPressed;
  final double? largura;
  const _BotaoNovoPedido({
    required this.habilitado,
    required this.onPressed,
    this.largura,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final larguraBotao = largura ??
        (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 560.0).toDouble();
    return Tooltip(
      message: 'Novo Delivery',
      child: Semantics(
        label: 'Novo Delivery',
        button: true,
        enabled: habilitado,
        excludeSemantics: true,
        child: Opacity(
          opacity: habilitado ? 1 : .55,
          child: Container(
            key: const ValueKey('novo-delivery'),
            width: larguraBotao,
            constraints: const BoxConstraints(minHeight: 64),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: habilitado ? onPressed : null,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      SizedBox(width: 10),
                      Text(
                        'Novo Delivery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AcoesFlutuantesDelivery extends StatelessWidget {
  const _AcoesFlutuantesDelivery({
    required this.habilitado,
    required this.onNovoPedido,
  });

  final bool habilitado;
  final VoidCallback onNovoPedido;

  @override
  Widget build(BuildContext context) {
    final larguraTela = MediaQuery.sizeOf(context).width;
    final largura = (larguraTela - 32).clamp(0.0, double.infinity);
    if (larguraTela >= 600) {
      final larguraNovoPedido = (largura - 140).clamp(0.0, 560.0).toDouble();
      return SizedBox(
        width: largura,
        height: 64,
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              left: 0,
              top: 3,
              child: BotaoFlutuantePendenciasImpressao(tag: 'delivery'),
            ),
            _BotaoNovoPedido(
              habilitado: habilitado,
              onPressed: onNovoPedido,
              largura: larguraNovoPedido,
            ),
          ],
        ),
      );
    }
    return SizedBox(
      width: largura,
      height: 134,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            child: BotaoFlutuantePendenciasImpressao(tag: 'delivery'),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _BotaoNovoPedido(
              habilitado: habilitado,
              onPressed: onNovoPedido,
            ),
          ),
        ],
      ),
    );
  }
}
