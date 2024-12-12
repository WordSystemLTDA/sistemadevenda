import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:flutter/material.dart';

class ConfigProvider extends ChangeNotifier {
  ConfigModelo? _configs;

  ConfigModelo? get configs => _configs;

  void setConfig(ConfigModelo? configs) {
    print(configs!.toMap());
    _configs = configs;
    notifyListeners();
  }
}
