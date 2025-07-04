import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/shared_prefs/modelo_conexao.dart';

class Apis {
  final ConfigSharedPreferences _config = ConfigSharedPreferences();

  Future<ModeloConexao> getConexao({String tipo = ''}) async {
    var conexao = await _config.getConexao();

    if (conexao!.tipoConexao == 'online' || tipo == 'online') {
      return ModeloConexao(tipoConexao: 'online', servidor: 'https://bigchef.com.br/sistema/apis_restaurantes/api_restaurantes_venda/api5/', porta: '');
    }

    return ModeloConexao(tipoConexao: conexao.tipoConexao, porta: conexao.porta, servidor: 'http://${conexao.servidor}/sistema/apis_restaurantes/api_restaurantes_venda/api1/');
  }
}
