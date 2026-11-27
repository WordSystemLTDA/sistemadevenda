import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';

import 'servico_pedido_voz.dart';
import 'cache_disponibilidade_voz.dart';

/// Consulta leve e temporariamente armazenada da ativacao de voz da empresa.
/// Nenhum gravador, permissao de microfone ou catalogo e iniciado aqui.
class ConfiguracaoVoz {
  static final _cache = CacheDisponibilidadeVoz();

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
      final disponivel = await _cache.consultar(chave, () async {
        final servico = ServicoPedidoVoz(servidor: servidor, usuario: usuario);
        try {
          return await servico.disponivel();
        } finally {
          servico.dispose();
        }
      }, forcar: forcar);
      return identical(identidade, usuario.usuario) && disponivel;
    } catch (_) {
      return false;
    }
  }

  static void invalidar() {
    _cache.invalidar();
  }
}
