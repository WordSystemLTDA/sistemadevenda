import 'package:shared_preferences/shared_preferences.dart';

class PreferenciaConfirmacaoDelivery {
  static const chave = 'delivery_confirmacao_pedido_automatica_v1';

  Future<bool> carregar() async =>
      (await SharedPreferences.getInstance()).getBool(chave) ?? false;

  Future<void> salvar(bool habilitada) async {
    final preferencias = await SharedPreferences.getInstance();
    if (!await preferencias.setBool(chave, habilitada)) {
      throw StateError('Não foi possível salvar a preferência no aparelho.');
    }
  }
}
