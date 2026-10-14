import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

/// Prepara consultas auxiliares sem bloquear a fila de pedidos. O escopo e o
/// servidor sao capturados pelo sincronizador; troca de conta interrompe a tarefa.
class PreparacaoDeliveryOffline {
  final DioCliente api;
  final Map<String, DateTime> _preparados = {};
  final Set<String> _emAndamento = {};

  PreparacaoDeliveryOffline(this.api);

  Future<void> preparar(
      {required String escopo,
      required String servidor,
      required String empresa,
      required String usuario}) async {
    final cache = api.cache;
    if (cache == null || escopo.isEmpty || !_emAndamento.add(escopo)) return;
    bool ativa() =>
        cache.escopo == escopo &&
        cache.servidor == servidor &&
        cache.servidorDisponivel;
    Future<dynamic> consultar(String rota, Map<String, dynamic> campos) async {
      if (!ativa()) throw StateError('Preparação interrompida.');
      final resposta = await api.cliente.get(rota,
          queryParameters: {
            ...campos,
            'empresa': empresa,
            'id_usuario': usuario
          },
          options: Options(
              extra: {'servidorFixo': servidor, 'preparacaoOffline': true},
              sendTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 8)));
      if (!ativa()) throw StateError('A conta mudou.');
      return resposta.data;
    }

    try {
      final ultima = _preparados[escopo];
      if (!ativa() ||
          ultima != null &&
              ultima.day == DateTime.now().day &&
              DateTime.now().difference(ultima) < const Duration(minutes: 10)) {
        return;
      }
      final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
      Future<void> opcional(String rota, Map<String, dynamic> dados) async {
        try {
          await consultar(rota, dados);
        } catch (_) {
          // Um modulo indisponivel nao impede preparar clientes e enderecos.
        }
      }

      await Future.wait([
        opcional('config_bigchef/listar.php', {}),
        opcional('permissoes_bigchef/listar_permissoes_bigchef.php', {}),
        opcional('delivery/listar_opcoes.php', {
          'dataInicio': hoje,
          'dataFim': hoje,
          'horaSelecionada': '05:00:00',
          'horaFimSelecionada': '05:00:00',
          'pesquisa': '',
          'tipoentrega': '0',
        }),
        opcional('recorrentes/listar.php',
            {'inicio': hoje, 'fim': hoje, 'cadastros': 'Não'}),
      ]);
      // O seletor de clientes nao envia id_usuario. Preserve a mesma chave.
      if (!ativa()) return;
      final resposta = await api.cliente.get('comandas/listar_clientes.php',
          queryParameters: {'pesquisa': '', 'empresa': empresa},
          options: Options(
              extra: {'servidorFixo': servidor, 'preparacaoOffline': true},
              receiveTimeout: const Duration(seconds: 8)));
      final clientes = resposta.data is List ? resposta.data as List : const [];
      for (var inicio = 0; inicio < clientes.length && ativa(); inicio += 4) {
        await Future.wait(
            clientes.skip(inicio).take(4).whereType<Map>().map((cliente) async {
          final id = '${cliente['id'] ?? ''}';
          if ((int.tryParse(id) ?? 0) <= 0) return;
          await consultar('enderecos_clientes/listar_por_cliente.php',
              {'cliente': id, 'pesquisa': ''});
        }));
      }
      if (ativa()) _preparados[escopo] = DateTime.now();
    } on DioException catch (erro) {
      if (!CacheConsultas.falhaDeConexao(erro)) {
        // API antiga ou permissao restrita nao impede pedidos ja preparados.
        _preparados[escopo] = DateTime.now();
      }
    } catch (_) {
      // O catalogo e a fila seguem independentes desta preparacao auxiliar.
    } finally {
      _emAndamento.remove(escopo);
    }
  }
}
