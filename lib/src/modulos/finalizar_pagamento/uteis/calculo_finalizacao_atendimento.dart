import 'dart:math' as math;

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

enum ModoRecebimentoAtendimento { contaInteira, porPessoa, porProduto }

double numeroMonetario(Object? valor) {
  if (valor is num) return valor.toDouble();
  var texto = (valor ?? '').toString().trim().replaceAll('R\$', '').trim();
  if (texto.contains(',') && texto.contains('.')) {
    texto = texto.replaceAll('.', '').replaceAll(',', '.');
  } else {
    texto = texto.replaceAll(',', '.');
  }
  return double.tryParse(texto) ?? 0;
}

int centavosMonetarios(Object? valor) => (numeroMonetario(valor) * 100).round();

double valorDosCentavos(int centavos) => centavos / 100;

int saldoEmCentavos({required Object? total, required Object? pago}) =>
    math.max(0, centavosMonetarios(total) - centavosMonetarios(pago));

int parcelaAtualEmCentavos({
  required int totalCentavos,
  required int pagoCentavos,
  required int pessoas,
}) {
  if (totalCentavos <= 0) return 0;
  final pagoLimitado = pagoCentavos.clamp(0, totalCentavos).toInt();
  final restante = totalCentavos - pagoLimitado;
  if (restante <= 0 || pessoas <= 1) return restante;

  final parcelaBase = totalCentavos ~/ pessoas;
  if (parcelaBase <= 0) return restante;

  final limitePrimeirasPessoas = parcelaBase * (pessoas - 1);
  if (pagoLimitado >= limitePrimeirasPessoas) return restante;

  final pagoNaParcelaAtual = pagoLimitado % parcelaBase;
  return math.min(parcelaBase - pagoNaParcelaAtual, restante);
}

/// Calcula a parcela da pessoa atual sem redistribuir produtos adicionados
/// depois que a divisao da conta comecou.
///
/// [valorBaseDivisaoCentavos] e o saldo congelado no primeiro recebimento e
/// [pessoasPagasDivisao] e a quantidade de cotas originais ja concluidas.
/// [divisaoLegada] conserva a regra de contas antigas sem base persistida.
int parcelaDivisaoPersistidaEmCentavos({
  required int totalAtualCentavos,
  required int pagoCentavos,
  required int pessoas,
  int? valorBaseDivisaoCentavos,
  int pessoasPagasDivisao = 0,
  bool divisaoLegada = false,
}) {
  if (valorBaseDivisaoCentavos == null || valorBaseDivisaoCentavos <= 0) {
    return parcelaAtualEmCentavos(
      totalCentavos: divisaoLegada
          ? totalAtualCentavos
          : math.max(0, totalAtualCentavos - pagoCentavos),
      pagoCentavos: divisaoLegada ? pagoCentavos : 0,
      pessoas: pessoas,
    );
  }

  if (totalAtualCentavos <= 0) return 0;
  final pagoLimitado = pagoCentavos.clamp(0, totalAtualCentavos).toInt();
  final restante = totalAtualCentavos - pagoLimitado;
  if (restante <= 0 || pessoas <= 1) return restante;

  final base = math.max(0, valorBaseDivisaoCentavos);
  final pagas = pessoasPagasDivisao.clamp(0, pessoas).toInt();
  if (pagas >= pessoas) return restante;

  final parcelaBase = base ~/ pessoas;
  final pessoaAtual = pagas + 1;
  final baseAcumulada =
      pessoaAtual == pessoas ? base : parcelaBase * pessoaAtual;
  final alteracoesDepoisDaDivisao = totalAtualCentavos - base;
  final devido = baseAcumulada + alteracoesDepoisDaDivisao - pagoLimitado;
  return devido.clamp(0, restante).toInt();
}

int totalProdutoEmCentavos(Modelowordprodutos produto) {
  final totalInformado = centavosMonetarios(produto.valorTotalVendas);
  if (totalInformado > 0) return totalInformado;
  return (centavosMonetarios(produto.valorVenda) * (produto.quantidade ?? 1))
      .round();
}

int saldoProdutoEmCentavos(Modelowordprodutos produto) => math.max(
      0,
      totalProdutoEmCentavos(produto) - centavosMonetarios(produto.valorPago),
    );

int totalProdutosSelecionadosEmCentavos(
  Iterable<Modelowordprodutos> produtos,
) =>
    produtos.fold(
        0, (total, produto) => total + saldoProdutoEmCentavos(produto));
