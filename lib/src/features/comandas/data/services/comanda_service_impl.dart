import 'dart:convert';
import 'dart:developer';
import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:app/src/shared/shared_prefs/shared_prefs_config.dart';
import 'package:dio/dio.dart';

class ComandaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<List<ComandasModel>> listar() async {
    try {
      final conexao = await Apis().getConexao();
      if (conexao == null) return [];
      final response = await dio.get('${conexao['servidor']}comandas/listar.php').timeout(const Duration(seconds: 60));

      if (response.data.isNotEmpty) {
        return List<ComandasModel>.from(response.data.map((e) => ComandasModel.fromMap(e)));
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

  Future<List<dynamic>> listarMesa(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}comandas/listar_mesas.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<bool> inserirComandaOcupada(String id, String idMesa, String idCliente, String obs) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}comandas/inserir_comanda_ocupada.php';

    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];
    final usuario = jsonDecode(await sharedPrefs.getUsuario())['id'];

    final response = await dio.post(
      url,
      data: {
        'id': id,
        'idMesa': idMesa,
        'idCliente': idCliente,
        'obs': obs,
        'usuario': usuario,
        'empresa': empresa,
      },
    ).timeout(const Duration(seconds: 60));

    return response.data['sucesso'];
  }
}
