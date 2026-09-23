import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/managers/app_lifecycle_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class BancoCiclo extends Fake implements Database {}

class ServidorCiclo extends Server {
  int conexoes = 0;
  Completer<bool>? tentativaBloqueada;
  final renovacoes = <bool>[];

  @override
  Future<bool> retomarConexao(String ip, String porta,
      {bool renovarCanal = false}) {
    renovacoes.add(renovarCanal);
    return super.retomarConexao(ip, porta, renovarCanal: renovarCanal);
  }

  @override
  Future<bool> connect(String ip, String porta) async {
    conexoes++;
    if (tentativaBloqueada != null) return tentativaBloqueada!.future;
    connected = true;
    return true;
  }
}

class SincronizadorCiclo extends Sincronizador {
  SincronizadorCiclo(super.api, super.usuario, super.socket)
      : super(banco: BancoLocal(BancoCiclo()));
  int retomadas = 0;
  @override
  void iniciar() {}
  @override
  void solicitar() => retomadas++;
}

class ModuloCiclo extends Module {
  final servidor = ServidorCiclo();
  final usuario = UsuarioProvedor();
  final api = DioCliente();
  late final sync = SincronizadorCiclo(api, usuario, servidor);

  @override
  void binds(Injector i) {
    i.addInstance<Server>(servidor);
    i.addInstance<Sincronizador>(sync);
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('dev.fluttercommunity.plus/connectivity_status');
  late ModuloCiclo modulo;
  final conexao = jsonEncode({
    'tipoConexao': 'local',
    'servidor': 'cozinha',
    'porta': '9980',
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({'conexao': conexao});
    binding.defaultBinaryMessenger
        .setMockMethodCallHandler(canal, (_) async => null);
    modulo = ModuloCiclo();
    Modular.init(modulo);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
    modulo.servidor.dispose();
    modulo.usuario.dispose();
    modulo.api.cliente.close(force: true);
    Modular.destroy();
  });

  testWidgets('pausar preserva canal e voltar solicita sincronizacao',
      (tester) async {
    await tester.pumpWidget(const AppLifecycleObserver(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(modulo.servidor.conexoes, 1);
    expect(modulo.sync.retomadas, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(modulo.servidor.connected, isTrue);
    expect(modulo.servidor.conexoes, 1);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(modulo.servidor.conexoes, 2);
    expect(modulo.servidor.renovacoes, [false, true]);
    expect(modulo.sync.retomadas, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('voltar ao app renova conexao sem aguardar tentativa travada',
      (tester) async {
    final tentativa = Completer<bool>();
    modulo.servidor.tentativaBloqueada = tentativa;
    await tester.pumpWidget(const AppLifecycleObserver(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(modulo.servidor.conexoes, 1);
    modulo.servidor.tentativaBloqueada = null;

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(modulo.servidor.conexoes, 2);
    expect(modulo.servidor.renovacoes, [false, true]);
    expect(modulo.servidor.connected, isTrue);
    tentativa.complete(false);
    await tester.pumpAndSettle();
    expect(modulo.servidor.connected, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('volta do Wi-Fi renova canal mesmo marcado como conectado',
      (tester) async {
    await tester.pumpWidget(const AppLifecycleObserver(child: SizedBox()));
    await tester.pumpAndSettle();
    Future<void> rede(List<String> tipos) async {
      await binding.defaultBinaryMessenger.handlePlatformMessage(canal.name,
          const StandardMethodCodec().encodeSuccessEnvelope(tipos), (_) {});
      await tester.pumpAndSettle();
    }

    await rede(['wifi']);
    await rede(['none']);
    await rede(['wifi']);
    expect(modulo.servidor.renovacoes, [false, false, true, true]);
    expect(modulo.servidor.connected, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('erro do monitor de rede nao trava retomada nem propaga excecao',
      (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('conexao', '{invalido');
    await tester.pumpWidget(const AppLifecycleObserver(child: SizedBox()));
    await tester.pumpAndSettle();
    expect(modulo.sync.retomadas, 1);
    expect(tester.takeException(), isNull);
    await binding.defaultBinaryMessenger.handlePlatformMessage(
        canal.name,
        const StandardMethodCodec()
            .encodeErrorEnvelope(code: 'rede_indisponivel'),
        (_) {});
    await tester.pumpAndSettle();
    expect(modulo.sync.retomadas, 2);
    expect(tester.takeException(), isNull);
    await prefs.setString('conexao', conexao);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(modulo.servidor.conexoes, 1);
    expect(modulo.sync.retomadas, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
