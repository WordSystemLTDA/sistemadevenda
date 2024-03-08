import 'dart:convert';

import 'package:app/src/essencial/services/api.dart';
import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:app/src/modulos/mesas/interactor/models/mesa_modelo.dart';
import 'package:dio/dio.dart';

class MesaServiceImpl {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<Map<String, List<MesaModelo>>> listar(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return {'mesasOcupadas': [], 'mesasLivres': []};
    final response = await dio.get('${conexao['servidor']}mesas/listar.php?pesquisa=$pesquisa&empresa=$empresa');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return {
          'mesasOcupadas': [
            ...response.data['mesasOcupadas'].map((e) {
              return MesaModelo(
                id: e['id'],
                nome: e['nome'],
                nomeCliente: e['nomeCliente'],
                dataAbertura: e['data_abertura'],
                horaAbertura: e['hora_abertura'],
                ativo: e['ativo'],
                mesaOcupada: e['mesaOcupada'],
              );
            })
          ],
          'mesasLivres': [
            ...response.data['mesasLivres'].map((e) {
              return MesaModelo(
                id: e['id'],
                nome: e['nome'],
                nomeCliente: '',
                dataAbertura: '',
                horaAbertura: '',
                ativo: e['ativo'],
                mesaOcupada: e['mesaOcupada'],
              );
            })
          ],
        };
        // return List<ProdutoModel>.from(response.data.map((elemento) {
        //   return ProdutoModel.fromMap(elemento);
        // }));
      } else {
        return {
          'mesasOcupadas': [],
          'mesasLivres': [],
        };
      }
    } else {
      return {
        'mesasOcupadas': [],
        'mesasLivres': [],
      };
    }
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}mesas/editar_ativo_mesa.php';

    final response = await dio.post(url, data: {
      'id': id,
      'ativo': ativo,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) {
      return {
        'sucesso': false,
        'mensagem': null,
      };
    }
    final url = '${conexao['servidor']}mesas/excluir_mesa.php';

    final response = await dio.post(url, data: {
      'idMesa': id,
      'empresa': empresa,
    });

    return {
      'sucesso': response.data['sucesso'],
      'mensagem': response.data['mensagem'],
    };
  }

  Future<bool> cadastrarMesa(String nome) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return false;

    final url = '${conexao['servidor']}mesas/cadastrar_mesa.php';

    final response = await dio.post(url, data: {
      'nome': nome,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<bool> editarMesa(String id, String nome) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;

    final url = '${conexao['servidor']}mesas/editar_mesa.php';

    final response = await dio.post(url, data: {
      'id': id,
      'nome': nome,
    });

    return response.data['sucesso'];
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<bool> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final url = '${conexao['servidor']}mesas/inserir_mesa_ocupada.php';

    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];
    final usuario = jsonDecode(await sharedPrefs.getUsuario())['id'];

    final response = await dio.post(
      url,
      data: {
        'idMesa': idMesa,
        'idCliente': idCliente,
        'obs': obs,
        'empresa': empresa,
        'usuario': usuario,
      },
    ).timeout(const Duration(seconds: 60));

    return response.data['sucesso'];
  }
}
