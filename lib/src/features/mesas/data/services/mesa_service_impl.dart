import 'dart:convert';

import 'package:app/src/shared/services/api.dart';
import 'package:app/src/shared/shared_prefs/shared_prefs_config.dart';
import 'package:dio/dio.dart';

class MesaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<dynamic> listar() async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final response = await dio.get('${Apis.baseUrl}mesas/listar.php?empresa=$empresa');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return response.data;
        // return List<ProdutoModel>.from(response.data.map((elemento) {
        //   return ProdutoModel.fromMap(elemento);
        // }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }
  // Future<MesasModel?> listar() async {
  //   try {
  //     final response = await dio.get('${Apis.baseUrl}mesas/listar.php').timeout(const Duration(seconds: 60));

  //     if (response.data.isNotEmpty) {
  //       return MesasModel.fromMap(response.data);
  //     }
  //   } on DioException catch (exception) {
  //     if (exception.type == DioExceptionType.connectionTimeout) {
  //       throw Exception("Requisição Expirou");
  //     } else if (exception.type == DioExceptionType.connectionError) {
  //       throw Exception("Verifique sua conexão");
  //     }

  //     throw Exception(exception.message);
  //   } catch (exception, stacktrace) {
  //     log("error", error: exception, stackTrace: stacktrace);
  //     throw Exception("Verifique sua conexão");
  //   }

  //   throw Exception('Ocorreu um erro, tente novamente.');
  // }
}

// class MesaServiceImpl implements MesaService {
//   final Dio dio;

//   MesaServiceImpl(this.dio);

//   @override
//   Future<MesasModel?> listar() async {
//     try {
//       final response = await dio.get('${Apis.baseUrl}mesas/listar.php').timeout(const Duration(seconds: 60));

//       if (response.data.isNotEmpty) {
//         return MesasModel.fromMap(response.data);
//       }
//     } on DioException catch (exception) {
//       if (exception.type == DioExceptionType.connectionTimeout) {
//         throw Exception("Requisição Expirou");
//       } else if (exception.type == DioExceptionType.connectionError) {
//         throw Exception("Verifique sua conexão");
//       }

//       throw Exception(exception.message);
//     } catch (exception, stacktrace) {
//       log("error", error: exception, stackTrace: stacktrace);
//       throw Exception("Verifique sua conexão");
//     }

//     throw Exception('Ocorreu um erro, tente novamente.');
//   }
// }
