import 'package:app/firebase_options.dart';
import 'package:app/src/app_module.dart';
import 'package:app/src/app_widget.dart';
import 'package:app/src/managers/app_lifecycle_observer.dart';
import 'package:app/src/managers/push_notification_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // PASSO 2: Inicialize o Gerenciador de Notificações UMA VEZ.
  await PushNotificationManager().init();

  runApp(
    ModularApp(
      module: AppModule(),
      child: AppLifecycleObserver(
        child: const AppWidget(),
      ),
    ),
  );
}
