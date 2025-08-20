// lib/managers/push_notification_manager.dart

import 'dart:async';
import 'dart:developer';

import 'package:firebase_messaging/firebase_messaging.dart';

// Esta função precisa ser de alto nível (fora de uma classe)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  log("Notificação em Background recebida: ${message.messageId}");
  // Aqui você pode fazer algum processamento se necessário,
  // mas evite qualquer lógica de UI.
}

class PushNotificationManager {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // <-- MUDANÇA: Stream para comunicar eventos de notificação para a UI.
  final _notificationStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get onNotificationOpened => _notificationStreamController.stream;

  // Usando um Singleton para garantir uma única instância
  static final PushNotificationManager _instance = PushNotificationManager._internal();
  factory PushNotificationManager() => _instance;
  PushNotificationManager._internal();

  Future<void> init() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log('Permissão de notificação concedida.');

      String? token = await _firebaseMessaging.getToken();
      log('Firebase FCM Token: $token');
      // Lembre-se de enviar este token para o seu servidor!

      // Handler para notificação com o app em primeiro plano
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        log('Notificação em Primeiro Plano: ${message.notification?.title}');
        // Aqui você pode usar o pacote `flutter_local_notifications` para
        // mostrar uma notificação visual, já que o FCM não faz isso
        // automaticamente no foreground.
      });

      // Handler para quando o usuário TOCA na notificação (app em background/terminado)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        log('App aberto pela notificação. Enviando para o stream...');
        // <-- MUDANÇA: Adiciona a mensagem ao stream em vez de tentar navegar.
        _notificationStreamController.add(message);
      });

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    } else {
      log('Permissão de notificação negada.');
    }
  }

  void dispose() {
    _notificationStreamController.close();
  }
}
