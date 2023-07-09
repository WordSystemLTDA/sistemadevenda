import 'dart:developer';

import 'package:app/src/features/mesas/interactor/models/mesas_model.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class MesaServiceImpl implements MesaService {
  final Dio dio;

  MesaServiceImpl(this.dio);

  @override
  Future<MesasModel?> listar() async {
    try {
      final response = await dio.get('${Apis.baseUrl}mesas/listar.php').timeout(const Duration(seconds: 60));

      if (response.data.isNotEmpty) {
        return MesasModel.fromMap(response.data);
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
