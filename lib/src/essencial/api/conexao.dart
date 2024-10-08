import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/shared_prefs/modelo_conexao.dart';

class Apis {
  final ConfigSharedPreferences _config = ConfigSharedPreferences();

  Future<ModeloConexao> getConexao() async {
    var conexao = await _config.getConexao();

    // return {
    //   'tipoConexao': conexao!.tipoConexao,
    //   'servidor': 'http://${conexao.servidor}/sistema/apis_restaurantes/api_restaurantes_venda/',
    // };

    // if (conexao!.tipoConexao == 'online') {
    return ModeloConexao(tipoConexao: conexao!.tipoConexao, servidor: 'https://bigchef.com.br/sistema/apis_restaurantes/api_restaurantes_venda/');
    // }

    // return ModeloConexao(tipoConexao: conexao.tipoConexao, servidor: 'http://${conexao.servidor}/sistema/apis_restaurantes/api_restaurantes_venda/');
  }

  // static const baseUrl = 'http://192.168.2.129/api_restaurantes/';
}
