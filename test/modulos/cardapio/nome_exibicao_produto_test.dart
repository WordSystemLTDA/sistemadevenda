import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/uteis/nome_exibicao_produto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ModeloDadosOpcoesPacotes sabor(String nome,
          {String? codigo, bool imprimirCodigo = false}) =>
      ModeloDadosOpcoesPacotes(
        id: '101',
        nome: nome,
        codigo: codigo,
        imprimirCodigoProdutoPreparo: imprimirCodigo ? 'Sim' : 'Não',
      );

  test('mantem nome usual e codigo conforme a configuracao', () {
    expect(nomeSaborPizza(sabor('Mussarela')), 'Mussarela');
    expect(nomeSaborPizza(sabor('Mussarela', codigo: '003')), 'Mussarela');
    expect(
        nomeSaborPizza(sabor('Mussarela', codigo: '003', imprimirCodigo: true)),
        '003 - Mussarela');
    expect(nomeSaborPizza(sabor('Mussarela', imprimirCodigo: true), '1/3'),
        '(1/3) Mussarela');
    expect(nomeSaborPizza(sabor('4 Queijos'), '1/3'), '(1/3) 4 Queijos');
  });

  test('nome preparado e idempotente com ou sem codigo', () {
    for (final imprimirCodigo in [false, true]) {
      final original =
          sabor('Mussarela', codigo: '003', imprimirCodigo: imprimirCodigo);
      final esperado =
          imprimirCodigo ? '003 - (1/3) Mussarela' : '(1/3) Mussarela';
      final primeiro = nomeSaborPizza(original, '1/3');
      expect(primeiro, esperado);
      final preparado =
          sabor(primeiro, codigo: '003', imprimirCodigo: imprimirCodigo);
      expect(nomeSaborPizza(preparado, '1/3'), esperado);
      expect(nomeSaborPizza(preparado), esperado);
    }
  });

  test('preserva fracao serializada e nao repete codigo existente', () {
    expect(nomeSaborPizza(sabor('(2/3) Mussarela'), '1/2'), '(2/3) Mussarela');
    expect(nomeSaborPizza(sabor('003 - (2/3) Mussarela'), '1/2'),
        '003 - (2/3) Mussarela');
    expect(
        nomeSaborPizza(
            sabor('003 - Mussarela', codigo: '003', imprimirCodigo: true),
            '1/3'),
        '003 - (1/3) Mussarela');
  });
}
