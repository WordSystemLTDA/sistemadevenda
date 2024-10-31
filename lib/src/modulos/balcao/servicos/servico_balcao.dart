import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_enderecos_clientes.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';

class ServicoBalcao {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;

  ServicoBalcao(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'balcao';

  Future<List<ModeloVendasBalcao>> listar(int pagina, int linhasPorPagina, String pesquisa, String dataInicio, String dataFim, String hora) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final id = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.post(
        '/$caminhoAPI/listar.php?id_empresa=$empresa&id_usuario=$id&pagina=$pagina&linhasPorPagina=$linhasPorPagina&pesquisa=$pesquisa&dataInicio=$dataInicio&dataFim=$dataFim&hora=$hora');

    if (response.data.isNotEmpty) {
      return List<ModeloVendasBalcao>.from(response.data.map((elemento) {
        return ModeloVendasBalcao.fromMap(elemento);
      }));
    }

    return [];
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = 'comandas/listar_clientes.php?pesquisa=$pesquisa&empresa=$empresa';
    final response = await dio.cliente.get(url);

    return response.data;
  }

  Future<List<Modelowordenderecosclientes>> listarEnderecosClientes(String pesquisa, String idCliente) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    var response = await dio.cliente.post('enderecos_clientes/listar_por_cliente.php?empresa=$idEmpresa&id_usuario=$idUsuario&pesquisa=$pesquisa&cliente=$idCliente');
    var jsonData = response.data;

    dynamic dados = jsonData;

    return List<Modelowordenderecosclientes>.from(dados.map((elemento) {
      return Modelowordenderecosclientes.fromMap(elemento);
    }));
  }

  Future<({bool sucesso, String idvenda})> inserir(String idCliente, String obs) async {
    final empresa = usuarioProvedor.usuario!.empresa;
    final usuario = usuarioProvedor.usuario!.id;

    const url = 'balcao/inserir.php';
    final response = await dio.cliente.post(
      url,
      data: {
        'idCliente': idCliente,
        'obs': obs,
        'empresa': empresa,
        'usuario': usuario,
      },
    );

    bool sucesso = response.data['sucesso'];
    String idvenda = response.data['idvenda'];

    return (sucesso: sucesso, idvenda: idvenda);
  }
}
