import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:flutter/material.dart';

class UsuarioProvedor extends ChangeNotifier {
  UsuarioModelo? _usuario;
  ModeloConfigBigchef? _configbigchef;

  UsuarioModelo? get usuario => _usuario;
  ModeloConfigBigchef? get configbigchef => _configbigchef;

  void setUsuario(UsuarioModelo? novoUsuario) {
    if (novoUsuario?.empresa != _usuario?.empresa) {
      _configbigchef = null;
    }
    _usuario = novoUsuario;

    notifyListeners();
  }

  void setConfigBigChef(ModeloConfigBigchef? config) {
    _configbigchef = config;
    notifyListeners();
  }
}
