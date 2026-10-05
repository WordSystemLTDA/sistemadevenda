import 'package:app/src/modulos/clientes/modelos/cliente_cadastro.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';

typedef ResultadoSalvarCliente = ({
  bool sucesso,
  String idcliente,
  String nomecliente,
  String mensagem,
});

abstract class RepositorioClientes {
  ServicoDelivery get servicoEndereco;

  Future<List<ClienteCadastro>> listarClientes(String pesquisa);

  Future<List<EnderecoClienteCadastro>> listarEnderecos(String idCliente);

  Future<ResultadoSalvarCliente> cadastrarCliente(
    String nome,
    String celular,
    String email,
    String observacao,
  );

  Future<ResultadoSalvarCliente> editarCliente(
    String id,
    String nome,
    String celular,
    String email,
    String observacao,
  );
}

class ServicoClientes implements RepositorioClientes {
  ServicoClientes(this._delivery);

  final ServicoDelivery _delivery;

  @override
  ServicoDelivery get servicoEndereco => _delivery;

  @override
  Future<List<ClienteCadastro>> listarClientes(String pesquisa) async {
    final resposta = await _delivery.consultar(
      'comandas/listar_clientes.php',
      {'pesquisa': pesquisa.trim(), 'ordenacao': 'recentes'},
    );
    if (resposta is! List) {
      throw StateError('Não foi possível consultar os clientes.');
    }
    final clientes = [
      for (final item in resposta)
        if (item is Map)
          ClienteCadastro.fromMap(Map<String, dynamic>.from(item)),
    ];
    clientes.sort(
        (a, b) => (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0));
    return clientes;
  }

  @override
  Future<List<EnderecoClienteCadastro>> listarEnderecos(
      String idCliente) async {
    final resposta = await _delivery.consultar(
      'enderecos_clientes/listar_por_cliente.php',
      {'cliente': idCliente, 'pesquisa': ''},
    );
    if (resposta is! List) {
      throw StateError('Não foi possível consultar os endereços.');
    }
    return [
      for (final item in resposta)
        if (item is Map)
          EnderecoClienteCadastro.fromMap(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<ResultadoSalvarCliente> cadastrarCliente(
    String nome,
    String celular,
    String email,
    String observacao,
  ) async {
    final nomeNormalizado = nome.trim();
    if (nomeNormalizado.isEmpty) {
      return (
        sucesso: false,
        idcliente: '',
        nomecliente: nomeNormalizado,
        mensagem: 'Informe o nome do cliente',
      );
    }
    final resposta = await _delivery.salvar('comandas/inserir_cliente.php', {
      'acao': 'cadastrar',
      'nome': nomeNormalizado,
      'celular': celular.trim(),
      'email': email.trim(),
      'obs': observacao.trim(),
    });
    return (
      sucesso: true,
      idcliente: resposta['idcliente']?.toString() ?? '',
      nomecliente: resposta['nomecliente']?.toString() ?? nomeNormalizado,
      mensagem:
          resposta['mensagem']?.toString() ?? 'Cliente cadastrado com sucesso',
    );
  }

  @override
  Future<ResultadoSalvarCliente> editarCliente(
    String id,
    String nome,
    String celular,
    String email,
    String observacao,
  ) async {
    final idNormalizado = id.trim();
    final nomeNormalizado = nome.trim();
    if ((int.tryParse(idNormalizado) ?? 0) <= 0) {
      throw StateError('Cliente não identificado para edição.');
    }
    if (nomeNormalizado.isEmpty) {
      return (
        sucesso: false,
        idcliente: idNormalizado,
        nomecliente: nomeNormalizado,
        mensagem: 'Informe o nome do cliente',
      );
    }
    Map<String, dynamic> capacidade;
    try {
      capacidade = await _delivery.salvar('comandas/inserir_cliente.php', {
        'acao': 'verificar_edicao_cliente',
        'id': idNormalizado,
        'idCliente': idNormalizado,
      });
    } catch (_) {
      throw StateError('A API de edição de clientes não está atualizada.');
    }
    if (capacidade['recurso'] != 'edicao_cliente_v1') {
      throw StateError('A API de edição de clientes não está atualizada.');
    }

    final resposta = await _delivery.salvar('comandas/inserir_cliente.php', {
      'acao': 'editar',
      'id': idNormalizado,
      'idCliente': idNormalizado,
      'nome': nomeNormalizado,
      'celular': celular.trim(),
      'email': email.trim(),
      'obs': observacao.trim(),
    });
    final idResposta = resposta['idcliente']?.toString().trim() ?? '';
    if (resposta['operacao'] != 'cliente_editado' ||
        idResposta != idNormalizado) {
      throw StateError('O servidor não confirmou a edição do cliente.');
    }
    return (
      sucesso: true,
      idcliente: idNormalizado,
      nomecliente: resposta['nomecliente']?.toString() ?? nomeNormalizado,
      mensagem:
          resposta['mensagem']?.toString() ?? 'Cliente atualizado com sucesso',
    );
  }
}
