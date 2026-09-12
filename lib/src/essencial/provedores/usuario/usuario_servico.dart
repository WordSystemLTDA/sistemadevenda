// ignore_for_file: public_member_api_docs, sort_constructors_first, use_build_context_synchronously
import 'dart:convert';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/api/socket/server.dart';

class UsuarioServico {
  static Future<UsuarioModelo?> pegarUsuario(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.clear();

    String? usuarioString = prefs.getString(ConfigSharedPreferences.usuario);

    if (usuarioString != null) {
      Map<String, dynamic> usuarioMap = json.decode(usuarioString);
      UsuarioModelo usuario = UsuarioModelo.fromMap(usuarioMap);

      // Atualize o UsuarioProvider
      UsuarioProvedor().setUsuario(usuario);

      return usuario;
    }

    return null;
  }

  static Future<void> sair(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Limpe os dados do usuário nas SharedPreferences
    // prefs.remove(ChavesSharedPreferences.usuario);
    await prefs.remove(ConfigSharedPreferences.usuario);
    Modular.get<UsuarioProvedor>().setUsuario(null);
    await Modular.get<Server>().disconnect();

    // Notifique o UsuarioProvider (se estiver usando Provider)
    // Navigator.pushReplacementNamed(context, AppRotas.login);
  }

  static Future<void> salvarUsuario(BuildContext context, UsuarioModelo usuario) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String usuarioString = json.encode(usuario.toMap());
    prefs.setString(ConfigSharedPreferences.usuario, usuarioString);

    // Atualize o UsuarioProvider
    UsuarioProvedor().setUsuario(usuario);
  }
}
