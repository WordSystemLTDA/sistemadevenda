import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefsConfig {
  Future<dynamic> getUsuario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var usuario = prefs.getString('usuario');
    return usuario;
  }
}
