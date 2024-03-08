import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';

class Apis {
  final SharedPrefsConfig _config = SharedPrefsConfig();

  Future<dynamic> getConexao() async {
    return await _config.getConexao();
  }

  // static const baseUrl = 'http://192.168.2.129/api_restaurantes/';
}
