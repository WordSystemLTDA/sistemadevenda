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
