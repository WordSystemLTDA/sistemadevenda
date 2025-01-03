import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';

class ServicoMesas {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoMesas(this.dio, this.usuarioProvedor);

  Future<List<MesasModel>> listar(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('mesas/listar.php?pesquisa=$pesquisa&empresa=$empresa');

    if (response.data.isNotEmpty) {
      return List<MesasModel>.from(response.data.map((elemento) {
        return MesasModel.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<List<MesaModelo>> listarLista(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('mesas/listar_lista.php?pesquisa=$pesquisa&empresa=$empresa');

    if (response.data.isNotEmpty) {
      return List<MesaModelo>.from(response.data.map((elemento) {
        return MesaModelo.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'mesas/editar_ativo_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'id': id,
      'ativo': ativo,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'mesas/excluir_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'idMesa': id,
      'empresa': empresa,
    });

    return {
      'sucesso': response.data['sucesso'],
      'mensagem': response.data['mensagem'],
    };
  }

  Future<bool> cadastrarMesa(String nome, String codigo) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'mesas/cadastrar_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'nome': nome,
      'codigo': codigo,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<bool> editarMesa(String id, String nome, String codigo) async {
    const url = 'mesas/editar_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'id': id,
      'nome': nome,
      'codigo': codigo,
    });

    return response.data['sucesso'];
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.cliente.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<bool> editarMesaOcupada(String id, String idMesa, String idCliente, String obs) async {
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

  Future<({bool sucesso, String idcomandapedido})> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    const url = 'mesas/inserir_mesa_ocupada.php';

    final empresa = usuarioProvedor.usuario!.empresa;
    final usuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.post(
      url,
      data: {
        'idMesa': idMesa,
        'idCliente': idCliente,
        'obs': obs,
        'empresa': empresa,
        'usuario': usuario,
      },
    ).timeout(const Duration(seconds: 60));

    bool sucesso = response.data['sucesso'];
    String idcomandapedido = response.data['idcomandapedido'];

    return (sucesso: sucesso, idcomandapedido: idcomandapedido);
  }
}
