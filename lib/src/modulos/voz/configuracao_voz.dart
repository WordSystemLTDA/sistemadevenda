import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';

import 'servico_pedido_voz.dart';

/// Consulta leve e temporariamente armazenada da ativacao de voz da empresa.
/// Nenhum gravador, permissao de microfone ou catalogo e iniciado aqui.
class ConfiguracaoVoz {
  static String? _chave;
  static bool? _disponivel;
  static DateTime? _validade;

  static Future<bool> carregar(UsuarioProvedor usuario,
      {bool forcar = false}) async {
    final identidade = usuario.usuario;
    if (identidade == null || identidade.senha?.isNotEmpty != true) {
      return false;
    }
    try {
      final servidor =
          (await Apis().getConexao().timeout(const Duration(seconds: 5)))
              .servidor;
      final chave = '$servidor|${identidade.empresa}|${identidade.id}';
      final agora = DateTime.now();
      if (!forcar &&
          _chave == chave &&
          _disponivel != null &&
          (_validade?.isAfter(agora) ?? false)) {
        return _disponivel!;
      }
      final servico = ServicoPedidoVoz(servidor: servidor, usuario: usuario);
      var disponivel = false;
      try {
        disponivel = await servico.disponivel();
      } finally {
        servico.dispose();
      }
      if (identical(identidade, usuario.usuario)) {
        _chave = chave;
        _disponivel = disponivel;
        _validade = agora.add(const Duration(seconds: 30));
      }
      return disponivel;
    } catch (_) {
      return false;
    }
  }

  static void invalidar() {
    _chave = null;
    _disponivel = null;
    _validade = null;
  }
}
