import 'package:app/src/essencial/sincronizacao/estado_servidor.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => Sincronizador.instancia = null);

  test('identifica indisponibilidade de transporte', () {
    final opcoes = RequestOptions(path: '/teste');

    expect(
      EstadoServidor.indisponivel(DioException(
        requestOptions: opcoes,
        type: DioExceptionType.connectionTimeout,
      )),
      isTrue,
    );
  });

  test('identifica servidor temporariamente indisponivel', () {
    final opcoes = RequestOptions(path: '/teste');

    expect(
      EstadoServidor.indisponivel(DioException.badResponse(
        statusCode: 503,
        requestOptions: opcoes,
        response: Response<void>(requestOptions: opcoes, statusCode: 503),
      )),
      isTrue,
    );
  });

  test('nao oculta falha funcional', () {
    expect(EstadoServidor.indisponivel(StateError('Dados inválidos')), isFalse);
  });
}
