// lib/app_lifecycle_observer.dart

import 'dart:async';
import 'dart:developer';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/managers/push_notification_manager.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart'; // <-- Importe para acessar a navigatorKey

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;

  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver> with WidgetsBindingObserver {
  late final Server server;
  late final PushNotificationManager notificationManager;
  StreamSubscription<RemoteMessage>? _notificationSubscription; // <-- Para nos desinscrevermos

  @override
  void initState() {
    super.initState();
    server = Modular.get<Server>();
    notificationManager = PushNotificationManager(); // Acessa a instância singleton

    WidgetsBinding.instance.addObserver(this);
    _conectarAoServidor();

    // <-- MUDANÇA: Escuta os eventos de notificação
    _notificationSubscription = notificationManager.onNotificationOpened.listen((message) {
      _handleNotificationNavigation(message);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel(); // <-- Cancela a inscrição para evitar memory leaks
    super.dispose();
  }

  void _handleNotificationNavigation(RemoteMessage message) {
    log('Navegando com base na notificação. Dados: ${message.data}');
    // Exemplo: a notificação pode conter dados sobre para onde navegar.
    // O seu servidor desktop, ao enviar a notificação, pode incluir um campo 'tela'.
    final String? tela = message.data['tela'];
    final String? id = message.data['id']; // Ex: ID de uma comanda, mesa, etc.

    if (tela != null && navigatorKey!.currentState != null) {
      switch (tela) {
        case 'comanda':
          // Exemplo de navegação
          // navigatorKey.currentState!.push(MaterialPageRoute(builder: (_) => PaginaDaComanda(id: id)));
          log('Navegação para a tela de comanda com ID: $id');
          break;
        case 'mesa':
          log('Navegação para a tela de mesa com ID: $id');
          break;
        // Adicione outras rotas conforme necessário
      }
    }
  }

  // ... (O resto da classe é o mesmo de antes) ...
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // ... lógica do WebSocket ...
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        log("App em primeiro plano (global). Conectando...");
        _conectarAoServidor();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        log("App em segundo plano (global). Desconectando...");
        server.disconnect();
        break;
    }
  }

  Future<void> _conectarAoServidor() async {
    // ... lógica de conexão ...
    final config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (conexao != null && conexao.servidor.isNotEmpty && conexao.porta.isNotEmpty) {
      await server.connect(conexao.servidor, conexao.porta);
    } else {
      log("Dados de conexão não encontrados.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
