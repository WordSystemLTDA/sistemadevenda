import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicosCategoriaTeste extends Fake implements ServicosCategoria {
  @override
  Future<List<ModeloCategoria>> listar() async => [];
}

class ServicosItensComandaTeste extends Fake implements ServicosItensComanda {}

class ModuloItensRecorrentesTeste extends Module {
  late final usuarioProvedor = UsuarioProvedor()
    ..setUsuario(UsuarioModelo(
      id: '275',
      empresa: '32',
      nome: 'Atendente',
      nomeEmpresa: 'Restaurante',
    ));
  late final provedorItensRecorrentes =
      ProvedorItensRecorrentes(ServicosItensComandaTeste());
  late final provedorCardapio =
      ProvedorCardapio(ServicosCategoriaTeste(), usuarioProvedor);

  @override
  void binds(Injector i) {
    i.addInstance<UsuarioProvedor>(usuarioProvedor);
    i.addInstance<ProvedorItensRecorrentes>(provedorItensRecorrentes);
    i.addInstance<ProvedorCardapio>(provedorCardapio);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModuloItensRecorrentesTeste modulo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    modulo = ModuloItensRecorrentesTeste();
    Modular.init(modulo);
  });

  tearDown(Modular.destroy);

  test('produto aceita id_itens_venda vindo da api', () {
    final produto = _pizzaRecorrente().toMap();
    produto.remove('iditensvenda');
    produto['id_itens_venda'] = 987;

    expect(Modelowordprodutos.fromMap(produto).iditensvenda, '987');
  });

  testWidgets('pizza recorrente mostra montagem e relanca copia exata',
      (tester) async {
    final pizza = _pizzaRecorrente();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardItensRecorrentes(
          estaPesquisando: false,
          searchController: null,
          item: pizza,
          categoria: null,
          finalizar: true,
          idComanda: '3',
          idMesa: '0',
          idComandaPedido: '10673',
        ),
      ),
    ));

    expect(find.text('Pizza de Queijos'), findsOneWidget);
    expect(find.text('Tamanho Pizza'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
    expect(find.text('(1/3) Mussarela'), findsOneWidget);
    expect(find.text('(1/3) Catupiry Especial'), findsOneWidget);
    expect(find.text('(1/3) Dois Quijos'), findsOneWidget);
    expect(find.text('Selecione as Bordas'), findsOneWidget);
    expect(find.text('Catupiry'), findsOneWidget);
    expect(find.text('Goiabada'), findsOneWidget);
    expect(find.text('Selecione os Adicionais'), findsOneWidget);
    expect(find.text('1x Ervilha'), findsOneWidget);
    expect(find.text('1x Bacon'), findsOneWidget);
    expect(find.text('Selecione os Itens Para Retirar'), findsOneWidget);
    expect(find.text('Cebola'), findsOneWidget);
    expect(find.text('Observação'), findsOneWidget);
    expect(find.text('Sem cebola e cortar bem assada'), findsOneWidget);

    await tester.tap(find.byType(CardItensRecorrentes));
    await tester.pumpAndSettle();

    expect(modulo.provedorItensRecorrentes.itensCarrinho, hasLength(1));
    final relancada = modulo.provedorItensRecorrentes.itensCarrinho.single;
    expect(relancada.nome, 'Pizza de Queijos');
    expect(relancada.valorVenda, '77.00');
    expect(relancada.observacao, 'Sem cebola e cortar bem assada');

    final opcoes = relancada.opcoesPacotesListaFinal!;
    expect(
        opcoes.where((opcao) => opcao.id == 9).single.dados!.single.nome, 'G');
    expect(
      opcoes
          .where((opcao) => opcao.id == 10)
          .single
          .dados!
          .map((dado) => dado.nome),
      ['Mussarela', 'Catupiry Especial', 'Dois Quijos'],
    );
    expect(
      opcoes
          .where((opcao) => opcao.id == 6)
          .single
          .dados!
          .map((dado) => dado.nome),
      ['Catupiry', 'Goiabada'],
    );
    expect(
      opcoes
          .where((opcao) => opcao.id == 7)
          .single
          .dados!
          .map((dado) => dado.nome),
      ['Ervilha', 'Bacon'],
    );
    expect(
      opcoes
          .where((opcao) => opcao.id == 8)
          .single
          .dados!
          .map((dado) => dado.nome),
      ['Cebola'],
    );
  });
}

Modelowordprodutos _pizzaRecorrente() {
  return Modelowordprodutos(
    id: '1',
    iditensvenda: '10673',
    nome: 'Pizza de Queijos',
    codigo: '1',
    estoque: '0',
    tamanho: '',
    foto: '',
    ativo: 'Sim',
    descricao: '',
    valorVenda: '77.00',
    categoria: '47',
    nomeCategoria: 'Pizza de Queijos',
    dataLancado:
        DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
    habilTipo: 'Pacote',
    ingredientes: [],
    quantidade: 1,
    observacao: 'Sem cebola e cortar bem assada',
    opcoesPacotesListaFinal: [
      ModeloOpcoesPacotes(
        id: 9,
        titulo: 'Tamanho Pizza',
        tipo: 1,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '3',
            nome: 'G',
            valor: '58.00',
          ),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 10,
        titulo: 'Sabores Pizza (3)',
        tipo: 1,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '1',
            nome: 'Mussarela',
            valor: '19.00',
            quantimaximaselecao: '1/3',
          ),
          ModeloDadosOpcoesPacotes(
            id: '2',
            nome: 'Catupiry Especial',
            valor: '19.00',
            quantimaximaselecao: '1/3',
          ),
          ModeloDadosOpcoesPacotes(
            id: '3',
            nome: 'Dois Quijos',
            valor: '20.00',
            quantimaximaselecao: '1/3',
          ),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 6,
        titulo: 'Selecione as Bordas',
        tipo: 4,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '10',
            nome: 'Catupiry',
            valor: '12.00',
          ),
          ModeloDadosOpcoesPacotes(
            id: '11',
            nome: 'Goiabada',
            valor: '12.00',
          ),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 7,
        titulo: 'Selecione os Adicionais',
        tipo: 3,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '20',
            nome: 'Ervilha',
            valor: '3.00',
            quantidade: 1,
          ),
          ModeloDadosOpcoesPacotes(
            id: '21',
            nome: 'Bacon',
            valor: '4.00',
            quantidade: 1,
          ),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 8,
        titulo: 'Selecione os Itens Para Retirar',
        tipo: 4,
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
            id: '30',
            nome: 'Cebola',
            valor: '0.00',
          ),
        ],
      ),
    ],
  );
}
