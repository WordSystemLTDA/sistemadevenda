import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';

class ServicoMesas {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoMesas(this.dio, this.usuarioProvedor);

  Future<Map<String, List<MesaModelo>>> listar(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get('mesas/listar.php?pesquisa=$pesquisa&empresa=$empresa');

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

  Future<bool> cadastrarMesa(String nome) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    const url = 'mesas/cadastrar_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'nome': nome,
      'empresa': empresa,
    });

    return response.data['sucesso'];
  }

  Future<bool> editarMesa(String id, String nome) async {
    const url = 'mesas/editar_mesa.php';

    final response = await dio.cliente.post(url, data: {
      'id': id,
      'nome': nome,
    });

    return response.data['sucesso'];
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';

    final response = await dio.cliente.get(url).timeout(const Duration(seconds: 60));

    return response.data;
  }

  Future<bool> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
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

    return response.data['sucesso'];
  }
}
