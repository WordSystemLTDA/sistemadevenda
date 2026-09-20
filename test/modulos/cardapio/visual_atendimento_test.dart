import 'dart:async';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_abrir_mesa.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import '../atendimento_test.dart' show ConfigBigchefTeste;
import 'montagem_pizza_test.dart' show ConfiguracoesTeste;

class ConfigVisual extends ConfiguracoesTeste {
  ConfigVisual() : super('media');
  @override
  String get habilitarVerValorTotalNoApp => 'Sim';
}

class DadosVisual extends Fake implements ServicoCardapio {
  bool falhar = false;
  bool fechamento = false;
  bool transferida = false;
  TipoCardapio? consultado;
  Completer<Modeloworddadoscardapio>? pendente;
  @override
  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode}) async {
    consultado = tipo;
    if (falhar) throw StateError('Sem conexao');
    return pendente == null
        ? Modeloworddadoscardapio(
            id: id,
            idComanda: tipo == TipoCardapio.mesa ? '0' : '4',
            idMesa: tipo == TipoCardapio.mesa ? '4' : '0',
            idCliente: '0',
            nomeCliente: 'Sem Cliente',
            observacaoDoPedido: 'Bruno Masson',
            nome: '${tipo.nome}: 4',
            nomeMesa: '',
            status: transferida
                ? 'Transferida'
                : fechamento
                    ? 'Fechamento'
                    : 'Andamento',
            numeroPedido: '46',
            valorTotal: '167.00',
            dataAbertura: DateTime.now()
                .subtract(const Duration(minutes: 13))
                .toIso8601String(),
          )
        : await pendente!.future;
  }
}

class MesasVisual extends Fake implements ProvedorMesas {
  List<String>? abertura;
  List<String>? edicao;
  bool falhar = false;
  @override
  String? get erro => 'Sem conexao';
  @override
  Future<({bool sucesso, String idcomandapedido})> inserirMesaOcupada(
      String idMesa, String idCliente, String obs) async {
    abertura = [idMesa, idCliente, obs];
    if (falhar) throw StateError('Queda');
    return (sucesso: true, idcomandapedido: 'local:mesa-teste');
  }

  @override
  Future<bool> editarMesaOcupada(
      String id, String idMesa, String idCliente, String obs) async {
    edicao = [id, idMesa, idCliente, obs];
    return true;
  }
}

class ComandasVisual extends Fake implements ProvedorComanda {
  List<String>? abertura;
  @override
  Future<({bool sucesso, String idcomandapedido})> inserirComandaOcupada(
      String id, String mesa, String cliente, String obs) async {
    abertura = [id, mesa, cliente, obs];
    return (sucesso: true, idcomandapedido: 'local:comanda-teste');
  }

  @override
  Future<List<dynamic>> listarClientes(String busca) async => [
        {'id': '9', 'nome': 'Cliente cadastrado'},
      ];
  @override
  Future<List<dynamic>> listarMesas(String busca) async => [
        {'id': '3', 'nome': 'Mesa: 3'},
      ];
}

class ModuloVisual extends Module {
  final dados = DadosVisual();
  final mesas = MesasVisual();
  final comandas = ComandasVisual();
  final server = Server();
  final usuario = UsuarioProvedor()
    ..setUsuario(
        UsuarioModelo(nome: 'Atendente', configuracoes: ConfigVisual()));
  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(dados);
    i.addInstance<ProvedorMesas>(mesas);
    i.addInstance<ProvedorComanda>(comandas);
    i.addInstance<Server>(server);
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<ServicoConfigBigchef>(ConfigBigchefTeste());
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  late ModuloVisual modulo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    modulo = ModuloVisual();
    Modular.init(modulo);
    app.usuarioProvedor = modulo.usuario;
  });
  tearDown(() {
    modulo.server.dispose();
    modulo.usuario.dispose();
    Modular.destroy();
  });

  Future<void> abrir(WidgetTester tester, Widget pagina,
      {Size tela = const Size(393, 852),
      double escala = 1,
      bool escuro = false}) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('captura'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: escuro ? Brightness.dark : Brightness.light),
          appBarTheme:
              const AppBarThemeData(actionsPadding: EdgeInsets.only(right: 60)),
        ),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => Navigator.push(
                          context, MaterialPageRoute(builder: (_) => pagina)),
                      child: const Text('Atendimentos')),
                )),
      ),
    ));
    await tester.tap(find.text('Atendimentos'));
    await tester.pumpAndSettle();
  }

  for (final tipo in [TipoCardapio.mesa, TipoCardapio.comanda]) {
    testWidgets('$tipo transferida nao oferece lancamento ou fechamento',
        (tester) async {
      modulo.dados.transferida = true;
      await abrir(
          tester, PaginaDetalhesPedido(idComandaPedido: '104', tipo: tipo));
      expect(find.text('Atendimento transferido'), findsOneWidget);
      expect(find.text('Histórico de transferências'), findsOneWidget);
      expect(find.text('Adicionar produtos'), findsNothing);
      expect(find.text('Fechar conta'), findsNothing);
      expect(find.text('Reabrir'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    for (final (tela, escala, escuro) in [
      (const Size(393, 852), 1.0, false),
      (const Size(320, 568), 2.0, false),
      (const Size(800, 1024), 1.3, true),
    ]) {
      for (final detalhes in [false, true]) {
        testWidgets(
            '${tipo.name} detalhes=$detalhes ${tela.width} fonte=$escala',
            (tester) async {
          await abrir(
              tester,
              detalhes
                  ? PaginaDetalhesPedido(idComandaPedido: '104', tipo: tipo)
                  : PaginaComandaDesocupada(
                      id: '4', nome: '${tipo.nome}: 4', tipo: tipo),
              tela: tela,
              escala: escala,
              escuro: escuro);
          expect(tester.takeException(), isNull);
          await capturarTela(tester,
              'etapa3_${tipo.name}_${detalhes ? 'detalhes' : 'abertura'}_${tela.width.toInt()}');
          if (detalhes) {
            expect(find.text('Bruno Masson'), findsOneWidget);
            await tester.scrollUntilVisible(
                find.text('Adicionar produtos'), 120,
                scrollable: find.byType(Scrollable).last);
            expect(find.text('Adicionar produtos'), findsOneWidget);
          } else {
            if (tipo == TipoCardapio.comanda) {
              await tester.scrollUntilVisible(find.text('Selecionar mesa'), 120,
                  scrollable: find.byType(Scrollable).last);
            }
            expect(find.text('Selecionar mesa'),
                tipo == TipoCardapio.comanda ? findsOneWidget : findsNothing);
          }
          await tester.pumpWidget(const SizedBox());
        });
      }
    }

    testWidgets(
        'abrir ${tipo.name} preserva observacao sem cadastro de cliente',
        (tester) async {
      await abrir(
          tester,
          PaginaComandaDesocupada(
              id: '4', nome: '${tipo.nome}: 4', tipo: tipo));
      await tester.enterText(find.byType(TextField), 'Bruno Masson');
      await tester.tap(find.widgetWithText(FilledButton, 'Abrir ${tipo.name}'));
      await tester.pumpAndSettle();
      expect(
          tipo == TipoCardapio.mesa
              ? modulo.mesas.abertura
              : modulo.comandas.abertura,
          tipo == TipoCardapio.mesa
              ? ['4', '0', 'Bruno Masson']
              : ['4', '0', '0', 'Bruno Masson']);
      expect(find.text('Atendimentos'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final tipo in [TipoCardapio.mesa, TipoCardapio.comanda]) {
    testWidgets('abertura de ${tipo.name} foca nome observacao ao abrir',
        (tester) async {
      await abrir(
          tester,
          PaginaComandaDesocupada(
              id: '4', nome: '${tipo.nome}: 4', tipo: tipo));
      final campo = tester.widget<TextField>(
          find.byKey(const Key('observacao_abertura_atendimento')));
      expect(campo.focusNode?.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('pagina dedicada de mesa foca observacao ao abrir',
      (tester) async {
    await abrir(tester, const PaginaAbrirMesa(id: '4', nome: 'Mesa: 4'));
    final campo = tester
        .widget<TextField>(find.byKey(const Key('observacao_abertura_mesa')));
    expect(campo.focusNode?.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('seleciona mesa apos abertura do teclado da busca',
      (tester) async {
    await abrir(
        tester,
        const PaginaComandaDesocupada(
            id: '4', nome: 'Comanda: 4', tipo: TipoCardapio.comanda));

    await tester.tap(find.text('Selecionar mesa'));
    await tester.pumpAndSettle();
    expect(find.text('Mesa: 3'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mesa: 3'));
    await tester.pumpAndSettle();

    expect(find.text('Mesa: 3'), findsOneWidget);
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir comanda'));
    await tester.pumpAndSettle();
    expect(modulo.comandas.abertura, ['4', '3', '0', '']);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'editar mesa abre formulario correto e atualiza detalhes ao voltar',
      (tester) async {
    await abrir(
        tester,
        const PaginaDetalhesPedido(
            idComandaPedido: '104', tipo: TipoCardapio.mesa));
    await tester.tap(find.text('Editar Mesa'));
    await tester.pumpAndSettle();
    final form = tester
        .widget<PaginaComandaDesocupada>(find.byType(PaginaComandaDesocupada));
    expect(form.id, '4');
    expect(form.idComandaPedido, '104');
    expect(modulo.dados.consultado, TipoCardapio.mesa);
    expect(find.text('Bruno Masson'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Cliente mesa 4');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar alterações'));
    await tester.pumpAndSettle();
    expect(modulo.mesas.edicao, ['104', '4', '0', 'Cliente mesa 4']);
    expect(find.byType(PaginaDetalhesPedido), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('formulario permite repetir consulta e salvar apos falha',
      (tester) async {
    modulo.dados.falhar = true;
    await abrir(
        tester,
        const PaginaComandaDesocupada(
            id: '4',
            idComandaPedido: '104',
            nome: 'Mesa: 4',
            tipo: TipoCardapio.mesa));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Salvar alterações'), findsNothing);
    modulo.dados.falhar = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar alterações'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('erro na abertura libera botao para nova tentativa',
      (tester) async {
    modulo.mesas.falhar = true;
    await abrir(
        tester,
        const PaginaComandaDesocupada(
            id: '4', nome: 'Mesa: 4', tipo: TipoCardapio.mesa));
    await tester.tap(find.widgetWithText(FilledButton, 'Abrir mesa'));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Abrir mesa'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('conta em fechamento oferece reabertura', (tester) async {
    modulo.dados.fechamento = true;
    await abrir(
        tester,
        const PaginaDetalhesPedido(
            idComandaPedido: '104', tipo: TipoCardapio.comanda));
    expect(find.text('Reabrir'), findsOneWidget);
    expect(find.text('Fechar conta'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  test('nome do preparo prioriza cadastro e usa observacao quando ausente', () {
    expect(nomeClienteAtendimento(null, ' Bruno Masson '), 'Bruno Masson');
    expect(nomeClienteAtendimento('Sem Cliente', 'Bruno'), 'Bruno');
    expect(nomeClienteAtendimento('sem cliente', 'Bruno'), 'Bruno');
    expect(nomeClienteAtendimento('Ana', 'Sem cebola'), 'Ana');
    expect(nomeClienteAtendimento('', '', vazio: ''), '');
  });
}
