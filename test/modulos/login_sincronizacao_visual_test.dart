import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/pendencias_sincronizacao.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/tema/theme_controller.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'atendimento_test.dart'
    show
        ComandasTeste,
        ConfigBigchefTeste,
        ConfigTeste,
        MesasTeste,
        ServerTeste;
import '../suporte/captura_tela.dart';

class BancoVisual extends Fake implements Database {}

class SincronizadorVisual extends Sincronizador {
  SincronizadorVisual(super.api, super.usuario, super.socket)
      : super(banco: BancoLocal(BancoVisual()));

  void mostrarEstado({bool conectado = true}) {
    escopo = 'sessao-teste';
    online = conectado;
    catalogoPronto = true;
    notifyListeners();
  }

  @override
  Future<List<Map<String, dynamic>>> rascunhosBloqueados() async => [];
}

class AutenticacaoVisual extends Fake implements ServicoAutenticacao {
  final UsuarioProvedor usuario;
  final SincronizadorVisual sync;
  AutenticacaoVisual(this.usuario, this.sync);

  @override
  Future<bool> entrar(
    String? usuario,
    String? senha, {
    bool permitirSessaoSalva = false,
    CancelToken? cancelToken,
    Duration tempoLimite = const Duration(seconds: 8),
  }) async {
    this.usuario.setUsuario(UsuarioModelo(
        id: '1', empresa: '1', nome: 'Atendente', nomeEmpresa: 'Restaurante'));
    sync.mostrarEstado();
    return true;
  }
}

class ModuloLoginVisual extends Module {
  final usuario = UsuarioProvedor();
  final server = ServerTeste();
  final api = DioCliente();
  final tema = ThemeController();
  final comandas = ProvedorComanda(ComandasTeste());
  final mesas = ProvedorMesas(MesasTeste());
  late final sync = SincronizadorVisual(api, usuario, server);

  @override
  void binds(Injector i) {
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<Server>(server);
    i.addInstance<ThemeController>(tema);
    i.addInstance<ProvedorComanda>(comandas);
    i.addInstance<ProvedorMesas>(mesas);
    i.addInstance<ConfigProvider>(ConfigProvider());
    i.addInstance<ServicoAutenticacao>(AutenticacaoVisual(usuario, sync));
    i.addInstance<ServicoConfigBigchef>(ConfigBigchefTeste());
    i.addInstance<ServicoConfig>(ConfigTeste());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late ModuloLoginVisual modulo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Garcom',
        packageName: 'app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '');
    modulo = ModuloLoginVisual();
    Modular.init(modulo);
    app.usuarioProvedor = modulo.usuario;
    app.navigatorKey = GlobalKey<NavigatorState>();
    Sincronizador.instancia = modulo.sync;
  });
  tearDown(() {
    modulo.sync.dispose();
    modulo.server.dispose();
    modulo.api.cliente.close(force: true);
    modulo.usuario.dispose();
    modulo.tema.dispose();
    modulo.comandas.dispose();
    modulo.mesas.dispose();
    Modular.destroy();
  });

  for (final largura in [320.0, 393.0, 1024.0]) {
    testWidgets('login e navegacao com icone flutuante na largura $largura',
        (tester) async {
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 59);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await tester.pumpWidget(const RepaintBoundary(
        key: ValueKey('captura'),
        child: app.AppWidget(),
      ));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'atendente');
      await tester.enterText(find.byType(TextField).last, 'senha-teste');
      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Início'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final indicador = find.byTooltip('Pedidos sincronizados');
      expect(indicador, findsOneWidget);
      final areaIndicador = tester.getRect(indicador);
      expect(areaIndicador.top, greaterThanOrEqualTo(59));
      expect(areaIndicador.bottom, lessThanOrEqualTo(59 + kToolbarHeight));
      expect(areaIndicador.center.dy, closeTo(59 + kToolbarHeight / 2, 0.1));
      expect(
        areaIndicador.right,
        lessThanOrEqualTo(largura - EstadoSincronizacao.recuoDireitaCabecalho),
      );
      await capturarTela(tester, 'sincronizacao_inicio_$largura');
      await tester.longPress(indicador);
      await tester.pumpAndSettle();
      expect(find.text('Pedidos sincronizados'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Tooltip.dismissAllToolTips();
      await tester.pumpAndSettle();

      await tester.tap(indicador);
      await tester.pumpAndSettle();
      expect(find.text('Envio dos pedidos'), findsOneWidget);
      final sincronizar = find.byTooltip('Sincronizar agora');
      expect(tester.getRect(sincronizar).right,
          lessThanOrEqualTo(tester.getRect(indicador).left));
      app.navigatorKey!.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsOneWidget);

      for (final pagina in ['Comandas', 'Mesas']) {
        await tester.tap(find.text(pagina));
        await tester.pumpAndSettle();
        final menu = find.widgetWithIcon(IconButton, Icons.more_horiz);
        final areaMenu = tester.getRect(menu);
        expect(areaMenu.right, lessThanOrEqualTo(areaIndicador.left));
        expect(areaMenu.center.dy, closeTo(areaIndicador.center.dy, 0.1));
        expect(tester.getRect(find.byType(TextField)).overlaps(areaIndicador),
            isFalse);
        expect(tester.takeException(), isNull);
        await capturarTela(tester, 'sincronizacao_${pagina}_$largura');
        await tester.tap(menu);
        await tester.pumpAndSettle();
        expect(
            find.text(
                pagina == 'Comandas' ? 'Todas as comandas' : 'Todas as mesas'),
            findsOneWidget);
        await tester.tap(menu);
        await tester.pumpAndSettle();
        app.navigatorKey!.currentState!.pop();
        await tester.pumpAndSettle();
      }

      modulo.sync.mostrarEstado(conectado: false);
      modulo.tema.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sem conexao com o servidor'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      await tester.tap(find.text('Comandas'));
      await tester.pumpAndSettle();
      expect(
          tester
              .getRect(find.widgetWithIcon(IconButton, Icons.more_horiz))
              .right,
          lessThanOrEqualTo(areaIndicador.left));
      await capturarTela(tester, 'sincronizacao_comandas_escuro_$largura');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }
}
