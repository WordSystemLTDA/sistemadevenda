import 'dart:convert';

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/uteis/montagem_cardapio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mais cobra uma vez por ingrediente e reverte sem perder embalagem', () {
    var item = ModeloDadosOpcoesPacotes.fromMap(
        {'id': '1', 'nome': 'Arroz', 'valor_adicional_mais': '2.75'});
    var montagem = const MontagemIngredienteCardapio(
        nomeOriginal: 'Arroz', acao: AcaoIngredienteCardapio.mais);
    item = MontagemCardapio.aplicar(item, montagem);
    expect(item.valor, '2.75');
    expect(item.montagemCardapio!.valorAdicionalMais, '2.75');
    item = MontagemCardapio.aplicar(item, item.montagemCardapio!);
    expect(item.valor, '2.75');
    montagem = item.montagemCardapio!
        .copyWith(separado: true, valorEmbalagemSeparada: '5.00');
    item = MontagemCardapio.aplicar(item, montagem);
    expect(item.valor, '7.75');
    final salvo = ModeloDadosOpcoesPacotes.fromJson(item.toJson());
    expect(salvo.montagemCardapio!.valorAdicionalMais, '2.75');
    expect(salvo.valorAdicionalMais, '2.75');
    for (final acao in [
      AcaoIngredienteCardapio.normal,
      AcaoIngredienteCardapio.pouco,
      AcaoIngredienteCardapio.trocar
    ]) {
      final removido =
          MontagemCardapio.aplicar(item, montagem.copyWith(acao: acao));
      expect(removido.valor, '5.00');
      expect(removido.montagemCardapio!.valorAdicionalMais, '0.00');
    }
    final gratuito =
        ModeloDadosOpcoesPacotes.fromMap({'id': '2', 'nome': 'Feijão'});
    expect(
        MontagemCardapio.aplicar(
                gratuito,
                const MontagemIngredienteCardapio(
                    nomeOriginal: 'Feijão', acao: AcaoIngredienteCardapio.mais))
            .valor,
        '0');
  });

  test('reabrir pedido conserva snapshot e permite Mais com preco do catalogo',
      () {
    final disponivel = ModeloDadosOpcoesPacotes.fromMap(
        {'id': '1', 'nome': 'Arroz', 'valorAdicionalMais': '4.00'});
    final normalSalvo = MontagemCardapio.iniciar([
      ModeloDadosOpcoesPacotes.fromMap({'id': '1', 'nome': 'Arroz'})
    ]).single;
    final normalReaberto =
        MontagemCardapio.iniciar([disponivel], salvos: [normalSalvo]).single;
    final mais = MontagemCardapio.aplicar(
        normalReaberto,
        normalReaberto.montagemCardapio!
            .copyWith(acao: AcaoIngredienteCardapio.mais));
    expect(mais.valor, '4.00');
    final antigo = ModeloDadosOpcoesPacotes.fromMap({
      'id': '1',
      'nome': 'MAIS Arroz',
      'valor': '2.75',
      'montagemCardapio': {
        'acao': 'mais',
        'nomeOriginal': 'Arroz',
        'valorAdicionalMais': '2.75'
      }
    });
    expect(
        MontagemCardapio.iniciar([disponivel], salvos: [antigo]).single.valor,
        '2.75');
  });

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

  test('configuracao le o valor da embalagem separada', () {
    expect(
      ModeloConfigBigchef.fromMap({
        'valorembalagemseparada': '5.50',
      }).valorembalagemseparada,
      '5.50',
    );
    expect(
      ModeloConfigBigchef.fromMap({
        'valor_embalagem_separada': '4.25',
      }).valorembalagemseparada,
      '4.25',
    );
  });

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
        'valorEmbalagemSeparada': '5.00',
      }),
    });

    expect(dado.idCategoriaCardapio, '9');
    expect(dado.diaSemana, 'quinta');
    expect(dado.montagemCardapio!.acao, AcaoIngredienteCardapio.mais);
    expect(dado.montagemCardapio!.valorEmbalagemSeparada, '5.00');
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
    expect(ingrediente['montagemCardapio']['valorEmbalagemSeparada'], '5.00');
  });

  test('embalagem separada agrega uma tarifa por ingrediente', () {
    final item = MontagemCardapio.aplicar(
      ingredientes().first,
      const MontagemIngredienteCardapio(
        nomeOriginal: 'Arroz',
        separado: true,
        valorEmbalagemSeparada: '5.00',
      ),
    );

    expect(item.valor, '5.00');
    expect(item.montagemCardapio!.separado, isTrue);
    expect(
      ModeloDadosOpcoesPacotes.fromMap(item.toMap())
          .montagemCardapio!
          .valorEmbalagemSeparada,
      '5.00',
    );
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
