import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/tema/theme_controller.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'atendimento_test.dart'
    show ConfigBigchefTeste, ConfigTeste, ServerTeste;

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
  late final sync = SincronizadorVisual(api, usuario, server);

  @override
  void binds(Injector i) {
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<Server>(server);
    i.addInstance<ThemeController>(tema);
    i.addInstance<ConfigProvider>(ConfigProvider());
    i.addInstance<ServicoAutenticacao>(AutenticacaoVisual(usuario, sync));
    i.addInstance<ServicoConfigBigchef>(ConfigBigchefTeste());
    i.addInstance<ServicoConfig>(ConfigTeste());
  }
}

void main() {
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
    Modular.destroy();
  });

  for (final largura in [393.0, 1024.0]) {
    testWidgets('login e navegacao com icone flutuante na largura $largura',
        (tester) async {
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const app.AppWidget());
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
      await tester.longPress(indicador);
      await tester.pumpAndSettle();
      expect(find.text('Pedidos sincronizados'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Tooltip.dismissAllToolTips();
      await tester.pumpAndSettle();

      await tester.tap(indicador);
      await tester.pumpAndSettle();
      expect(find.text('Envio dos pedidos'), findsOneWidget);
      app.navigatorKey!.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsOneWidget);

      modulo.sync.mostrarEstado(conectado: false);
      modulo.tema.value = ThemeMode.dark;
      await tester.pumpAndSettle();
      expect(find.byTooltip('Sem conexao com o servidor'), findsOneWidget);
      expect(find.text('Início'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
