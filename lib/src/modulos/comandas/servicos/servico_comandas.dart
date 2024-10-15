import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/comandas/modelos/comanda_model.dart';
import 'package:app/src/modulos/comandas/modelos/comandas_model.dart';

class ServicoComandas {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoComandas(this.dio, this.usuarioProvedor);

  Future<List<ComandasModel>> listar(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('comandas/listar.php?pesquisa=$pesquisa&empresa=$empresa').timeout(const Duration(seconds: 60));

    if (response.data.isNotEmpty) {
      return List<ComandasModel>.from(response.data.map((elemento) {
        return ComandasModel.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<List<ComandaModel>> listarLista(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('comandas/listar_lista.php?pesquisa=$pesquisa&empresa=$empresa').timeout(const Duration(seconds: 60));

    if (response.data.isNotEmpty) {
      return List<ComandaModel>.from(response.data.map((elemento) {
        return ComandaModel.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'comandas/editar_ativo_comanda.php';

    final response = await dio.cliente.post(url, data: {
      'id': id,
      'ativo': ativo,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<Map<String, dynamic>> excluirComanda(String id) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'comandas/excluir_comanda.php';

    final response = await dio.cliente.post(url, data: {
      'idComanda': id,
      'empresa': empresa,
    });

    return {
      'sucesso': response.data['sucesso'],
      'mensagem': response.data['mensagem'],
    };
  }

  Future<bool> cadastrarComanda(String nome) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'comandas/cadastrar_comanda.php';

    final response = await dio.cliente.post(url, data: {
      'nome': nome,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<bool> editarComanda(String id, String nome) async {
    const url = 'comandas/editar_comanda.php';

    final response = await dio.cliente.post(url, data: {
      'id': id,
      'nome': nome,
    });

    return response.data['sucesso'];
  }

  Future<List<dynamic>> listarMesa(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_mesas.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.cliente.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.cliente.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<({bool sucesso, String? idcomandapedido})> inserirComandaOcupada(String id, String idMesa, String idCliente, String obs) async {
    const url = 'comandas/inserir_comanda_ocupada.php';

    final empresa = usuarioProvedor.usuario!.empresa;
    final usuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.post(
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

    bool sucesso = response.data['sucesso'];
    String? idcomandapedido = response.data['idcomandapedido'];

    return (sucesso: sucesso, idcomandapedido: idcomandapedido);
  }

  Future<bool> editarComandaOcupada(String id, String idMesa, String idCliente, String obs) async {
    const url = 'comandas/editar_comanda_ocupada.php';

    final empresa = usuarioProvedor.usuario!.empresa;
    final usuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.post(
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
    const url = 'comandas/inserir_cliente.php';

    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.post(
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
