import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';

class ServicoMesas {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoMesas(this.dio, this.usuarioProvedor);
  int _consultaCarrinhos = 0;

  Future<List<MesasModel>> listar(String pesquisa) async {
    final consulta = ++_consultaCarrinhos;
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get(
      'mesas/listar.php',
      queryParameters: {
        'pesquisa': pesquisa,
        'empresa': empresa,
      },
    );

    final sync = Sincronizador.instancia;
    final lista = sync == null ? response.data : await AtendimentosLocais(sync.banco, sync.escopo)
        .projetarLista(List<dynamic>.from(response.data), 'mesa', pesquisa);
    if (lista.isNotEmpty) {
      final grupos = List<MesasModel>.from(lista.map((elemento) {
        return MesasModel.fromMap(elemento);
      }));
      if (consulta == _consultaCarrinhos) {
        await _sincronizarCarrinhos(empresa ?? '',
            grupos.expand((grupo) => grupo.mesas ?? <MesaModelo>[]));
      }
      return grupos;
    }

    return [];
  }

  Future<List<MesaModelo>> listarLista(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final response = await dio.cliente.get(
      'mesas/listar_lista.php',
      queryParameters: {
        'pesquisa': pesquisa,
        'empresa': empresa,
      },
    );

    if (response.data.isNotEmpty) {
      final mesas = List<MesaModelo>.from(response.data.map((elemento) {
        return MesaModelo.fromMap(elemento);
      }));
      // A lista de cadastro nao informa a ocupacao real dos atendimentos.
      return mesas;
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

  Future<void> _sincronizarCarrinhos(
      String empresa, Iterable<MesaModelo> mesas) async {
    for (final mesa in mesas) {
      await ArmazenamentoCarrinhos.instancia.sincronizarRecurso(
        empresa: empresa,
        tipo: 'mesa',
        idRecurso: mesa.id,
        idAtendimento: mesa.idComandaPedido,
        aberto: mesa.mesaOcupada,
        bloqueado: mesa.fechamento == true,
      );
    }
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

    final response = await dio.cliente.get(
      'comandas/listar_clientes.php',
      queryParameters: {
        'pesquisa': pesquisa,
        'empresa': empresa,
      },
    );

    return response.data;
  }

  Future<bool> editarMesaOcupada(
      String id, String idMesa, String idCliente, String obs) async {
    final sync = Sincronizador.instancia;
    if (sync != null) id = await AtendimentosLocais(sync.banco, sync.escopo).idServidor(id);
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
    );

    return response.data['sucesso'];
  }

  Future<({bool sucesso, String idcomandapedido})> inserirMesaOcupada(
      String idMesa, String idCliente, String obs) async {
    final sync = Sincronizador.instancia;
    if (sync != null && await sync.prepararAberturasOffline()) {
      final atendimento = await sync.abrirAtendimento(tipo: 'mesa',
          idMesa: idMesa, idCliente: idCliente, obs: obs);
      return (sucesso: true, idcomandapedido: atendimento);
    }
    if (sync != null && dio.cache?.servidorDisponivel == false) {
      throw StateError('O servidor precisa receber a atualizacao de abertura offline.');
    }
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
    );

    bool sucesso = response.data['sucesso'];
    String idcomandapedido = response.data['idcomandapedido'];

    return (sucesso: sucesso, idcomandapedido: idcomandapedido);
  }
}
