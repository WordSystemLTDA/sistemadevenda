import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';

void main() {
  ModeloOpcoesPacotes grupo(List<Map<String, dynamic>> dados, {int id = 4}) =>
      ModeloOpcoesPacotes.fromMap({'id': id, 'dados': dados});

  test('ordem salva prevalece sobre ID e preserva tamanho selecionado e preço',
      () {
    final tamanho = grupo([
      {'id': '5', 'nome': '300ml', 'ordem': '2', 'valor': '20'},
      {
        'id': '9',
        'nome': '200ml',
        'ordem': 1,
        'valor': '15',
        'estaSelecionado': true
      },
      {'id': '7', 'nome': '500ml', 'ordem': 3},
    ]);
    expect(tamanho.dados!.map((e) => e.id), ['9', '5', '7']);
    expect(tamanho.dados!.first.estaSelecionado, true);
    expect(tamanho.dados!.first.valor, '15');
    final copia = ModeloOpcoesPacotes.fromMap(tamanho.toMap());
    expect(copia.dados!.map((e) => e.ordem), [1, 2, 3]);
    expect(copia.dados!.first.estaSelecionado, true);
  });

  test(
      'tamanhos novos ficam depois dos configurados, mantendo empates estáveis',
      () {
    final tamanho = grupo([
      {'id': '9'},
      {'id': '5', 'ordem': 0},
      {'id': '7', 'ordem': 2},
      {'id': '8', 'ordem': '2'},
      {'id': '10', 'ordem': 'invalida'},
    ]);
    expect(tamanho.dados!.map((e) => e.id), ['7', '8', '9', '5', '10']);
  });

  test('resposta antiga conserva sequência e outros grupos não são reordenados',
      () {
    expect(
        grupo([
          {'id': '9'},
          {'id': '5'}
        ]).dados!.map((e) => e.id),
        ['9', '5']);
    expect(
        grupo([
          {'id': '5', 'ordem': 2},
          {'id': '9', 'ordem': 1}
        ], id: 12)
            .dados!
            .map((e) => e.id),
        ['5', '9']);
    expect(grupo([]).dados, isEmpty);
  });

  for (final id in [1, 5, 6, 7, 8, 11]) {
    test('grupo $id aplica ordem compartilhada sem mudar valores ou selecao',
        () {
      final opcoes = grupo([
        {'id': '101', 'ordem': 2, 'valor': '8'},
        {'id': '102', 'ordem': 1, 'valor': '3', 'estaSelecionado': true},
      ], id: id);
      expect(opcoes.dados!.map((e) => e.id), ['102', '101']);
      expect(opcoes.dados!.first.valor, '3');
      expect(opcoes.dados!.first.estaSelecionado, true);
    });
  }

  test('grupos internos também recuperam a ordem ao desserializar', () {
    final pacote = ModeloOpcoesPacotes.fromMap({
      'id': 2,
      'opcoesPacote': [
        {
          'id': 4,
          'dados': [
            {'id': '5', 'ordem': 2},
            {'id': '9', 'ordem': 1}
          ]
        }
      ],
    });
    expect(pacote.opcoesPacote!.single.dados!.map((e) => e.id), ['9', '5']);
  });
}
