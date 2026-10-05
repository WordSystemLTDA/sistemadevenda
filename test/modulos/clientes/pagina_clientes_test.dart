import 'package:app/src/modulos/clientes/modelos/cliente_cadastro.dart';
import 'package:app/src/modulos/clientes/paginas/pagina_clientes.dart';
import 'package:app/src/modulos/clientes/servicos/servico_clientes.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _RepositorioClientesTeste implements RepositorioClientes {
  _RepositorioClientesTeste({
    this.enderecos,
    this.clientes,
    this.omitirClienteCadastrado = false,
  });

  final List<EnderecoClienteCadastro>? enderecos;
  final List<ClienteCadastro>? clientes;
  ClienteCadastro? clienteCadastrado;
  bool omitirClienteCadastrado;
  final _servicoEndereco = _ServicoEnderecoClientesTeste();
  String ultimaPesquisa = '';
  int cadastros = 0;
  int edicoes = 0;
  String? ultimoIdEditado;
  bool falharEdicao = false;
  bool vendasVinculadas = false;
  bool contasVinculadas = false;
  bool falharVerificacao = false;
  String? erroAoExcluir;
  int verificacoes = 0;
  final excluidos = <String>[];

  @override
  ServicoDelivery get servicoEndereco => _servicoEndereco;

  @override
  Future<List<ClienteCadastro>> listarClientes(String pesquisa) async {
    ultimaPesquisa = pesquisa;
    return [
      ...(clientes ??
          [
            ClienteCadastro.fromMap({
              'id': '10',
              'nome_puro': 'Bruno Masson',
              'celular': '(44) 99921-3336',
              'email': 'bruno@example.com',
              'obs': '',
            }),
          ]),
      if (clienteCadastrado != null && !omitirClienteCadastrado)
        clienteCadastrado!,
    ].where((cliente) => !excluidos.contains(cliente.id)).toList();
  }

  @override
  Future<VerificacaoExclusaoCliente> verificarExclusaoCliente(String id) async {
    verificacoes++;
    if (falharVerificacao) throw Exception('Sem conexão');
    final motivos = [
      if (vendasVinculadas) 'vendas',
      if (contasVinculadas) 'contas a receber',
    ];
    return (
      podeExcluir: motivos.isEmpty,
      vendas: vendasVinculadas,
      contasReceber: contasVinculadas,
      mensagem: motivos.isEmpty
          ? 'Sem vínculos'
          : 'Este cliente possui ${motivos.join(' e ')} vinculadas e não pode ser excluído.',
    );
  }

  @override
  Future<String> excluirCliente(String id) async {
    if (erroAoExcluir != null) throw StateError(erroAoExcluir!);
    excluidos.add(id);
    return 'Cliente excluído com sucesso.';
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
  ) async {
    cadastros++;
    clienteCadastrado = ClienteCadastro.fromMap({
      'id': '11',
      'nome_puro': nome,
      'celular': celular,
      'email': email,
      'obs': observacao,
    });
    return (
      sucesso: true,
      idcliente: '11',
      nomecliente: nome,
      mensagem: 'Salvo',
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
    edicoes++;
    ultimoIdEditado = id;
    if (falharEdicao) throw Exception('Falha simulada');
    return (
      sucesso: true,
      idcliente: id,
      nomecliente: nome,
      mensagem: 'Salvo',
    );
  }
}

class _ServicoEnderecoClientesTeste extends Fake implements ServicoDelivery {
  @override
  Future<dynamic> consultar(String rota,
          [Map<String, dynamic> campos = const {}]) async =>
      const <String, dynamic>{};

  @override
  Future<Map<String, dynamic>> salvar(
          String rota, Map<String, dynamic> campos) async =>
      const {'sucesso': true};
}

class _ServicoDeliveryGravacaoTeste extends Fake implements ServicoDelivery {
  final gravacoes = <(String, Map<String, dynamic>)>[];
  final consultas = <(String, Map<String, dynamic>)>[];
  String? idClienteResposta;
  Map<String, dynamic>? respostaExclusao;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    consultas.add((rota, campos));
    return [
      {'id': '9', 'nome_puro': 'Ana'},
      {'id': '100', 'nome_puro': 'Zeca'},
      {'id': '10', 'nome_puro': 'Bruno'},
    ];
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    gravacoes.add((rota, campos));
    if (rota == 'comandas/excluir_cliente.php') {
      return respostaExclusao ??
          {
            'sucesso': true,
            'operacao': campos['acao'] == 'consultar'
                ? 'consulta_exclusao_cliente'
                : 'cliente_excluido',
            'idcliente': campos['id'],
            'pode_excluir': true,
            'vendas': false,
            'contas_receber': false,
            'mensagem': 'Confirmado',
          };
    }
    if (campos['acao'] == 'verificar_edicao_cliente') {
      return {
        'sucesso': true,
        'recurso': 'edicao_cliente_v1',
      };
    }
    return {
      'sucesso': true,
      'idcliente': idClienteResposta ?? campos['id'] ?? '11',
      'nomecliente': campos['nome'],
      if (campos['acao'] == 'editar') 'operacao': 'cliente_editado',
    };
  }
}

Future<void> _aguardarDialogoExclusao(WidgetTester tester) async {
  // A consulta mantém o indicador ativo enquanto o usuário decide no diálogo.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
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
    expect(find.byKey(const ValueKey('excluir-cliente-10')), findsOneWidget);
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

  testWidgets('edicao limpa o filtro e recarrega todos os clientes',
      (tester) async {
    final repositorio = _RepositorioClientesTeste();
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-clientes')),
      'filtro mantido',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editar-cliente-10')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cliente-nome')),
      'Bruno Atualizado',
    );
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(repositorio.edicoes, 1);
    expect(repositorio.cadastros, 0);
    expect(repositorio.ultimoIdEditado, '10');
    final pesquisa = tester.widget<TextField>(
      find.byKey(const ValueKey('pesquisa-clientes')),
    );
    expect(pesquisa.controller?.text, isEmpty);
    expect(repositorio.ultimaPesquisa, isEmpty);
  });

  testWidgets(
      'cadastro mostra cliente salvo primeiro e volta ao topo sem filtro',
      (tester) async {
    final repositorio = _RepositorioClientesTeste(
      omitirClienteCadastrado: true,
      clientes: [
        for (var id = 20; id < 40; id++)
          ClienteCadastro.fromMap({'id': '$id', 'nome_puro': 'Cliente $id'}),
      ],
    );
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pesquisa-clientes')),
      'filtro anterior',
    );
    await tester.pump(const Duration(milliseconds: 450));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.widget<ListView>(find.byType(ListView)).controller!.offset,
        greaterThan(0));

    await tester.tap(find.byKey(const ValueKey('novo-cliente-flutuante')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('cliente-nome')),
      'Novo cliente',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cliente-endereco')),
      'Rua Teste',
    );
    await tester.enterText(
      find.byKey(const ValueKey('cliente-numero')),
      '10',
    );
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();

    expect(repositorio.cadastros, 1);
    final pesquisa = tester.widget<TextField>(
      find.byKey(const ValueKey('pesquisa-clientes')),
    );
    expect(pesquisa.controller?.text, isEmpty);
    expect(repositorio.ultimaPesquisa, isEmpty);
    final lista = tester.widget<ListView>(find.byType(ListView));
    expect(lista.controller!.offset, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('cliente-11'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('cliente-20'))).dy),
    );

    repositorio.omitirClienteCadastrado = false;
    await tester.tap(find.byTooltip('Atualizar clientes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cliente-11')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('cliente-11'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('cliente-20'))).dy),
    );
    await tester.tap(find.byKey(const ValueKey('excluir-cliente-11')));
    await _aguardarDialogoExclusao(tester);
    await tester.tap(find.byKey(const ValueKey('confirmar-exclusao-cliente')));
    await tester.pumpAndSettle();
    expect(repositorio.excluidos, ['11']);
    expect(find.byKey(const ValueKey('cliente-11')), findsNothing);
    await tester.tap(find.byTooltip('Atualizar clientes'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cliente-11')), findsNothing);
  });

  for (final caso in [
    (vendas: true, contas: false, motivo: 'vendas'),
    (vendas: false, contas: true, motivo: 'contas a receber'),
    (vendas: true, contas: true, motivo: 'vendas e contas a receber'),
  ]) {
    testWidgets('bloqueia exclusão com ${caso.motivo} vinculadas',
        (tester) async {
      final repositorio = _RepositorioClientesTeste()
        ..vendasVinculadas = caso.vendas
        ..contasVinculadas = caso.contas;
      await tester.pumpWidget(MaterialApp(
        home: PaginaClientes(repositorio: repositorio),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('excluir-cliente-10')));
      await _aguardarDialogoExclusao(tester);

      expect(find.text('Exclusão bloqueada'), findsOneWidget);
      expect(find.textContaining(caso.motivo), findsOneWidget);
      expect(find.byKey(const ValueKey('confirmar-exclusao-cliente')),
          findsNothing);
      expect(repositorio.excluidos, isEmpty);
      expect(find.text('Bruno Masson'), findsOneWidget);
    });
  }

  testWidgets('cancelar confirmação mantém o cliente', (tester) async {
    final repositorio = _RepositorioClientesTeste();
    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excluir-cliente-10')));
    await _aguardarDialogoExclusao(tester);
    expect(find.text('Excluir cliente?'), findsOneWidget);
    expect(repositorio.excluidos, isEmpty);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(repositorio.excluidos, isEmpty);
    expect(find.text('Bruno Masson'), findsOneWidget);
  });

  testWidgets('falha na consulta nunca permite confirmar a exclusão',
      (tester) async {
    final repositorio = _RepositorioClientesTeste()..falharVerificacao = true;
    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excluir-cliente-10')));
    await _aguardarDialogoExclusao(tester);
    expect(find.text('Não foi possível excluir'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('confirmar-exclusao-cliente')), findsNothing);
    expect(repositorio.excluidos, isEmpty);
  });

  testWidgets(
      'novo vínculo encontrado ao excluir mantém cliente e informa motivo',
      (tester) async {
    final repositorio = _RepositorioClientesTeste()
      ..erroAoExcluir =
          'Este cliente possui contas a receber vinculadas e não pode ser excluído.';
    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('excluir-cliente-10')));
    await _aguardarDialogoExclusao(tester);
    await tester.tap(find.byKey(const ValueKey('confirmar-exclusao-cliente')));
    await _aguardarDialogoExclusao(tester);
    expect(find.textContaining('contas a receber vinculadas'), findsOneWidget);
    expect(find.text('Bruno Masson'), findsOneWidget);
    expect(repositorio.excluidos, isEmpty);
  });

  test('serviço consulta vínculos e exclui apenas com confirmação do servidor',
      () async {
    final delivery = _ServicoDeliveryGravacaoTeste();
    final repositorio = ServicoClientes(delivery);
    final verificacao = await repositorio.verificarExclusaoCliente('10');
    expect(verificacao.podeExcluir, isTrue);
    expect(verificacao.vendas, isFalse);
    expect(verificacao.contasReceber, isFalse);
    expect(delivery.gravacoes.single.$2, {'acao': 'consultar', 'id': '10'});
    await repositorio.excluirCliente('10');
    expect(delivery.gravacoes.last.$2, {'acao': 'excluir', 'id': '10'});
    expect(delivery.gravacoes.last.$1, 'comandas/excluir_cliente.php');
  });

  test('serviço rejeita verificação incompleta ou contraditória', () async {
    final delivery = _ServicoDeliveryGravacaoTeste();
    final repositorio = ServicoClientes(delivery);
    for (final resposta in [
      {'sucesso': true},
      {
        'operacao': 'consulta_exclusao_cliente',
        'idcliente': '10',
        'pode_excluir': true,
        'vendas': true,
        'contas_receber': false
      },
    ]) {
      delivery.respostaExclusao = resposta;
      await expectLater(
          repositorio.verificarExclusaoCliente('10'), throwsStateError);
    }
  });

  test('serviço rejeita exclusão sem operação e cliente correspondentes',
      () async {
    final delivery = _ServicoDeliveryGravacaoTeste()
      ..respostaExclusao = {'operacao': 'cliente_excluido', 'idcliente': '20'};
    await expectLater(
        ServicoClientes(delivery).excluirCliente('10'), throwsStateError);
  });

  test('consulta prioriza os clientes recentes e ordena os ids numericamente',
      () async {
    final delivery = _ServicoDeliveryGravacaoTeste();
    final repositorio = ServicoClientes(delivery);

    final clientes = await repositorio.listarClientes('  cliente  ');

    expect(delivery.consultas.single.$1, 'comandas/listar_clientes.php');
    expect(delivery.consultas.single.$2,
        {'pesquisa': 'cliente', 'ordenacao': 'recentes'});
    expect(clientes.map((cliente) => cliente.id), ['100', '10', '9']);
  });

  test('servico confirma a API e envia operacao explicita ao editar', () async {
    final delivery = _ServicoDeliveryGravacaoTeste();
    final repositorio = ServicoClientes(delivery);

    final resposta = await repositorio.editarCliente(
      '10',
      'Bruno Atualizado',
      '(44) 99921-3336',
      'bruno@example.com',
      '',
    );

    expect(resposta.idcliente, '10');
    expect(delivery.gravacoes, hasLength(2));
    expect(delivery.gravacoes.first.$2['acao'], 'verificar_edicao_cliente');
    expect(delivery.gravacoes.last.$1, 'comandas/inserir_cliente.php');
    expect(delivery.gravacoes.last.$2['acao'], 'editar');
    expect(delivery.gravacoes.last.$2['id'], '10');
    expect(delivery.gravacoes.last.$2['idCliente'], '10');
  });

  test('cadastro usa somente a rota de insercao e nao envia id', () async {
    final delivery = _ServicoDeliveryGravacaoTeste();
    final repositorio = ServicoClientes(delivery);

    await repositorio.cadastrarCliente(
      'Novo cliente',
      '(44) 99999-0000',
      '',
      '',
    );

    expect(delivery.gravacoes, hasLength(1));
    expect(delivery.gravacoes.single.$1, 'comandas/inserir_cliente.php');
    expect(delivery.gravacoes.single.$2['acao'], 'cadastrar');
    expect(delivery.gravacoes.single.$2, isNot(contains('id')));
    expect(delivery.gravacoes.single.$2, isNot(contains('idCliente')));
  });

  test('edicao rejeita resposta com id de um novo cadastro', () async {
    final delivery = _ServicoDeliveryGravacaoTeste()..idClienteResposta = '99';
    final repositorio = ServicoClientes(delivery);

    await expectLater(
      repositorio.editarCliente('10', 'Bruno Atualizado', '', '', ''),
      throwsA(isA<StateError>()),
    );
    expect(delivery.gravacoes, hasLength(2));
    expect(delivery.gravacoes.last.$2['acao'], 'editar');
  });

  testWidgets('falha na edicao nunca mostra mensagem de cadastro',
      (tester) async {
    final repositorio = _RepositorioClientesTeste()..falharEdicao = true;
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: PaginaClientes(repositorio: repositorio),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('editar-cliente-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(repositorio.edicoes, 1);
    expect(repositorio.cadastros, 0);
    expect(find.text('Não foi possível editar o cliente.'), findsOneWidget);
    expect(find.text('Não foi possível cadastrar o cliente.'), findsNothing);
    expect(find.text('Editar cliente'), findsOneWidget);
  });
}
