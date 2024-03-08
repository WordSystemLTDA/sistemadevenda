import 'dart:convert';

import 'package:app/src/essencial/services/api.dart';
import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:app/src/modulos/comandas/interactor/models/comanda_model.dart';
import 'package:app/src/modulos/comandas/interactor/models/comandas_model.dart';
import 'package:dio/dio.dart';

class ComandaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<List<ComandasModel>> listar(String pesquisa) async {
    // try {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final response = await dio.get('${conexao['servidor']}comandas/listar.php?pesquisa=$pesquisa&empresa=$empresa').timeout(const Duration(seconds: 60));

    if (response.data.isNotEmpty) {
      // return List<ComandasModel>.from(response.data.map((e) => ComandasModel.fromMap(e)));
      return [
        ...response.data.map(
          (e) => ComandasModel(
            titulo: e['titulo'],
            comandas: [
              ...e['comandas'].map(
                (el) => ComandaModel(
                  id: el['id'],
                  nome: el['nome'],
                  ativo: el['ativo'],
                  nomeCliente: el['nomeCliente'] ?? '',
                  nomeMesa: el['nomeMesa'] ?? '',
                  dataAbertura: el['dataAbertura'] ?? '',
                  horaAbertura: el['horaAbertura'] ?? '',
                  comandaOcupada: el['comandaOcupada'],
                ),
              ),
            ],
          ),
        )
      ];
    }

    return [];
    // } on DioException catch (exception) {
    //   if (exception.type == DioExceptionType.connectionTimeout) {
    //     throw Exception("Requisição Expirou");
    //   } else if (exception.type == DioExceptionType.connectionError) {
    //     throw Exception("Verifique sua conexão");
    //   }

    //   throw Exception(exception.message);
    // } catch (exception, stacktrace) {
    //   log("error", error: exception, stackTrace: stacktrace);
    //   throw Exception("Verifique sua conexão");
    // }

    // throw Exception('Ocorreu um erro, tente novamente.');
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}comandas/editar_ativo_comanda.php';

    final response = await dio.post(url, data: {
      'id': id,
      'ativo': ativo,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<Map<String, dynamic>> excluirComanda(String id) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) {
      return {
        'sucesso': false,
        'mensagem': null,
      };
    }
    final url = '${conexao['servidor']}comandas/excluir_comanda.php';

    final response = await dio.post(url, data: {
      'idComanda': id,
      'empresa': empresa,
    });

    return {
      'sucesso': response.data['sucesso'],
      'mensagem': response.data['mensagem'],
    };
  }

  Future<bool> cadastrarComanda(String nome) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return false;

    final url = '${conexao['servidor']}comandas/cadastrar_comanda.php';

    final response = await dio.post(url, data: {
      'nome': nome,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<bool> editarComanda(String id, String nome) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;

    final url = '${conexao['servidor']}comandas/editar_comanda.php';

    final response = await dio.post(url, data: {
      'id': id,
      'nome': nome,
    });

    return response.data['sucesso'];
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

  Future<bool> inserirCliente(String nome, String celular, String email, String obs) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}comandas/inserir_cliente.php';

    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final response = await dio.post(
      url,
      data: {
        'nome': nome,
        'celular': celular,
        'email': email,
        'obs': obs,
        'empresa': empresa,
      },
    ).timeout(const Duration(seconds: 60));

    return response.data['sucesso'];
  }
}
