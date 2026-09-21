import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/uteis/agrupamento_itens_pedido.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Modelowordprodutos produto({
  required String idItem,
  String observacao = '',
  String sabor = '',
}) {
  return Modelowordprodutos(
    id: '100',
    iditensvenda: idItem,
    nome: 'Água Tônica Schweppes Lata',
    codigo: '100',
    estoque: '0',
    tamanho: '',
    foto: '',
    ativo: 'Sim',
    descricao: '',
    valorVenda: '6.00',
    categoria: '1',
    nomeCategoria: 'Bebidas',
    habilTipo: '',
    ingredientes: const [],
    quantidade: 1,
    observacao: observacao,
    opcoesPacotesListaFinal: sabor.isEmpty
        ? null
        : [
            ModeloOpcoesPacotes(
              id: 11,
              titulo: 'Sabor',
              obrigatorio: true,
              dados: [
                ModeloDadosOpcoesPacotes(id: sabor, nome: sabor, valor: '0'),
              ],
            ),
          ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('soma as quantidades somente de produtos realmente iguais', () {
    final itens = [
      produto(idItem: '1'),
      produto(idItem: '2'),
      produto(idItem: '3'),
      produto(idItem: '4', observacao: 'Sem gelo'),
      produto(idItem: '5', sabor: 'Limão'),
      produto(idItem: '6', sabor: 'Laranja'),
    ];

    final grupos = organizarItensPedido(itens, agrupar: true);

    expect(grupos, hasLength(4));
    expect(grupos.first.produto.quantidade, 3);
    expect(grupos.first.itensOriginais, hasLength(3));
    expect(grupos.first.possuiMaisDeUmLancamento, isTrue);
    expect(
        grupos.skip(1).every((grupo) => grupo.produto.quantidade == 1), isTrue);
  });

  test('mantém todos os lançamentos separados quando a opção está desligada',
      () {
    final grupos = organizarItensPedido(
      [produto(idItem: '1'), produto(idItem: '2'), produto(idItem: '3')],
      agrupar: false,
    );

    expect(grupos, hasLength(3));
    expect(grupos.every((grupo) => !grupo.possuiMaisDeUmLancamento), isTrue);
  });

  test('salva a preferência de agrupamento no aparelho', () async {
    final preferencia = PreferenciaAgrupamentoItensPedido();

    expect(await preferencia.carregar(), isFalse);
    expect(await preferencia.salvar(true), isTrue);
    expect(await preferencia.carregar(), isTrue);
    expect(
      (await SharedPreferences.getInstance())
          .getBool(PreferenciaAgrupamentoItensPedido.chave),
      isTrue,
    );
  });
}
