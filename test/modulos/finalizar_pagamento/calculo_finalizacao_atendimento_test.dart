import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:flutter_test/flutter_test.dart';

Modelowordprodutos produto({
  String total = '0',
  String valor = '0',
  String pago = '0',
  double quantidade = 1,
}) =>
    Modelowordprodutos(
      id: '1',
      nome: 'Produto',
      codigo: '100',
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: valor,
      valorTotalVendas: total,
      valorPago: pago,
      categoria: '1',
      nomeCategoria: 'Categoria',
      habilTipo: '',
      ingredientes: const [],
      quantidade: quantidade,
    );

void main() {
  test('divide por pessoa preservando os centavos na ultima cota', () {
    expect(
        parcelaAtualEmCentavos(
            totalCentavos: 1000, pagoCentavos: 0, pessoas: 3),
        333);
    expect(
        parcelaAtualEmCentavos(
            totalCentavos: 1000, pagoCentavos: 333, pessoas: 3),
        333);
    expect(
        parcelaAtualEmCentavos(
            totalCentavos: 1000, pagoCentavos: 666, pessoas: 3),
        334);
  });

  test('produto parcial considera total e o valor que ja foi pago', () {
    final primeiro = produto(total: '18.00', valor: '6', pago: '6');
    final segundo = produto(valor: '10', pago: '2', quantidade: 2);

    expect(saldoProdutoEmCentavos(primeiro), 1200);
    expect(saldoProdutoEmCentavos(segundo), 1800);
    expect(totalProdutosSelecionadosEmCentavos([primeiro, segundo]), 3000);
  });

  test('le valores brasileiros e valores decimais da API', () {
    expect(numeroMonetario('R\$ 1.234,56'), 1234.56);
    expect(numeroMonetario('1234.56'), 1234.56);
    expect(saldoEmCentavos(total: '85.00', pago: '18,50'), 6650);
  });

  test('permissoes de mesa e comanda sao independentes e seguras por padrao',
      () {
    final padrao = ModeloConfigBigchef.fromMap(const {});
    expect(padrao.permiteFinalizarMesa, isFalse);
    expect(padrao.permiteFinalizarComanda, isFalse);

    final config = ModeloConfigBigchef.fromMap({
      'permitir_finalizar_mesa': 'Sim',
      'permitirfinalizarcomanda': 'Não',
    });
    expect(config.permiteFinalizarMesa, isTrue);
    expect(config.permiteFinalizarComanda, isFalse);
    expect(config.toMap()['permitirfinalizarmesa'], 'Sim');
  });
}
