import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/widgets/bottom_editar_parcelamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';

class PaginaParcelamento extends StatefulWidget {
  // final SalvarListarVendasModelo modelo;
  final String idVenda;
  final double valor;
  final String acrescimo;
  final String desconto;
  final String descontoPercentual;
  final String totalPedido;
  final String totalReceber;
  // final String dinheiro;
  // final String promissoria;
  // final String cartaoDebito;
  // final String cartaoCredito;
  final String valorFalta;
  final String valorTroco;
  final String pagamentoselecionado;
  final String nomePagamentoSelecionado;
  final bool confirmacaoPedidoHabilitada;
  final DateTime? vencimentoRecorrente;

  const PaginaParcelamento({
    super.key,
    required this.idVenda,
    required this.valor,
    required this.acrescimo,
    required this.desconto,
    required this.descontoPercentual,
    required this.totalPedido,
    required this.totalReceber,
    // required this.dinheiro,
    // required this.promissoria,
    // required this.cartaoDebito,
    // required this.cartaoCredito,
    required this.valorFalta,
    required this.valorTroco,
    required this.pagamentoselecionado,
    this.nomePagamentoSelecionado = 'Conta',
    this.confirmacaoPedidoHabilitada = false,
    this.vencimentoRecorrente,
  });

  @override
  State<PaginaParcelamento> createState() => _PaginaParcelamentoState();
}

class _PaginaParcelamentoState extends State<PaginaParcelamento> {
  static const int _prazoPadraoDias = 30;
  static const int _intervaloEntreParcelasDias = 30;

  final ProvedorFinalizarPagamento provedor =
      Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorBalcao provedorBalcao = Modular.get<ProvedorBalcao>();
  final Server server = Modular.get<Server>();

  final _valorController = TextEditingController();
  late final TextEditingController _dataController;
  late String dataOriginal;

  final ValueNotifier<bool> finalizando = ValueNotifier(false);
  final ValueNotifier<List<ParcelasModelo>> listaParcelas = ValueNotifier([]);
  int _parcelas = 0;
  final _chavePagamento = ServicosRecorrentes.novaChave();

  String _vendaDia1 = '30';
  String _vendaDia2 = '45';
  String _vendaDia3 = '60';
  String _vendaDia4 = '90';

  @override
  void initState() {
    super.initState();

    final primeiroVencimento = widget.vencimentoRecorrente ??
        DateUtils.dateOnly(DateTime.now())
            .add(const Duration(days: _prazoPadraoDias));
    _dataController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(primeiroVencimento),
    );
    dataOriginal = DateFormat('yyyy-MM-dd').format(primeiroVencimento);
    _valorController.text =
        widget.valor.toStringAsFixed(2).replaceAll('.', ',');

    alterarParcelas(incrementar: true);
    listarDatasVenda();
  }

  Future<void> listarDatasVenda() async {
    final value =
        await context.read<ServicoFinalizarPagamento>().listarDatasVendas();
    if (!mounted || value == null) return;

    setState(() {
      _vendaDia1 = value.vendaDia1;
      _vendaDia2 = value.vendaDia2;
      _vendaDia3 = value.vendaDia3;
      _vendaDia4 = value.vendaDia4;
    });
  }

  void alterarParcelas({required bool incrementar}) {
    final quantidade = incrementar ? _parcelas + 1 : _parcelas - 1;
    if (quantidade < 1) return;
    _parcelas = quantidade;
    _substituirParcelas(DateTime.parse(dataOriginal));
  }

  List<ParcelasModelo> _montarParcelas(DateTime primeiroVencimento) {
    final totalCentavos = (widget.valor * 100).round();
    final valorBase = totalCentavos ~/ _parcelas;
    final resto = totalCentavos - (valorBase * _parcelas);

    return List.generate(_parcelas, (index) {
      final vencimento = DateUtils.dateOnly(primeiroVencimento).add(
        Duration(days: index * _intervaloEntreParcelasDias),
      );
      final valorCentavos = valorBase + (index == _parcelas - 1 ? resto : 0);
      final valor = (valorCentavos / 100).toStringAsFixed(2);
      return ParcelasModelo(
        parcela: (index + 1).toString(),
        valor: valor,
        vencimento: DateFormat('yyyy-MM-dd').format(vencimento),
        vencimentoController: TextEditingController(
            text: DateFormat('dd/MM/yyyy').format(vencimento)),
        valorController: TextEditingController(text: valor),
      );
    });
  }

  void _substituirParcelas(DateTime primeiroVencimento) {
    final antigas = listaParcelas.value;
    listaParcelas.value = _montarParcelas(primeiroVencimento);
    for (final parcela in antigas) {
      parcela.valorController?.dispose();
      parcela.vencimentoController?.dispose();
    }
    if (mounted) setState(() {});
  }

  void _definirPrimeiroVencimento(DateTime data) {
    _dataController.text = DateFormat('dd/MM/yyyy').format(data);
    dataOriginal = DateFormat('yyyy-MM-dd').format(data);
    _substituirParcelas(data);
  }

  void _selecionarPrazo(String valor) {
    final dias = int.tryParse(valor.trim());
    if (dias == null || dias < 0) return;
    _definirPrimeiroVencimento(
      DateUtils.dateOnly(DateTime.now()).add(Duration(days: dias)),
    );
  }

  @override
  void dispose() {
    _valorController.dispose();
    _dataController.dispose();
    finalizando.dispose();
    for (final parcela in listaParcelas.value) {
      parcela.valorController?.dispose();
      parcela.vencimentoController?.dispose();
    }
    listaParcelas.dispose();
    super.dispose();
  }

  int _valorEmCentavos(String valor) =>
      ((double.tryParse(valor.replaceAll(',', '.')) ?? 0) * 100).round();

  bool get _parcelasConferem =>
      listaParcelas.value.isNotEmpty &&
      listaParcelas.value.fold<int>(
            0,
            (total, parcela) =>
                total +
                _valorEmCentavos(
                    parcela.valorController?.text ?? parcela.valor),
          ) ==
          (widget.valor * 100).round();

  void _notificarDeliveryFinalizadoEmSegundoPlano(
      ServicoDelivery servico, String id) {
    unawaited(() async {
      try {
        servico.notificarPedidoAtualizado(await servico.pedido(id));
      } catch (_) {}
    }());
  }

  Future<String?> _enviarConfirmacaoPedidoAposFinalizar(
      ServicoDelivery servico, PedidoDelivery pedido) async {
    if (!widget.confirmacaoPedidoHabilitada || !pedido.possuiCelularCliente) {
      return null;
    }
    try {
      await servico.notificarConfirmacaoPedido(
        pedido,
        formaPagamento: widget.nomePagamentoSelecionado,
      );
      return null;
    } catch (erro, pilha) {
      debugPrint(
          '[Delivery] Pedido finalizado, mas a confirmação no WhatsApp falhou: $erro\n$pilha');
      final detalhe = erro is StateError
          ? erro.message.toString()
          : 'Confira a conexão e o WhatsApp do cliente.';
      return 'Pedido finalizado, mas a confirmação não foi enviada. $detalhe';
    }
  }

  void _mostrarFalhaConfirmacaoAposRetorno(
      ScaffoldMessengerState? mensageiro, String? mensagem) {
    if (mensageiro == null || mensagem == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mensageiro.mounted) return;
      mensageiro
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(mensagem),
          backgroundColor: Theme.of(mensageiro.context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
    });
  }

  Future<void> _finalizarDelivery() async {
    final servico = Modular.get<ServicoDelivery>();
    final totalReceber =
        double.tryParse(widget.totalReceber.replaceAll(',', '.')) ??
            widget.valor;
    final descontoInformado =
        double.tryParse(widget.desconto.replaceAll(',', '.')) ?? 0;
    final desconto = descontoInformado > 0 ? descontoInformado : 0.0;
    final acrescimo = descontoInformado < 0
        ? descontoInformado.abs()
        : (double.tryParse(widget.acrescimo.replaceAll(',', '.')) ?? 0);
    final pedido = await servico.pedido(widget.idVenda);

    await servico.pagar(
      pedido,
      int.parse(widget.pagamentoselecionado),
      widget.valor,
      valorOriginal: totalReceber,
      valorAPagar: totalReceber,
      desconto: desconto,
      acrescimo: acrescimo,
      dataLancamento: dataOriginal,
      parcelasLista: listaParcelas.value,
      chavePagamento: _chavePagamento,
      nomePagamento: widget.nomePagamentoSelecionado,
    );

    final pagamentoIntegral = widget.valor + 0.009 >= totalReceber;
    final atualizado =
        pagamentoIntegral ? pedido : await servico.pedido(widget.idVenda);
    final quitado = pagamentoIntegral || atualizado.restante <= 0.009;
    if (quitado) {
      await servico.concluir(atualizado);
      await servico.confirmar(widget.idVenda);
      final falhaConfirmacao =
          await _enviarConfirmacaoPedidoAposFinalizar(servico, atualizado);
      _notificarDeliveryFinalizadoEmSegundoPlano(servico, widget.idVenda);
      provedorBalcao.observacaoDoPedido = '';
      final contexto = carrinhoProvedor.contexto;
      if (!pedido.salvoNoAparelho &&
          contexto?.tipo == 'delivery' &&
          contexto?.idAtendimento == pedido.id) {
        await carrinhoProvedor.removerComandasPedidos(contexto: contexto);
      }
      FeedbackUsuario.pedidoFinalizado();
      if (!mounted) return;
      final mensageiro = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context, rootNavigator: true).popUntil((rota) =>
          rota.settings.name == provedor.rotaRetornoDelivery || rota.isFirst);
      _mostrarFalhaConfirmacaoAposRetorno(mensageiro, falhaConfirmacao);
      return;
    }

    provedor.idVenda = widget.idVenda;
    provedor.valor = atualizado.restante > 0
        ? atualizado.restante
        : totalReceber - widget.valor;
    if (!mounted) return;
    if (pedido.salvoNoAparelho) {
      Navigator.of(context, rootNavigator: true).popUntil((rota) =>
          rota.settings.name == provedor.rotaRetornoDelivery || rota.isFirst);
      return;
    }
    Navigator.popUntil(
        context, ModalRoute.withName('PaginaFinalizarAcrescimo'));
  }

  void finalizar() async {
    if (finalizando.value) return;
    finalizando.value = true;
    // final modelo = context.read<ProvedoresTelaNfeSaida>().venda;

    if (!mounted) {
      finalizando.value = false;
      return;
    }

    if (!_parcelasConferem) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('A soma das parcelas deve ser igual ao valor da conta.'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
      finalizando.value = false;
      return;
    }

    if (provedorCardapio.tipo == TipoCardapio.delivery) {
      try {
        await _finalizarDelivery();
      } catch (erro) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(erro is StateError
                ? erro.message.toString()
                : 'Não foi possível lançar o pagamento em conta.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ));
        }
      } finally {
        finalizando.value = false;
      }
      return;
    }

    var (sucesso, mensagem, idvenda) =
        await context.read<ServicoFinalizarPagamento>().pagarPedido(
              provedor.idVenda,
              provedorCardapio.idComanda,
              provedorCardapio.idMesa,
              provedorCardapio.idCliente,
              widget.valor.toStringAsFixed(2), // valorLancamento,
              widget.totalReceber, // valorOriginal,
              int.parse(widget.pagamentoselecionado),
              0, // quantidadePessoas,
              widget.totalReceber, // subTotal,
              dataOriginal, // dataLancamento,
              _parcelas.toString(), // parcelas
              listaParcelas.value, // parcelasLista
              provedorCardapio.tipo,
              (double.tryParse(widget.desconto) ?? 0)
                  .abs()
                  .toStringAsFixed(2), // valortroco,
              '0', // TODO: fazer delivery (valorentrega)
              carrinhoProvedor.itensCarrinho.precoTotal
                  .toStringAsFixed(2), // valoresProduto,
              false, // novo,
              provedorCardapio.tipodeentrega,
              carrinhoProvedor.itensCarrinho.listaComandosPedidos,
              widget.totalReceber, // valorAPagarOriginal,
              provedorBalcao.observacaoDoPedido,
            );

    if (sucesso) {
      if (idvenda.startsWith('venda-local:')) {
        await carrinhoProvedor.listarComandasPedidos();
        finalizando.value = false;
        if (!mounted) return;
        if (widget.valor >= double.parse(widget.totalReceber)) {
          provedorBalcao.observacaoDoPedido = '';
          FeedbackUsuario.pedidoFinalizado();
          Navigator.popUntil(context, ModalRoute.withName('PaginaBalcao'));
        } else {
          provedor.idVenda = idvenda;
          provedor.valor = double.parse(widget.totalReceber) - widget.valor;
          Navigator.popUntil(
              context, ModalRoute.withName('PaginaFinalizarAcrescimo'));
        }
        return;
      }
      provedorBalcao.observacaoDoPedido = '';

      if (widget.valor >= double.parse(widget.totalReceber)) {
        var provedorBalcao = Modular.get<ProvedorBalcao>();
        var servico = Modular.get<ServicoBalcao>();
        await provedorBalcao.listar();

        var vendaBalcao = provedorBalcao.dados
            .where((element) => element.id == idvenda)
            .firstOrNull;

        if (vendaBalcao != null) {
          server.write(jsonEncode({
            'tipo': TipoCardapio.balcao.nome,
            'nomeConexao': usuarioProvedor.usuario!.nome,
          }));

          final configuracaoImpressao =
              await Modular.get<ServicoConfigBigchef>()
                  .listar(forcarAtualizacao: true);
          final imprimirPreparoNoComprovante =
              configuracaoImpressao?.imprimePreparoNoComprovanteConsumacao ??
                  provedorCardapio
                      .configBigchef?.imprimePreparoNoComprovanteConsumacao ??
                  false;
          if (configuracaoImpressao != null) {
            provedorCardapio.configBigchef = configuracaoImpressao;
          }

          if (!imprimirPreparoNoComprovante) {
            await Impressao.comprovanteDePedido(
              local: '',
              tipoTela: provedorCardapio.tipo,
              comanda: "Balcão $idvenda",
              numeroPedido: vendaBalcao.numeropedido,
              nomeCliente: (vendaBalcao.nomecliente) == 'Sem Cliente' &&
                      (vendaBalcao.observacaoDoPedido ?? '').isNotEmpty
                  ? (vendaBalcao.observacaoDoPedido ?? '')
                  : (vendaBalcao.nomecliente),
              nomeEmpresa: vendaBalcao.nomeEmpresa,
              produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
              tipodeentrega: vendaBalcao.idtipodeentrega,
            );
          }

          var informacoes = await servico.listarPorId(idvenda);
          var parcelas = await servico.listarFinanceiroVenda(idvenda);

          final duration =
              DateTime.now().difference(DateTime.parse(vendaBalcao.dataHora));
          final newDuration = ConfigSistema.formatarHora(duration);

          Impressao.comprovanteDeConsumo(
            tipoTela: TipoCardapio.balcao,
            agruparPorDestino: false,
            valorentrega: informacoes.informacoes.valorentrega,
            nomeEmpresa: vendaBalcao.nomeEmpresa,
            produtos: informacoes.produtos,
            nomelancamento:
                List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
              return ModeloNomeLancamento(
                  nome: elemento.entradaMov,
                  valor: UtilBrasilFields.converterMoedaParaDouble(
                          elemento.valorMovF)
                      .toStringAsExponential(2));
            })),
            somaValorHistorico: informacoes.informacoes.subtotal,
            cnpjEmpresa: informacoes.informacoes.docempresa,
            celularEmpresa: informacoes.informacoes.celularcliente,
            enderecoEmpresa: informacoes.informacoes.enderecoempresa,
            permanencia: newDuration,
            local: '',
            total: informacoes.informacoes.subtotal,
            numeroPedido: informacoes.informacoes.numerodopedido,
            tipodeentrega: informacoes.informacoes.tipodeentrega,
            nomeCliente: (informacoes.informacoes.nomeCliente == ''
                    ? null
                    : informacoes.informacoes.nomeCliente) ??
                'Sem Cliente',
          );
          FeedbackUsuario.pedidoFinalizado();

          // Impressao.enviarImpressao(
          //   tipoImpressao: '1',
          //   tipo: provedorCardapio.tipo,
          //   comanda: "Balcão ${provedorCardapio.id}",
          //   numeroPedido: vendaBalcao.numeropedido,
          //   nomeCliente: vendaBalcao.nomecliente,
          //   nomeEmpresa: vendaBalcao.nomeEmpresa,
          //   produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
          // );
        }

        carrinhoProvedor.removerComandasPedidos();

        if (mounted) {
          Navigator.popUntil(context, ModalRoute.withName('PaginaBalcao'));
        }
      } else {
        if (context.mounted) {
          provedor.idVenda = idvenda;
          provedor.valor = double.parse(widget.totalReceber) - widget.valor;

          Navigator.popUntil(
              context, ModalRoute.withName('PaginaFinalizarAcrescimo'));
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }

    // if (modelo == null) {
    //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //     content: Text('Ocorreu um Erro: Não Há Venda'),
    //     backgroundColor: Colors.red,
    //     showCloseIcon: true,
    //   ));
    //   finalizando.value = false;
    //   return;
    // }

    // final (sucesso, mensagem) = await context.read<ServicoFinalizarPagamento>().inserir(
    //       SalvarListarVendasModelo(
    //         idVenda: modelo.idVenda,
    //         idCliente: modelo.idCliente,
    //         razaoSocialCliente: modelo.razaoSocialCliente,
    //         idNatureza: modelo.idNatureza,
    //         idVendedor: modelo.idVendedor,
    //         dataLancamento: modelo.dataLancamento,
    //         idTransportadoraNfe: modelo.idTransportadoraNfe,
    //         fretePorContaNfe: modelo.fretePorContaNfe,
    //         placaDoVeiculoNfe: modelo.placaDoVeiculoNfe,
    //         ufDoVeiculoNfe: modelo.ufDoVeiculoNfe,
    //         quantidadeTransNfe: modelo.quantidadeTransNfe,
    //         especieTransNfe: modelo.especieTransNfe,
    //         marcaTransNfe: modelo.marcaTransNfe,
    //         numeracaoTransNfe: modelo.numeracaoTransNfe,
    //         pesoBrutoTransNfe: modelo.pesoBrutoTransNfe,
    //         pesoLiquidoTransNfe: modelo.pesoLiquidoTransNfe,
    //         tipoNfReferenciadaNfe: modelo.tipoNfReferenciadaNfe,
    //         chaveAcessoNfeRefNfe: modelo.chaveAcessoNfeRefNfe,
    //         descricaoDoCliente: modelo.descricaoDoCliente,
    //         observacoesDoCliente: modelo.observacoesDoCliente,
    //         resumoFinal: modelo.resumoFinal,
    //         observacoesInterna: modelo.observacoesInterna,
    //         dadosAdicionais: modelo.dadosAdicionais,
    //         moviDinheiro: widget.dinheiro,
    //         moviPromissoria: widget.promissoria,
    //         moviCartaoDebito: widget.cartaoDebito,
    //         moviCartaoCredito: widget.cartaoCredito,
    //         moviPix: modelo.moviPix,
    //         moviOp2: modelo.moviOp2,
    //         moviOp3: modelo.moviOp3,
    //         moviOp4: modelo.moviOp4,
    //         moviOp5: modelo.moviOp5,
    //         produtos: modelo.produtos,
    //         acrescimo: widget.acrescimo,
    //         data: dataOriginal,
    //         desconto: widget.desconto,
    //         descontoPercentual: widget.descontoPercentual,
    //         docDePessoa: '',
    //         emissaoDeNota: '',
    //         idDescricao: '',
    //         notaFiscal: '',
    //         parcelas: listaParcelas.value.length.toString(),
    //         parcelasLista: listaParcelas.value,
    //         subTotalNovo: widget.totalPedido,
    //         tipoDePessoa: modelo.tipoDePessoa,
    //         totalAReceber: widget.totalReceber,
    //         totalRecebido: '',
    //         valorFalta: widget.valorFalta,
    //         valorTroco: widget.valorTroco,
    //       ),
    //     );

    if (!mounted) return;

    // if (sucesso) {
    //   if (mounted) {
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //   }
    // }

    // if (mounted) {
    //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //     content: Text(mensagem),
    //     backgroundColor: sucesso ? Colors.green : Colors.red,
    //     showCloseIcon: true,
    //     behavior: SnackBarBehavior.floating,
    //   ));
    // }

    finalizando.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelamento'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        backgroundColor:
            DateFormat('yyyy-MM-dd').format(DateTime.parse(dataOriginal)) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now())
                ? null
                : const Color(0xFF4f0073),
        foregroundColor:
            DateFormat('yyyy-MM-dd').format(DateTime.parse(dataOriginal)) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now())
                ? null
                : Colors.white,
        onPressed:
            DateFormat('yyyy-MM-dd').format(DateTime.parse(dataOriginal)) ==
                    DateFormat('yyyy-MM-dd').format(DateTime.now())
                ? null
                : () {
                    finalizar();
                  },
        label: SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: ValueListenableBuilder(
            valueListenable: finalizando,
            builder: (context, finalizandoValue, _) {
              return Visibility(
                visible: finalizandoValue == false,
                replacement: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                ),
                child: const Text('Finalizar', textAlign: TextAlign.center),
              );
            },
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '  ID Cliente: #${provedorCardapio.idCliente}',
                  style: const TextStyle(fontSize: 14),
                ),
                // Row(
                //   children: [
                //     const Icon(Icons.person_outline_outlined, size: 22),
                //     const SizedBox(width: 5),
                //     Text(
                //       _nomeCliente,
                //       style: const TextStyle(fontSize: 15),
                //     ),
                //   ],
                // ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('('),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _selecionarPrazo(_vendaDia1),
                      child: Text('$_vendaDia1 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _selecionarPrazo(_vendaDia2),
                      child: Text('$_vendaDia2 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _selecionarPrazo(_vendaDia3),
                      child: Text('$_vendaDia3 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () => _selecionarPrazo(_vendaDia4),
                      child: Text('$_vendaDia4 dias'),
                    ),
                    const Text(')'),
                  ],
                ),
                TextField(
                  controller: _dataController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: '',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onTap: () async {
                    final DateTime? time = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                      initialDate: dataOriginal.isEmpty
                          ? DateTime.now()
                          : DateTime.parse(dataOriginal),
                    );

                    if (time != null) _definirPrimeiroVencimento(time);
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            // height: 220,
            child: ValueListenableBuilder(
              valueListenable: listaParcelas,
              builder: (context, value, child) => ListView.builder(
                shrinkWrap: true,
                itemCount: value.length,
                padding: const EdgeInsets.only(left: 6, right: 6),
                itemBuilder: (context, index) {
                  final item = value[index];

                  return Card(
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.black
                                  : Colors.white54,
                          width: 0.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (context) => BottomEditarParcelamento(
                              valor: item.valorController?.text ?? '',
                              data: item.vencimentoController?.text ?? '',
                              aoSalvar: (valor, data) {
                                Navigator.pop(context);

                                listaParcelas.value = listaParcelas.value
                                    .asMap()
                                    .map(
                                      (key, value) => key == index
                                          ? MapEntry(
                                              key,
                                              ParcelasModelo(
                                                parcela: (key + 1).toString(),
                                                valor: double.parse(
                                                        valor.isEmpty
                                                            ? '0'
                                                            : valor)
                                                    .toStringAsFixed(2),
                                                vencimento: data,
                                                vencimentoController:
                                                    TextEditingController(
                                                  text: DateFormat('dd/MM/yyyy')
                                                      .format(
                                                          DateTime.parse(data)),
                                                ),
                                                valorController:
                                                    TextEditingController(
                                                  text: double.parse(
                                                          valor.isEmpty
                                                              ? '0'
                                                              : valor)
                                                      .toStringAsFixed(2),
                                                ),
                                              ))
                                          : MapEntry(key, value),
                                    )
                                    .values
                                    .toList();
                              },
                            ),
                          );
                        },
                        borderRadius:
                            const BorderRadius.all(Radius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('Parcela: ${item.parcela}'),
                                  const Spacer(),
                                  const Text('Vencimento'),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Valor: '),
                                  Text(item.valorController?.text
                                          .replaceAll('.', ',') ??
                                      ''),
                                  const Spacer(),
                                  Text(item.vencimentoController?.text ?? ''),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // const Spacer(),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(60), topRight: Radius.circular(60)),
              // color: Theme.of(context).colorScheme.inversePrimary,
              color: Color.fromARGB(255, 237, 232, 246),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '${_parcelas.toString()} Parcela',
                    style: TextStyle(
                        fontSize: 25,
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(
                      left: 30, right: 30, bottom: 15, top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor:
                                          const WidgetStatePropertyAll(
                                              Colors.white),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                    onPressed: _parcelas <= 1
                                        ? null
                                        : () =>
                                            alterarParcelas(incrementar: false),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            size: 26,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.light
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .inversePrimary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Remover',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .inversePrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor:
                                          const WidgetStatePropertyAll(
                                              Colors.white),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                    onPressed: () =>
                                        alterarParcelas(incrementar: true),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 12),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline,
                                            size: 26,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.light
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .inversePrimary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Adicionar',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.light
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .inversePrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Valor à ser Parcelado',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'R\$ ${widget.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
