import 'package:app/src/modulos/clientes/modelos/cliente_cadastro.dart';
import 'package:app/src/modulos/clientes/paginas/pagina_clientes.dart';
import 'package:app/src/modulos/clientes/servicos/servico_clientes.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioClientesTeste implements RepositorioClientes {
  _RepositorioClientesTeste({this.enderecos});

  final List<EnderecoClienteCadastro>? enderecos;
  String ultimaPesquisa = '';

  @override
  ServicoDelivery get servicoEndereco => throw UnimplementedError();

  @override
  Future<List<ClienteCadastro>> listarClientes(String pesquisa) async {
    ultimaPesquisa = pesquisa;
    return [
      ClienteCadastro.fromMap({
        'id': '10',
        'nome_puro': 'Bruno Masson',
        'celular': '(44) 99921-3336',
        'email': 'bruno@example.com',
        'obs': '',
      }),
    ];
  }

  @override
  Future<List<EnderecoClienteCadastro>> listarEnderecos(
      String idCliente) async {
    return enderecos ??
        [
          EnderecoClienteCadastro.fromMap({
            'id': '31',
            'endereco': 'Rua Luiz Roncalha',
            'numero': '169',
            'bairro': 'Centro',
            'cidade': 'Santa Fé',
            'estado': 'PR',
            'cep': '86770-000',
            'padrao': 'Sim',
            'tipolocalentrega': 'Normal',
          }),
        ];
  }

  @override
  Future<ResultadoSalvarCliente> cadastrarCliente(
    String nome,
    String celular,
    String email,
    String observacao,
  ) async =>
      (
        sucesso: true,
        idcliente: '11',
        nomecliente: nome,
        mensagem: 'Salvo',
      );

  @override
  Future<ResultadoSalvarCliente> editarCliente(
    String id,
    String nome,
    String celular,
    String email,
    String observacao,
  ) async =>
      (
        sucesso: true,
        idcliente: id,
        nomecliente: nome,
        mensagem: 'Salvo',
      );
}

void main() {
  testWidgets('lista cliente com celular, endereço e ações rápidas',
      (tester) async {
    final repositorio = _RepositorioClientesTeste();
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Bruno Masson'), findsOneWidget);
    expect(find.text('(44) 99921-3336'), findsOneWidget);
    expect(find.text('Rua Luiz Roncalha, 169'), findsOneWidget);
    expect(find.text('Centro · Santa Fé · PR\nCEP 86770-000'), findsOneWidget);
    expect(find.text('Padrão'), findsOneWidget);
    expect(find.byKey(const ValueKey('editar-cliente-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('novo-endereco-10')), findsOneWidget);
    expect(find.byKey(const ValueKey('editar-endereco-10-31')), findsOneWidget);
  });

  testWidgets('pesquisa cliente por nome ou celular com atraso curto',
      (tester) async {
    final repositorio = _RepositorioClientesTeste();
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-clientes')),
      '99921',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    expect(repositorio.ultimaPesquisa, '99921');
    expect(
        find.byKey(const ValueKey('novo-cliente-flutuante')), findsOneWidget);
  });

  testWidgets('mostra o endereco padrao antes dos demais', (tester) async {
    final repositorio = _RepositorioClientesTeste(enderecos: [
      EnderecoClienteCadastro.fromMap({
        'id': '30',
        'endereco': 'Rua Comum',
        'numero': '10',
        'padrao': 'Não',
      }),
      EnderecoClienteCadastro.fromMap({
        'id': '31',
        'endereco': 'Rua Padrão',
        'numero': '20',
        'padrao': 'Sim',
      }),
    ]);
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    final posicaoPadrao =
        tester.getTopLeft(find.byKey(const ValueKey('endereco-10-31')));
    final posicaoComum =
        tester.getTopLeft(find.byKey(const ValueKey('endereco-10-30')));
    expect(posicaoPadrao.dy, lessThan(posicaoComum.dy));
  });
}
