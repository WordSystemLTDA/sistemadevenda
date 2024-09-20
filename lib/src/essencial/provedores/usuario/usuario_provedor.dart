import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:flutter/material.dart';

class UsuarioProvedor extends ChangeNotifier {
  UsuarioModelo? _usuario;

  UsuarioModelo? get usuario => _usuario;

  void setUsuario(UsuarioModelo? novoUsuario) {
    _usuario = novoUsuario;

    notifyListeners();
  }
}
