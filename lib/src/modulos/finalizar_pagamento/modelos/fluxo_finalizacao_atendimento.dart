import 'dart:math' as math;

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';

enum ResultadoFluxoAtendimento { registrado, finalizou, recarregar }

class FluxoFinalizacaoAtendimento {
  final String idAtendimento;
  final String idComanda;
  final String idMesa;
  final String idCliente;
  final String titulo;
  final TipoCardapio tipo;
  final ModoRecebimentoAtendimento modo;
  final int quantidadePessoas;
  final List<Modelowordprodutos> produtosSelecionados;
  final int valorBaseCentavos;
  final int valorPagoCentavos;
  final int valorDescontoCentavos;
  final int valorAcrescimoCentavos;
  final String valorTaxaServico;
  final String valorEntrega;
  final String tipoEntrega;
  final int? valorBaseDivisaoCentavos;
  final int pessoasPagasDivisao;

  const FluxoFinalizacaoAtendimento({
    required this.idAtendimento,
    required this.idComanda,
    required this.idMesa,
    required this.idCliente,
    required this.titulo,
    required this.tipo,
    required this.modo,
    required this.quantidadePessoas,
    required this.produtosSelecionados,
    required this.valorBaseCentavos,
    required this.valorPagoCentavos,
    required this.valorDescontoCentavos,
    required this.valorAcrescimoCentavos,
    required this.valorTaxaServico,
    this.valorEntrega = '0',
    this.tipoEntrega = '0',
    this.valorBaseDivisaoCentavos,
    this.pessoasPagasDivisao = 0,
  });

  int get valorTotalCentavos => math.max(
        0,
        valorBaseCentavos + valorAcrescimoCentavos - valorDescontoCentavos,
      );

  int get saldoCentavos => math.max(0, valorTotalCentavos - valorPagoCentavos);

  int get valorPagamentoCentavos {
    switch (modo) {
      case ModoRecebimentoAtendimento.contaInteira:
        return saldoCentavos;
      case ModoRecebimentoAtendimento.porPessoa:
        return parcelaDivisaoPersistidaEmCentavos(
          totalAtualCentavos: valorTotalCentavos,
          pagoCentavos: valorPagoCentavos,
          pessoas: quantidadePessoas,
          valorBaseDivisaoCentavos: valorBaseDivisaoCentavos,
          pessoasPagasDivisao: pessoasPagasDivisao,
        );
      case ModoRecebimentoAtendimento.porProduto:
        return math.min(
          saldoCentavos,
          totalProdutosSelecionadosEmCentavos(produtosSelecionados),
        );
    }
  }

  FluxoFinalizacaoAtendimento comAjustes({
    required int descontoCentavos,
    required int acrescimoCentavos,
  }) {
    return FluxoFinalizacaoAtendimento(
      idAtendimento: idAtendimento,
      idComanda: idComanda,
      idMesa: idMesa,
      idCliente: idCliente,
      titulo: titulo,
      tipo: tipo,
      modo: modo,
      quantidadePessoas: quantidadePessoas,
      produtosSelecionados: produtosSelecionados,
      valorBaseCentavos: valorBaseCentavos,
      valorPagoCentavos: valorPagoCentavos,
      valorDescontoCentavos: descontoCentavos,
      valorAcrescimoCentavos: acrescimoCentavos,
      valorTaxaServico: valorTaxaServico,
      valorEntrega: valorEntrega,
      tipoEntrega: tipoEntrega,
      valorBaseDivisaoCentavos: valorBaseDivisaoCentavos,
      pessoasPagasDivisao: pessoasPagasDivisao,
    );
  }
}
