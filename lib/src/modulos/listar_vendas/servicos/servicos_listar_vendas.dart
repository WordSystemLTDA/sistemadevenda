import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:app/src/modulos/listar_vendas/modelos/itens_insercao_listar_vendas_modelo.dart';
import 'package:app/src/modulos/listar_vendas/modelos/listar_vendas_modelo.dart';
import 'package:app/src/modulos/listar_vendas/modelos/salvar_listar_vendas_modelo.dart';
import 'package:dio/dio.dart';

class ServicosListarVendas {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  static const String caminho = 'listar_vendas';

  Future<List<ListarVendasModelo>> listar(String pesquisa, String dataInicial, String dataFinal) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];
    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];
    final nivel = jsonDecode(await sharedPrefs.getUsuario())['nivel'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar.php';

    final response = await dio.post(url, data: {
      'id_empresa': empresa,
      'id_usuario': idUsuario,
      'nivel_usuario': nivel,
      'pagina': 1,
      'linhasPorPagina': 20,
      'dataInicial': dataInicial,
      'dataFinal': dataFinal,
      'alterou_data': '',
      'listar_personalizacao_1': '',
      'data_filtro': '',
    });

    final jsonData = response.data;

    return List<ListarVendasModelo>.from(jsonData.map((elemento) {
      return ListarVendasModelo.fromMap(elemento);
    }));
  }

  // Future<bool> inserir(SalvarListarVendasModelo modelo) async {
  // final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

  // final conexao = await Apis().getConexao();
  // if (conexao == null) return [];
  // final url = '${conexao['servidor']}/$caminho/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

  // final response = await dio.get(url);

  // final jsonData = response.data;

  //   return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
  //     return ItensInsercaoListarVendasModelo.fromMap(elemento);
  //   }));
  //   return true;
  // }

  Future<List<ItensInsercaoListarVendasModelo>> listarClientes(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url);

    final jsonData = response.data;

    return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
      return ItensInsercaoListarVendasModelo.fromMap(elemento);
    }));
  }

  Future<List<ItensInsercaoListarVendasModelo>> listarNatureza(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar_natureza.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url);

    final jsonData = response.data;

    return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
      return ItensInsercaoListarVendasModelo.fromMap(elemento);
    }));
  }

  Future<List<ItensInsercaoListarVendasModelo>> listarVendedor(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar_vendedor.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url);

    final jsonData = response.data;

    return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
      return ItensInsercaoListarVendasModelo.fromMap(elemento);
    }));
  }

  Future<List<ItensInsercaoListarVendasModelo>> listarTransportadoras(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar_transportadora.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.get(url);

    final jsonData = response.data;

    return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
      return ItensInsercaoListarVendasModelo.fromMap(elemento);
    }));
  }

  Future<List<ItensInsercaoListarVendasModelo>> listarFrete(String pesquisa) async {
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];
    final idUsuario = jsonDecode(await sharedPrefs.getUsuario())['id'];

    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final url = '${conexao['servidor']}/$caminho/listar_frete.php?pesquisa=$pesquisa&id_empresa=$empresa&id_usuario=$idUsuario';

    final response = await dio.get(url);

    final jsonData = response.data;

    return List<ItensInsercaoListarVendasModelo>.from(jsonData.map((elemento) {
      return ItensInsercaoListarVendasModelo.fromMap(elemento);
    }));
  }
}
