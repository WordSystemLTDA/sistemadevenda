import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _ServicoEnderecoTeste extends Fake implements ServicoDelivery {
  final gravacoes = <Map<String, dynamic>>[];

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    return {
      'padrao_nome_cidade': 'Lobato',
      'padrao_estado': 'PR',
      'requerido_endereco': 'Sim',
    };
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    gravacoes.add(campos);
    return {'sucesso': true};
  }
}

void main() {
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
    expect(tester.takeException(), isNull);
  });
}
