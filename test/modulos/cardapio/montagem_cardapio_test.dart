import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/uteis/montagem_cardapio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<ModeloDadosOpcoesPacotes> ingredientes() => [
        ModeloDadosOpcoesPacotes(
          id: '1',
          nome: 'Arroz',
          valor: '0',
          idCategoriaCardapio: '4',
          diaSemana: 'quinta',
        ),
        ModeloDadosOpcoesPacotes(
          id: '2',
          nome: 'Carne de Panela',
          valor: '0',
          idCategoriaCardapio: '4',
          diaSemana: 'quinta',
        ),
        ModeloDadosOpcoesPacotes(
          id: '3',
          nome: 'Feijão',
          valor: '0',
          idCategoriaCardapio: '4',
          diaSemana: 'quinta',
        ),
      ];

  test(
      'montagem inicia normal, aplica alteracoes e reabre pelas escolhas salvas',
      () {
    final itens = MontagemCardapio.iniciar(ingredientes());
    expect(
      itens.map((item) => item.montagemCardapio!.acao),
      everyElement(AcaoIngredienteCardapio.normal),
    );

    itens[0] = MontagemCardapio.aplicar(
      itens[0],
      const MontagemIngredienteCardapio(
        nomeOriginal: 'Arroz',
        acao: AcaoIngredienteCardapio.pouco,
      ),
    );
    itens[1] = MontagemCardapio.aplicar(
      itens[1],
      const MontagemIngredienteCardapio(
        nomeOriginal: 'Carne de Panela',
        acao: AcaoIngredienteCardapio.trocar,
        destinoTipo: 'adicional',
        destinoId: '8',
        destinoNome: 'Ovo',
        quantidadeTroca: 2,
        separado: true,
      ),
    );

    expect(itens[0].nome, 'POUCO Arroz');
    expect(itens[1].nome, 'TROCAR Carne de Panela POR 2x Ovo (SEPARADO)');

    final reabertos = MontagemCardapio.iniciar(ingredientes(), salvos: itens);
    expect(reabertos.map((item) => item.nome), [
      'POUCO Arroz',
      'TROCAR Carne de Panela POR 2x Ovo (SEPARADO)',
      'Feijão',
    ]);
    expect(reabertos[1].montagemCardapio!.destinoNome, 'Ovo');
    expect(reabertos[1].montagemCardapio!.separado, isTrue);
  });

  test('serializacao aceita chaves do banco e preserva montagem para envio',
      () {
    final dado = ModeloDadosOpcoesPacotes.fromMap({
      'id': '1',
      'nome': 'Arroz',
      'valor': '0',
      'categoria_cardapio': '9',
      'dia_semana': 'quinta',
      'montagem_json': jsonEncode({
        'nomeOriginal': 'Arroz',
        'acao': 'mais',
        'separado': true,
      }),
    });

    expect(dado.idCategoriaCardapio, '9');
    expect(dado.diaSemana, 'quinta');
    expect(dado.montagemCardapio!.acao, AcaoIngredienteCardapio.mais);
    expect(dado.toMap()['montagemCardapio'], isA<Map<String, dynamic>>());

    final produto = Modelowordprodutos(
      id: '151',
      nome: 'Almoço Livre',
      codigo: '151',
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '45.00',
      categoria: 'Almoço',
      nomeCategoria: 'Almoço',
      habilTipo: '',
      idCategoriaCardapio: '9',
      ingredientes: const [],
      observacao: 'Caprichar',
      opcoesPacotesListaFinal: [
        ModeloOpcoesPacotes(
          id: 12,
          titulo: 'Ingredientes do Cardápio',
          tipo: 8,
          obrigatorio: false,
          dados: [dado],
        ),
        montarGrupoObservacaoProduto('Caprichar'),
      ],
    );
    final produtoDoBanco = Modelowordprodutos.fromMap({
      ...produto.toMap(),
      'idCategoriaCardapio': null,
      'categoriaCardapio': null,
      'id_categoria_cardapio': null,
      'categoria_cardapio': '9',
    });
    expect(produtoDoBanco.idCategoriaCardapio, '9');

    final envio = normalizarProdutoParaEnvio(produto.toMap());
    final grupos = envio['opcoesPacotesListaFinal'] as List;
    expect(grupos, hasLength(1));
    expect((grupos.single as Map)['id'], 12);
    final ingrediente = (grupos.single as Map)['dados'].single as Map;
    expect(ingrediente['id_categoria_cardapio'], '9');
    expect(ingrediente['categoria_cardapio'], '9');
    expect(ingrediente['montagemCardapio']['acao'], 'mais');
    expect(ingrediente['montagemCardapio']['separado'], isTrue);
  });

  test('permissoes do banco removem a acao sem e sobrevivem a serializacao',
      () {
    final arroz = ModeloDadosOpcoesPacotes.fromMap({
      'id': '6',
      'nome': 'Arroz',
      'permitir_sem': 'Não',
      'permitir_pouco': 'Sim',
      'permitir_normal': 'Sim',
      'permitir_mais': 'Sim',
      'permitir_trocar': 'Sim',
    });

    expect(arroz.permiteMontagemCardapio(AcaoIngredienteCardapio.sem), isFalse);
    expect(
        arroz.permiteMontagemCardapio(AcaoIngredienteCardapio.pouco), isTrue);
    expect(
      ModeloDadosOpcoesPacotes.fromMap(arroz.toMap())
          .permiteMontagemCardapio(AcaoIngredienteCardapio.sem),
      isFalse,
    );

    final iniciado = MontagemCardapio.iniciar([arroz]).single;
    expect(iniciado.montagemCardapio!.acao, AcaoIngredienteCardapio.normal);

    final salvoInvalido = MontagemCardapio.aplicar(
      arroz,
      const MontagemIngredienteCardapio(
        nomeOriginal: 'Arroz',
        acao: AcaoIngredienteCardapio.sem,
      ),
    );
    final reaberto =
        MontagemCardapio.iniciar([arroz], salvos: [salvoInvalido]).single;
    expect(reaberto.montagemCardapio!.acao, AcaoIngredienteCardapio.normal);
  });

  test('validacao bloqueia troca para ingrediente removido ou ja trocado', () {
    final itens = MontagemCardapio.iniciar(ingredientes());
    itens[1] = MontagemCardapio.aplicar(
      itens[1],
      const MontagemIngredienteCardapio(
        nomeOriginal: 'Carne de Panela',
        acao: AcaoIngredienteCardapio.sem,
      ),
    );

    expect(
      MontagemCardapio.validarTroca(itens, '1', '2', 'ingrediente'),
      'Este ingrediente não pode receber troca agora.',
    );
    expect(MontagemCardapio.validarTroca(itens, '1', '8', 'adicional'), isNull);
  });
}
