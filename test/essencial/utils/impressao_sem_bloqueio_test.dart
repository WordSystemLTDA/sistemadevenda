import 'dart:convert';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'envio_impressao_test.dart' show CanalTeste, SaidaTeste;
import 'fila_impressao_test.dart' show mensagem;
import 'impressao_preparo_test.dart'
    show produto, ServidorTeste, ModuloImpressaoTeste;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'produto e combo sem impressora nao criam fila; destinos validos permanecem',
      () {
    Modular.init(ModuloImpressaoTeste(ServidorTeste()));
    addTearDown(Modular.destroy);
    final vazio = produto()
      ..destinoDeImpressao = ModeloDestinoImpressao(
          nome: 'Cozinha',
          nomeDaImpressora: '  ',
          tamanhoDoPapel: '42',
          nomedopc: 'PC');
    final desativado = produto()
      ..destinoDeImpressao = ModeloDestinoImpressao(
          nome: 'Bar',
          nomeDaImpressora: ' Sem Impressora ',
          tamanhoDoPapel: '42');
    expect(
        Impressao.prepararComprovanteDePedido(
            produtos: [produto(), vazio, desativado]),
        isEmpty);
    final combo = produto()
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
            id: 2,
            titulo: 'Combos',
            obrigatorio: false,
            dados: [],
            produtos: [
              vazio,
              desativado,
              produto(id: 'pizza', computador: 'Cozinha'),
              produto(id: 'bebida', computador: 'Bar')
            ])
      ];
    final mensagens = Impressao.prepararComprovanteDePedido(produtos: [combo])
        .map((item) => jsonDecode(item) as Map)
        .toList();
    expect(mensagens.map((item) => item['nomedopc']), ['Cozinha', 'Bar']);
    expect(
        mensagens
            .expand((item) => item['produtos'] as List)
            .map((item) => item['id']),
        ['pizza', 'bebida']);
  });

  test('fila grande envia apenas tres mensagens por ciclo', () async {
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final enviados = <dynamic>[];
    server.channel = CanalTeste(SaidaTeste(enviados.add));
    await server.enviarImpressoes(List.generate(50, (i) => mensagem('$i')));
    expect(enviados, hasLength(3));
    expect(server.filaImpressao.itens, hasLength(50));
  });

  testWidgets('lotes seguintes saem sem esperar cinco segundos e sem duplicar',
      (tester) async {
    final server = Server()..connected = true;
    final enviados = <dynamic>[];
    server.channel = CanalTeste(SaidaTeste(enviados.add));
    await server
        .enviarImpressoes(List.generate(7, (i) => mensagem('rapido-$i')));
    expect(enviados, hasLength(3));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(enviados, hasLength(6));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(enviados, hasLength(7));
    await tester.pump(const Duration(seconds: 1));
    expect(enviados, hasLength(7));
    expect(server.filaImpressao.itens, hasLength(7));
    server.dispose();
  });

  testWidgets('falha de armazenamento nao cria repeticoes rapidas',
      (tester) async {
    final fila = _FilaSemGravacao();
    final server = Server(filaImpressao: fila)..connected = true;
    server.channel =
        CanalTeste(SaidaTeste((_) => fail('Nao deve enviar sem gravar')));
    await server.enviarImpressoes([mensagem('sem-disco')]);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(fila.tentativas, 1);
    expect(fila.itens.single.estado, EstadoImpressao.aguardandoEnvio);
    server.dispose();
  });

  test(
      'pedido novo tem prioridade sobre consultas antigas sem reenviar as vias',
      () async {
    final server = Server(agora: () => DateTime(2026))..connected = true;
    addTearDown(server.dispose);
    final enviados = <Map<String, dynamic>>[];
    server.channel = CanalTeste(SaidaTeste((data) => enviados.add(
        Map<String, dynamic>.from(
            jsonDecode(data as String)['data']['customData']))));
    for (var i = 0; i < 4; i++) {
      await server.filaImpressao.registrar([mensagem('antigo-$i')]);
      await server.filaImpressao
          .iniciarEnvio('antigo-$i', agora: DateTime(2020));
    }
    await server.enviarImpressoes([mensagem('novo')]);
    expect(enviados, hasLength(3));
    expect(enviados.first['idRequisicao'], 'novo');
    expect(
        enviados
            .skip(1)
            .every((dados) => dados['tipo'] == 'ConsultarImpressao'),
        isTrue);
  });

  test('servidor sem resposta continua consultas sem repetir a impressao',
      () async {
    var agora = DateTime(2026);
    final server = Server(agora: () => agora)..connected = true;
    addTearDown(server.dispose);
    final enviados = <dynamic>[];
    server.channel = CanalTeste(SaidaTeste(enviados.add));
    await server.enviarImpressoes([mensagem('sem-resposta')]);
    for (var i = 0; i < 10; i++) {
      agora = agora.add(const Duration(minutes: 2));
      await server.processarImpressoesPendentes();
    }
    expect(enviados, hasLength(11));
    final mensagens = enviados
        .map((e) => jsonDecode(e as String)['data']['customData'] as Map)
        .toList();
    expect(mensagens.where((e) => e['tipoImpressao'] == '1'), hasLength(1));
    expect(mensagens.skip(1).every((e) => e['tipo'] == 'ConsultarImpressao'),
        isTrue);
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.semConfirmacao);
  });

  test('limpeza offline persiste e envia somente cancelamento na reconexao',
      () async {
    final original = Server();
    await original.enviarImpressoes([mensagem('cancelar')]);
    await original.limparImpressoes(['cancelar']);
    original.dispose();
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final enviados = <Map<String, dynamic>>[];
    server.channel = CanalTeste(SaidaTeste((data) => enviados.add(
        Map<String, dynamic>.from(
            jsonDecode(data as String)['data']['customData']))));
    await server.processarImpressoesPendentes();
    expect(enviados.single['tipo'], 'CancelarImpressao');
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'protocoloImpressao': 2,
      'statusResposta': 'naoEncontrada',
      'idRequisicao': 'cancelar'
    });
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.cancelamentoPendente);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'protocoloImpressao': 2,
      'statusResposta': 'cancelada',
      'idRequisicao': 'cancelar'
    });
    expect(server.filaImpressao.itens, isEmpty);
    await server.filaImpressao.registrar([mensagem('cancelar')]);
    expect(server.filaImpressao.itens, isEmpty);
  });

  test('limpeza nao interfere no pedido ainda sendo gravado', () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('salvando')],
        estado: EstadoImpressao.aguardandoPedido);
    await fila.registrar([mensagem('pendente')]);
    await fila.cancelarLote({'salvando', 'pendente'});
    expect(fila.itens.first.estado, EstadoImpressao.aguardandoPedido);
    expect(fila.itens.last.estado, EstadoImpressao.cancelamentoPendente);
    await fila.autorizarReenvio('pendente', manual: true);
    expect(await fila.iniciarEnvio('pendente'), isFalse);
  });

  test('retomada manual conserva ID e renova limite com token explicito',
      () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('retomar')]);
    await fila.iniciarEnvio('retomar');
    await fila.pausar('retomar', 'Confira a cozinha');
    await fila.autorizarReenvio('retomar', manual: true);
    expect(fila.itens.single.id, 'retomar');
    expect(fila.itens.single.tentativas, 0);
    expect(fila.itens.single.dados['retomadaImpressao'], isNotEmpty);
    expect(await fila.iniciarEnvio('retomar'), isTrue);
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
        'limpar pede confirmacao e funciona em celular com fonte $escala',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await fila.registrar([mensagem('limpar')]);
      var limpezas = 0;
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: PendenciasImpressao(
              fila: fila,
              reenviar: (_) async {},
              limpar: (ids) async {
                limpezas++;
                await fila.cancelarLote(ids.toSet());
              })));
      await tester.tap(find.byTooltip('Limpar pendências'));
      await tester.pumpAndSettle();
      expect(limpezas, 0);
      await tester.tap(find.widgetWithText(FilledButton, 'Limpar'));
      await tester.pumpAndSettle();
      expect(limpezas, 1);
      expect(fila.itens.single.estado, EstadoImpressao.cancelamentoPendente);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FilaSemGravacao extends FilaImpressao {
  int tentativas = 0;
  @override
  Future<bool> iniciarEnvio(String id, {DateTime? agora}) async {
    tentativas++;
    throw StateError('Disco indisponivel');
  }
}
