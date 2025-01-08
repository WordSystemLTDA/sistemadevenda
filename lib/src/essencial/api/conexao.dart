import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/shared_prefs/modelo_conexao.dart';
import 'package:package_info_plus/package_info_plus.dart';

class Apis {
  final ConfigSharedPreferences _config = ConfigSharedPreferences();

  Future<ModeloConexao> getConexao() async {
    var conexao = await _config.getConexao();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    var versao = packageInfo.version;

    if (conexao!.tipoConexao == 'online') {
      return ModeloConexao(tipoConexao: 'online', servidor: 'https://bigchef.com.br/sistema/apis_restaurantes/api_restaurantes_venda/$versao', porta: '');
    }

    return ModeloConexao(tipoConexao: conexao.tipoConexao, porta: conexao.porta, servidor: 'http://${conexao.servidor}/sistema/apis_restaurantes/api_restaurantes_venda/1.0.01/');
  }
}
