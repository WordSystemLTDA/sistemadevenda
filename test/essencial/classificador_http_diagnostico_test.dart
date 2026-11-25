import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/essencial/diagnosticos/classificador_http_diagnostico.dart';

void main() {
  final pausa = {
    'protocolo': 2,
    'sucesso': false,
    'codigo': 'SINCRONIZACAO_ADIADA',
    'status': 'pendente',
    'tentar_apos': 30
  };
  test('somente pausa autentica do protocolo tem classificacao de aviso', () {
    for (final status in [200, 429, 503]) {
      expect(
          ehAdiamentoSincronizacao(
              caminho: 'sincronizador/transferir.php',
              status: status,
              resposta: pausa),
          isTrue);
      expect(
          ehAdiamentoSincronizacao(
              caminho: 'sincronizador_de_arquivos/enviar_arquivos.php',
              status: status,
              resposta: pausa),
          isTrue);
    }
    expect(
        ehAdiamentoSincronizacao(
            caminho: 'autenticacao/entrar.php', status: 503, resposta: pausa),
        isFalse);
    expect(
        ehAdiamentoSincronizacao(
            caminho: 'sincronizador/transferir.php',
            status: 503,
            resposta: {'mensagem': 'Indisponivel'}),
        isFalse);
    for (final alterar in [
      {'protocolo': 1},
      {'tentar_apos': 0},
      {'codigo': 'LICENCA_BLOQUEADA'},
      {'status': 'erro'}
    ]) {
      expect(
          ehAdiamentoSincronizacao(
              caminho: 'sincronizador/transferir.php',
              status: 503,
              resposta: {...pausa, ...alterar}),
          isFalse);
    }
    expect(
        ehAdiamentoSincronizacao(
            caminho: 'sincronizador/transferir.php',
            status: 500,
            resposta: pausa),
        isFalse);
  });
}
