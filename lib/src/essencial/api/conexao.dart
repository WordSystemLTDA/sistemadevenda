import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';

class Apis {
  final ConfigSharedPreferences _config = ConfigSharedPreferences();

  dynamic getConexao() async {
    var conexao = await _config.getConexao();

    return {
      'tipoConexao': conexao['tipoConexao'],
      'servidor': 'http://${conexao['servidor']}/sistema/apis_restaurantes/api_restaurantes_venda/',
    };
  }

  // static const baseUrl = 'http://192.168.2.129/api_restaurantes/';
}
