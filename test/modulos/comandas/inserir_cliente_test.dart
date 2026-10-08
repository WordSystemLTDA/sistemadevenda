import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicoEnderecoTeste extends Fake implements ServicoDelivery {
  _ServicoEnderecoTeste({
    this.configuracaoEndereco = const {
      'padrao_nome_cidade': 'Lobato',
      'padrao_estado': 'PR',
      'requerido_endereco': 'Sim',
    },
  });

  final Map<String, dynamic> configuracaoEndereco;
  final gravacoes = <Map<String, dynamic>>[];
  bool falharUmaVez = false;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    return configuracaoEndereco;
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    gravacoes.add(campos);
    if (falharUmaVez) {
      falharUmaVez = false;
      throw StateError('Não foi possível salvar o endereço.');
    }
    return {'sucesso': true};
  }
}

void main() {
  testWidgets('recusa de cadastro exibe motivo e nao tenta cadastrar endereco',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final servico = _ServicoEnderecoTeste();
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: servico,
        aoCadastrarCliente: (nome, celular, email, observacao) async => (
          sucesso: false,
          idcliente: '',
          nomecliente: '',
          mensagem: 'Este celular já está cadastrado.',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-endereco')), 'Rua A');
    await tester.enterText(find.byKey(const ValueKey('cliente-numero')), '10');
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Este celular já está cadastrado.'), findsOneWidget);
    expect(servico.gravacoes, isEmpty);
    expect(find.text('Salvar cliente e endereço'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repetir apos falha no endereco usa o cliente ja cadastrado',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final servico = _ServicoEnderecoTeste()..falharUmaVez = true;
    var cadastros = 0;
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: servico,
        aoCadastrarCliente: (nome, celular, email, observacao) async {
          cadastros++;
          return (
            sucesso: true,
            idcliente: '7',
            nomecliente: nome,
            mensagem: 'Salvo'
          );
        },
      ),
    ));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-endereco')), 'Rua A');
    await tester.enterText(find.byKey(const ValueKey('cliente-numero')), '10');
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível salvar o endereço.'), findsOneWidget);
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();
    expect(cadastros, 1);
    expect(servico.gravacoes, hasLength(2));
    expect(
        servico.gravacoes.every((dados) => dados['idCliente'] == '7'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cadastro do cliente oculta cidade e UF e conserva os valores padrao',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final servico = _ServicoEnderecoTeste();
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: servico,
        aoCadastrarCliente: (nome, celular, email, observacao) async => (
          sucesso: true,
          idcliente: '7',
          nomecliente: nome,
          mensagem: 'Cliente cadastrado',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cliente-cidade')), findsNothing);
    expect(find.byKey(const ValueKey('cliente-uf')), findsNothing);

    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente Teste');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-endereco')), 'Rua A');
    await tester.enterText(find.byKey(const ValueKey('cliente-numero')), '10');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-bairro')), 'Centro');
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();

    expect(servico.gravacoes, hasLength(1));
    expect(servico.gravacoes.single['cidade'], 'Lobato');
    expect(servico.gravacoes.single['uf'], 'PR');
    expect(servico.gravacoes.single['tipoLocalEntrega'], 'Normal');
    expect(servico.gravacoes.single['podeInserirNovaCidade'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro exige somente rua e numero do endereco',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final servico = _ServicoEnderecoTeste(configuracaoEndereco: const {});
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: servico,
        aoCadastrarCliente: (nome, celular, email, observacao) async => (
          sucesso: true,
          idcliente: '9',
          nomecliente: nome,
          mensagem: 'Cliente cadastrado',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente Teste');
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsNWidgets(2));
    expect(servico.gravacoes, isEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('cliente-endereco')), 'Avenida Brasil');
    await tester.enterText(find.byKey(const ValueKey('cliente-numero')), '25');
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();

    expect(servico.gravacoes, hasLength(1));
    expect(servico.gravacoes.single['cep'], isEmpty);
    expect(servico.gravacoes.single['bairro'], isEmpty);
    expect(servico.gravacoes.single['cidade'], isEmpty);
    expect(servico.gravacoes.single['uf'], isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cadastro do cliente salva endereco em sitio quando selecionado',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final servico = _ServicoEnderecoTeste();
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: servico,
        aoCadastrarCliente: (nome, celular, email, observacao) async => (
          sucesso: true,
          idcliente: '8',
          nomecliente: nome,
          mensagem: 'Cliente cadastrado',
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente do Sítio');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-endereco')), 'Estrada Rural');
    await tester.enterText(find.byKey(const ValueKey('cliente-numero')), 'S/N');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-bairro')), 'Zona Rural');
    await tester.tap(find.byKey(const ValueKey('cliente-endereco-sitio')));
    await tester.tap(find.text('Salvar cliente e endereço'));
    await tester.pumpAndSettle();

    expect(servico.gravacoes, hasLength(1));
    expect(servico.gravacoes.single['tipoLocalEntrega'], 'Sitio');
    expect(tester.takeException(), isNull);
  });

  testWidgets('edicao preenche os dados e atualiza o mesmo cliente',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    String? nomeSalvo, celularSalvo, emailSalvo, observacaoSalva;
    await tester.pumpWidget(MaterialApp(
      home: InserirCliente(
        servicoEndereco: _ServicoEnderecoTeste(),
        idCliente: '7',
        dadosIniciais: const {
          'nome_puro': 'Cliente Antigo',
          'celular': '(44) 99999-1111',
          'email': 'antigo@teste.com',
          'obs': 'Observação antiga',
        },
        aoEditarCliente: (nome, celular, email, observacao) async {
          nomeSalvo = nome;
          celularSalvo = celular;
          emailSalvo = email;
          observacaoSalva = observacao;
          return (
            sucesso: true,
            idcliente: '7',
            nomecliente: nome,
            mensagem: 'Cliente atualizado com sucesso',
          );
        },
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Editar cliente'), findsOneWidget);
    expect(find.text('EDIÇÃO DE CADASTRO'), findsOneWidget);
    expect(find.byKey(const ValueKey('cliente-endereco')), findsNothing);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cliente-nome')))
            .controller!
            .text,
        'Cliente Antigo');
    expect(
        tester
            .widget<TextFormField>(
                find.byKey(const ValueKey('cliente-celular')))
            .controller!
            .text,
        '(44) 99999-1111');

    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Cliente Atualizado');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-email')), 'novo@teste.com');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-observacao')), 'Nova observação');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(nomeSalvo, 'Cliente Atualizado');
    expect(celularSalvo, '(44) 99999-1111');
    expect(emailSalvo, 'novo@teste.com');
    expect(observacaoSalva, 'Nova observação');
    expect(tester.takeException(), isNull);
  });
}
