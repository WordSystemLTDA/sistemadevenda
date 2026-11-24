import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';

ModeloOpcoesPacotes grupo(int limite, {bool obrigatorio = false}) =>
    ModeloOpcoesPacotes(
        id: 13,
        tipo: 9,
        titulo: 'Opções',
        obrigatorio: obrigatorio,
        limiteSelecao: limite,
        idCategoriaOpcoes: '1',
        dados: []);
ModeloDadosOpcoesPacotes opcao(int id) => ModeloDadosOpcoesPacotes(
    id: '$id',
    nome: 'Opção $id',
    valor: '$id.00',
    quantidade: 7,
    estaSelecionado: false);
void main() {
  test(
      'escolha única substitui a anterior e obrigatório conserva a escolha atual',
      () {
    final g = grupo(1, obrigatorio: true);
    expect(g.validarOpcoes(), isNotNull);
    g.alternarOpcao(opcao(1));
    g.alternarOpcao(opcao(2));
    expect(g.dados!.map((d) => d.id), ['2']);
    g.alternarOpcao(opcao(2));
    expect(g.dados!.single.quantidade, 1);
    expect(g.dados!.single.estaSelecionado, isTrue);
    expect(g.validarOpcoes(), isNull);
  });
  for (final limite in [2, 3, 4]) {
    test('limite $limite permite remover e substituir sem exceder a categoria',
        () {
      final g = grupo(limite);
      for (var i = 1; i <= limite; i++) {
        expect(g.alternarOpcao(opcao(i)), isNull);
      }
      expect(g.alternarOpcao(opcao(6)), isNotNull);
      expect(g.dados!, hasLength(limite));
      g.alternarOpcao(opcao(1));
      expect(g.alternarOpcao(opcao(6)), isNull);
      expect(g.dados!.map((d) => d.id), contains('6'));
    });
  }
  test('Livre não limita e reabrir preserva regras e escolhas', () {
    final g = grupo(0, obrigatorio: true);
    for (var i = 1; i <= 9; i++) {
      g.alternarOpcao(opcao(i));
    }
    final copia = ModeloOpcoesPacotes.fromJson(g.toJson());
    expect(copia.limiteOpcoes, 0);
    expect(copia.idCategoriaOpcoes, '1');
    expect(copia.dados, hasLength(9));
    expect(copia.validarOpcoes(), isNull);
    expect(copia.toMap(), g.toMap());
  });
  test(
      'grupo opcional pode ficar vazio e dados legados não recebem novas regras',
      () {
    final g = grupo(1);
    g.alternarOpcao(opcao(1));
    g.alternarOpcao(opcao(1));
    expect(g.dados, isEmpty);
    expect(g.validarOpcoes(), isNull);
    final legado = ModeloOpcoesPacotes.fromMap(
        {'id': 5, 'titulo': 'Acompanhamentos', 'dados': []});
    expect(legado.toMap().containsKey('limiteSelecao'), isFalse);
    expect(legado.ehCategoriaOpcoes, isFalse);
  });
}
