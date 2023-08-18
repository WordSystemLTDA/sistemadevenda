import 'dart:developer';

import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';
import 'package:app/src/features/comandas/interactor/services/comanda_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class ComandaServiceImpl implements ComandaService {
  final Dio dio;

  ComandaServiceImpl(this.dio);

  @override
  Future<ComandasModel?> listar() async {
    try {
      final response = await dio.get('${Apis.baseUrl}comandas/listar.php').timeout(const Duration(seconds: 60));

      if (response.data.isNotEmpty) {
        return ComandasModel.fromMap(response.data);
      }
    } on DioException catch (exception) {
      if (exception.type == DioExceptionType.connectionTimeout) {
        throw Exception("Requisição Expirou");
      } else if (exception.type == DioExceptionType.connectionError) {
        throw Exception("Verifique sua conexão");
      }

      throw Exception(exception.message);
    } catch (exception, stacktrace) {
      log("error", error: exception, stackTrace: stacktrace);
      throw Exception("Verifique sua conexão");
    }

    throw Exception('Ocorreu um erro, tente novamente.');
  }
}
