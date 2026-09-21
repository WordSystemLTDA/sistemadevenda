import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_acompanhar_pedido.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/uteis/agrupamento_itens_pedido.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Modelowordprodutos _produto({
  required String id,
  required String codigo,
  required String nome,
  required String valor,
}) {
  return Modelowordprodutos(
    id: codigo,
    iditensvenda: id,
    nome: nome,
    codigo: codigo,
    estoque: '0',
    tamanho: '',
    foto: '',
    ativo: 'Sim',
    descricao: '',
    valorVenda: valor,
    categoria: '1',
    nomeCategoria: 'Bebidas',
    dataLancado: '2026-09-21T10:47:45',
    habilTipo: '',
    ingredientes: const [],
    quantidade: 1,
  );
}

class _ServicoCardapioAgrupamento extends Fake implements ServicoCardapio {
  @override
  Future<Modeloworddadoscardapio> listarPorId(
    String id,
    TipoCardapio tipo,
    String mostraritens, {
    String? codigoQrcode,
  }) async {
    return Modeloworddadoscardapio(
      id: '138',
      idComanda: '3',
      status: 'Andamento',
      nome: 'Comanda: 3',
      nomeCliente: '',
      numeroPedido: '138',
      produtos: [
        _produto(
            id: '1',
            codigo: '100',
            nome: 'Água Tônica Schweppes Lata',
            valor: '6.00'),
        _produto(
            id: '2',
            codigo: '100',
            nome: 'Água Tônica Schweppes Lata',
            valor: '6.00'),
        _produto(
            id: '3',
            codigo: '100',
            nome: 'Água Tônica Schweppes Lata',
            valor: '6.00'),
        _produto(
            id: '4', codigo: '200', nome: 'Suco de Laranja', valor: '10.00'),
      ],
    );
  }
}

class _ServicoConfigAgrupamento extends Fake implements ServicoConfigBigchef {
  @override
  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async {
    return null;
  }
}

class _ModuloAgrupamento extends Module {
  final servidor = Server();

  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(_ServicoCardapioAgrupamento());
    i.addInstance<ServicoConfigBigchef>(_ServicoConfigAgrupamento());
    i.addInstance<Server>(servidor);
    i.addInstance<UsuarioProvedor>(UsuarioProvedor());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _ModuloAgrupamento modulo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    modulo = _ModuloAgrupamento();
    Modular.init(modulo);
  });

  tearDown(() {
    modulo.servidor.dispose();
    Modular.destroy();
  });

  Future<void> abrirTela(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: PaginaAcompanharPedido(
        tipo: TipoCardapio.comanda,
        idComanda: '3',
        idComandaPedido: '138',
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('agrupa, salva e restaura a preferência da tela de detalhes',
      (tester) async {
    await abrirTela(tester);

    final botao = find.byKey(const ValueKey('agrupar_itens_iguais'));
    expect(find.byType(CardProdutoAcompanhar), findsNWidgets(4));
    expect(tester.widget<FilterChip>(botao).selected, isFalse);

    await tester.tap(botao);
    await tester.pumpAndSettle();

    final cardsAgrupados = tester
        .widgetList<CardProdutoAcompanhar>(find.byType(CardProdutoAcompanhar))
        .toList();
    expect(cardsAgrupados, hasLength(2));
    expect(cardsAgrupados.first.item.codigo, '100');
    expect(cardsAgrupados.first.item.quantidade, 3);
    expect(tester.widget<FilterChip>(botao).selected, isTrue);
    expect(find.textContaining('desative “Agrupar iguais”'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance())
          .getBool(PreferenciaAgrupamentoItensPedido.chave),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await abrirTela(tester);

    expect(find.byType(CardProdutoAcompanhar), findsNWidgets(2));
    expect(tester.widget<FilterChip>(botao).selected, isTrue);

    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(find.byType(CardProdutoAcompanhar), findsNWidgets(4));
    expect(tester.widget<FilterChip>(botao).selected, isFalse);
    expect(
      (await SharedPreferences.getInstance())
          .getBool(PreferenciaAgrupamentoItensPedido.chave),
      isFalse,
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
