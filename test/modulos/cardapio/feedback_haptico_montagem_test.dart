import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montagem_pizza_test.dart'
    show
        CategoriasTeste,
        ConfiguracoesTeste,
        ModuloTeste,
        ProdutosTeste,
        configBigchef,
        sabor,
        tamanho;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UsuarioProvedor usuario;
  late ProvedorCardapio cardapio;
  late ProdutosTeste produtos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(configuracoes: ConfiguracoesTeste('media')));
    produtos = ProdutosTeste();
    cardapio = ProvedorCardapio(CategoriasTeste(), usuario);
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
  });

  tearDown(() {
    Modular.destroy();
    cardapio.dispose();
    usuario.dispose();
  });

  testWidgets('selecionar sabor de pizza vibra', (tester) async {
    final chamadasHapticas = _capturarFeedbackHaptico();
    final categoria = ModeloCategoria(
      id: 'Queijos',
      nomeCategoria: 'Queijos',
      quantidadeProdutos: '1',
      tamanhosPizza: [tamanho('G')],
    );
    final produto = sabor('Mussarela', 'Queijos', '57');
    cardapio.tamanhosPizza = tamanho('G');

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardProduto(
          estaPesquisando: false,
          item: produto,
          categoria: categoria,
          finalizar: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CardProduto));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 1);

    await tester.tap(find.byType(CardProduto));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selecionar borda, adicional e item retirado vibra',
      (tester) async {
    final chamadasHapticas = _capturarFeedbackHaptico();
    final provedorProduto = Modular.get<ProvedorProduto>();
    cardapio.configBigchef = configBigchef();
    cardapio.tamanhosPizza = tamanho('G');

    final cheddar = ModeloDadosOpcoesPacotes(
      id: '10',
      nome: 'Cheddar',
      valor: '12.00',
    );
    final adicional = ModeloDadosOpcoesPacotes(
      id: '20',
      nome: 'Ervilha',
      valor: '3.00',
      quantidade: 1,
    );
    final retirada = ModeloDadosOpcoesPacotes(
      id: '30',
      nome: 'Cebola',
      valor: '0.00',
    );
    final opcaoBorda = ModeloOpcoesPacotes(
      id: 6,
      titulo: 'Selecione as Bordas',
      tipo: 4,
      obrigatorio: false,
      dados: [cheddar],
    );
    final opcaoAdicional = ModeloOpcoesPacotes(
      id: 7,
      titulo: 'Selecione os Adicionais',
      tipo: 3,
      obrigatorio: false,
      dados: [adicional],
    );
    final opcaoRetirada = ModeloOpcoesPacotes(
      id: 8,
      titulo: 'Selecione os Itens Para Retirar',
      tipo: 4,
      obrigatorio: false,
      dados: [retirada],
    );
    provedorProduto.opcoesPacotesListaFinal = [
      ModeloOpcoesPacotes(
        id: 6,
        titulo: opcaoBorda.titulo,
        tipo: opcaoBorda.tipo,
        obrigatorio: false,
        dados: [],
      ),
      ModeloOpcoesPacotes(
        id: 7,
        titulo: opcaoAdicional.titulo,
        tipo: opcaoAdicional.tipo,
        obrigatorio: false,
        dados: [],
      ),
      ModeloOpcoesPacotes(
        id: 8,
        titulo: opcaoRetirada.titulo,
        tipo: opcaoRetirada.tipo,
        obrigatorio: false,
        dados: [],
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: provedorProduto,
            builder: (context, _) => Column(
              children: [
                const ListaBordas(),
                CardOpcoesPacotes(
                  kit: false,
                  opcoesPacote: opcaoBorda,
                  item: cheddar,
                  idProduto: '0',
                ),
                CardOpcoesPacotes(
                  kit: false,
                  opcoesPacote: opcaoAdicional,
                  item: adicional,
                  idProduto: '0',
                ),
                CardOpcoesPacotes(
                  kit: false,
                  opcoesPacote: opcaoRetirada,
                  item: retirada,
                  idProduto: '0',
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1 sabor'));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 1);

    await tester.tap(find.text('Cheddar'));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 2);

    await tester.tap(find.text('Ervilha'));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 3);

    await tester.tap(find.byIcon(Icons.add_circle_outline));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 4);

    await tester.tap(find.text('Cebola'));
    await _aguardarFeedback(tester);
    expect(_selecoes(chamadasHapticas), 5);
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

Future<void> _aguardarFeedback(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(Duration.zero);
}

int _selecoes(List<MethodCall> chamadas) {
  return chamadas
      .where(
          (chamada) => chamada.arguments == 'HapticFeedbackType.mediumImpact')
      .length;
}
