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
      {'pesquisa': pesquisa.trim()},
    );
    if (resposta is! List) {
      throw StateError('Não foi possível consultar os clientes.');
    }
    return [
      for (final item in resposta)
        if (item is Map)
          ClienteCadastro.fromMap(Map<String, dynamic>.from(item)),
    ];
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
  ) =>
      _salvarCliente(
        id: '',
        nome: nome,
        celular: celular,
        email: email,
        observacao: observacao,
      );

  @override
  Future<ResultadoSalvarCliente> editarCliente(
    String id,
    String nome,
    String celular,
    String email,
    String observacao,
  ) =>
      _salvarCliente(
        id: id,
        nome: nome,
        celular: celular,
        email: email,
        observacao: observacao,
      );

  Future<ResultadoSalvarCliente> _salvarCliente({
    required String id,
    required String nome,
    required String celular,
    required String email,
    required String observacao,
  }) async {
    if (nome.trim().isEmpty) {
      return (
        sucesso: false,
        idcliente: id,
        nomecliente: nome.trim(),
        mensagem: 'Informe o nome do cliente',
      );
    }
    final idNormalizado = id.trim();
    final editando = idNormalizado.isNotEmpty;
    // A API publicada usa esta mesma rota para INSERT e UPDATE; com ID válido
    // ela atualiza o cliente existente e não executa o trecho de cadastro.
    final resposta = await _delivery.salvar('comandas/inserir_cliente.php', {
      if (editando) ...{
        'id': idNormalizado,
        'idCliente': idNormalizado,
      },
      'nome': nome.trim(),
      'celular': celular.trim(),
      'email': email.trim(),
      'obs': observacao.trim(),
    });
    return (
      sucesso: true,
      idcliente: resposta['idcliente']?.toString() ?? id,
      nomecliente: resposta['nomecliente']?.toString() ?? nome.trim(),
      mensagem: resposta['mensagem']?.toString() ??
          (editando
              ? 'Cliente atualizado com sucesso'
              : 'Cliente cadastrado com sucesso'),
    );
  }
}
