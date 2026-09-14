import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cardapio/montagem_pizza_test.dart' show DioClienteTeste;

class ServicosCategoriaTeste extends Fake implements ServicosCategoria {
  @override
  Future<List<ModeloCategoria>> listar() async => [];
}

class ModuloItensRecorrentesTeste extends Module {
  late final usuarioProvedor = UsuarioProvedor()
    ..setUsuario(UsuarioModelo(
      id: '275',
      empresa: '32',
      nome: 'Atendente',
      nomeEmpresa: 'Restaurante',
    ));
  late final provedorItensRecorrentes = ProvedorItensRecorrentes(
      ServicosItensComanda(DioClienteTeste(), usuarioProvedor));
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

  for (final (largura, escala) in [(800.0, 1.0), (320.0, 1.0), (320.0, 2.0)]) {
    testWidgets(
        'pizza recorrente mostra montagem e relanca copia exata em $largura escala $escala',
        (tester) async {
      tester.view.physicalSize = Size(largura, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final chamadasHapticas = _capturarFeedbackHaptico();
      final pizza = _pizzaRecorrente(meiaBorda: true);

      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CardItensRecorrentes(
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
        ),
      ));

      expect(find.text('Pizza de Queijos'), findsOneWidget);
      expect(find.text('Detalhes'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.text('Tamanho Pizza'), findsNothing);
      expect(modulo.provedorItensRecorrentes.itensCarrinho, isEmpty);

      await tester.ensureVisible(
          find.byKey(const Key('botao_detalhes_pizza_recorrente')));
      await tester
          .tap(find.byKey(const Key('botao_detalhes_pizza_recorrente')));
      await tester.pumpAndSettle();

      expect(modulo.provedorItensRecorrentes.itensCarrinho, isEmpty);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.text('Tamanho Pizza'), findsOneWidget);
      expect(find.text('G'), findsOneWidget);
      expect(find.text('(1/3) Mussarela'), findsOneWidget);
      expect(find.text('(1/3) Catupiry Especial'), findsOneWidget);
      expect(find.text('(1/3) Dois Quijos'), findsOneWidget);
      expect(find.text('Selecione as Bordas'), findsOneWidget);
      expect(find.text('Meio - (1/4) Catupiry'), findsOneWidget);
      expect(find.text('Meio - (1/4) Goiabada'), findsOneWidget);
      expect(find.text('Selecione os Adicionais'), findsOneWidget);
      expect(find.text('1x Ervilha'), findsOneWidget);
      expect(find.text('1x Bacon'), findsOneWidget);
      expect(find.text('Selecione os Itens Para Retirar'), findsOneWidget);
      expect(find.text('Cebola'), findsOneWidget);
      expect(find.text('Observação'), findsOneWidget);
      expect(find.text('Sem cebola e cortar bem assada'), findsOneWidget);

      await tester.ensureVisible(
          find.byKey(const Key('botao_detalhes_pizza_recorrente')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const Key('botao_detalhes_pizza_recorrente')));
      await tester.pumpAndSettle();

      expect(modulo.provedorItensRecorrentes.itensCarrinho, isEmpty);
      expect(find.text('Tamanho Pizza'), findsNothing);
      expect(find.text('Detalhes'), findsNothing);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      await tester.ensureVisible(find.text('Pizza de Queijos'));
      await tester.tap(find.text('Pizza de Queijos'));
      await tester.pumpAndSettle();

      expect(modulo.provedorItensRecorrentes.itensCarrinho, hasLength(1));
      expect(
        chamadasHapticas
            .where((chamada) =>
                chamada.arguments == 'HapticFeedbackType.heavyImpact')
            .length,
        1,
      );
      final relancada = modulo.provedorItensRecorrentes.itensCarrinho.single;
      expect(relancada.nome, 'Pizza de Queijos');
      expect(relancada.valorVenda, '77.00');
      expect(relancada.observacao, 'Sem cebola e cortar bem assada');

      final opcoes = relancada.opcoesPacotesListaFinal!;
      expect(opcoes.where((opcao) => opcao.id == 9).single.dados!.single.nome,
          'G');
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
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('selecionar sabor de pizza em itens recorrentes vibra',
      (tester) async {
    final chamadasHapticas = _capturarFeedbackHaptico();
    modulo.provedorCardapio.tamanhosPizza = ModeloTamanhosPizza(
      id: 'G',
      nomedotamanho: 'G',
      quantpedacos: '8',
      saboreslimite: '3',
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardItensRecorrentes(
          estaPesquisando: false,
          searchController: null,
          item: _pizzaRecorrente(),
          categoria: null,
          finalizar: true,
          idComanda: '3',
          idMesa: '0',
          idComandaPedido: '10673',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pizza de Queijos'));
    await tester.pump();

    expect(modulo.provedorCardapio.saboresPizzaSelecionados, hasLength(1));
    expect(
      chamadasHapticas
          .where((chamada) =>
              chamada.arguments == 'HapticFeedbackType.mediumImpact')
          .length,
      1,
    );
    expect(modulo.provedorItensRecorrentes.itensCarrinho, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'carrinho recorrente mostra sabores da pizza e codigos habilitados',
      (tester) async {
    final pizza = _pizzaRecorrente(meiaBorda: true);
    final sabores = pizza.opcoesPacotesListaFinal!
        .where((opcao) => opcao.id == 10)
        .single
        .dados!;
    sabores[0] = ModeloDadosOpcoesPacotes(
      id: '1',
      nome: 'Mussarela',
      codigo: '1',
      imprimirCodigoProdutoPreparo: 'Sim',
      valor: '19.00',
      quantimaximaselecao: '1/3',
    );
    sabores[1] = ModeloDadosOpcoesPacotes(
      id: '2',
      nome: 'Catupiry Especial',
      codigo: '2',
      imprimirCodigoProdutoPreparo: 'Sim',
      valor: '19.00',
      quantimaximaselecao: '1/3',
    );
    sabores[2] = ModeloDadosOpcoesPacotes(
      id: '3',
      nome: 'Dois Quijos',
      codigo: '3',
      imprimirCodigoProdutoPreparo: 'Sim',
      valor: '20.00',
      quantimaximaselecao: '1/3',
    );

    const nomePizza =
        '1 - (1/3) Mussarela\n2 - (1/3) Catupiry Especial\n3 - (1/3) Dois Quijos';

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: CardCarrinhoItensRecorrentes(
            item: pizza,
            index: 0,
            idComanda: '3',
            idComandaPedido: '10673',
            idMesa: '0',
            value: null,
            setarQuantidade: (_) {},
          ),
        ),
      ),
    ));

    expect(find.text('Pizza de Queijos'), findsNothing);
    expect(find.text(nomePizza), findsOneWidget);

    await tester.tap(find.byTooltip('Mostrar detalhes'));
    await tester.pumpAndSettle();

    expect(find.text('Sabores Pizza (3)'), findsOneWidget);
    expect(find.text('1 - (1/3) Mussarela'), findsOneWidget);
    expect(find.text('2 - (1/3) Catupiry Especial'), findsOneWidget);
    expect(find.text('3 - (1/3) Dois Quijos'), findsOneWidget);
    expect(find.text('Meio (1/2)'), findsOneWidget);
    expect(find.text('Meio - (1/4) Catupiry'), findsOneWidget);
    expect(find.text('Meio - (1/4) Goiabada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

List<MethodCall> _capturarFeedbackHaptico() {
  final chamadas = <MethodCall>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
    if (methodCall.method == 'HapticFeedback.vibrate') {
      chamadas.add(methodCall);
    }
    return null;
  });
  addTearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  return chamadas;
}

Modelowordprodutos _pizzaRecorrente({bool meiaBorda = false}) {
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
            somenteMetadeBorda: meiaBorda,
          ),
          ModeloDadosOpcoesPacotes(
            id: '11',
            nome: 'Goiabada',
            valor: '12.00',
            somenteMetadeBorda: meiaBorda,
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
