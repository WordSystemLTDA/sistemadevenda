import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/widgets/card_resumo_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/transferencias/servico_transferencias.dart';
import 'package:app/src/modulos/transferencias/transferencia_atendimento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../suporte/captura_tela.dart';
import '../cardapio/card_carrinho_test.dart' show produtoCarrinho;

const origem = AlvoTransferencia(
    id: '1',
    atendimento: '101',
    nome: 'Comanda: 1',
    tipo: 'comanda',
    versao: 'original',
    total: '12.34');
const destino = AlvoTransferencia(
    id: '2',
    atendimento: '102',
    nome: 'Comanda: 2',
    tipo: 'comanda',
    versao: 'destino',
    total: '24.68');
const livre = AlvoTransferencia(
    id: '3',
    atendimento: '0',
    nome: 'Comanda: 3',
    tipo: 'comanda',
    versao: 'livre',
    livre: true);

class ApiTeste extends DioCliente {
  final chamadas = <RequestOptions>[];
  int? recusar;
  bool cair = false, antigo = false;
  Map? recibo;
  Completer<void>? espera;
  ApiTeste() {
    cliente.interceptors.clear();
    cliente.interceptors
        .add(InterceptorsWrapper(onRequest: (op, handler) async {
      chamadas.add(op);
      if (op.method == 'POST') {
        await espera?.future;
        if (recusar != null) {
          handler.reject(DioException(
              requestOptions: op,
              type: DioExceptionType.badResponse,
              response: Response(
                  requestOptions: op,
                  statusCode: recusar,
                  data: {'mensagem': 'Atendimento alterado'})));
          return;
        }
        recibo = {
          'sucesso': true,
          'id_operacao': op.data['id_operacao'],
          'id_comanda_pedido': '102'
        };
        if (cair) {
          handler.reject(DioException(
              requestOptions: op, type: DioExceptionType.receiveTimeout));
          return;
        }
      }
      handler.resolve(Response(
          requestOptions: op,
          statusCode: 200,
          data: antigo
              ? '<html>404</html>'
              : op.method == 'POST'
                  ? recibo
                  : {
                      'protocolo': 1,
                      'sucesso': true,
                      'recursos': [
                        origem.toMap(),
                        destino.toMap(),
                        livre.toMap()
                      ],
                      'resposta': recibo
                    }));
    }));
  }
}

class ServicoTeste extends Fake implements ServicoTransferencias {
  int envios = 0, verificacoes = 0;
  String? erro;
  bool mostrar = true, falharEnvio = false;
  TransferenciaPendente? anterior;
  List<AlvoTransferencia> recursos = [origem, destino, livre];
  Completer<void>? espera;
  @override
  bool get mostrarValores => mostrar;
  @override
  Future<void> iniciar() async {}
  @override
  Future<TransferenciaPendente?> pendente() async => anterior;
  @override
  Future<List<AlvoTransferencia>> listar(String tipo) async {
    if (erro != null) throw FalhaTransferencia(erro!);
    return recursos;
  }

  @override
  Future<void> validarPendencias(
      AlvoTransferencia a, AlvoTransferencia b) async {}
  @override
  Future<void> confirmar(AlvoTransferencia a, AlvoTransferencia b) async {
    envios++;
    await espera?.future;
    if (falharEnvio)
      throw const FalhaTransferencia('Conexao interrompida', pendente: true);
  }

  @override
  Future<void> verificarPendente() async {
    verificacoes++;
  }

  @override
  Future<List<Map<String, dynamic>>> historico(AlvoTransferencia a,
          {String? antes}) async =>
      [
        {
          'id': '1',
          'nome_origem': origem.nome,
          'nome_destino': destino.nome,
          'atendimento_origem': '101',
          'atendimento_destino': '102',
          'usuario': '1',
          'criado_em': '2026-09-12 23:00:00',
          'total_origem': '12.34',
          'observacao_origem': 'Cliente de teste'
        }
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
  });

  group('servico', () {
    late ApiTeste api;
    late UsuarioProvedor usuario;
    late ServicoTransferencias servico;
    setUp(() async {
      api = ApiTeste();
      usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
      servico = ServicoTransferencias(api, usuario);
      await servico.iniciar();
    });
    tearDown(() {
      api.cliente.close();
      usuario.dispose();
    });

    test('consulta direta sem cache e sem mutacao', () async {
      expect(await servico.listar('comanda'), hasLength(3));
      expect(api.chamadas.single.extra['semCache'], isTrue);
      expect(api.chamadas.single.extra['servidorFixo'],
          contains('http://cozinha/'));
      expect(api.chamadas.single.method, 'GET');
    });
    test('API antiga falha explicitamente', () async {
      api.antigo = true;
      await expectLater(
          servico.listar('mesa'), throwsA(isA<FalhaTransferencia>()));
    });
    test(
        'perda de resposta sobrevive a reinicio e consulta recibo sem duplicar',
        () async {
      api.cair = true;
      await expectLater(
          servico.confirmar(origem, destino),
          throwsA(isA<FalhaTransferencia>()
              .having((e) => e.pendente, 'pendente', isTrue)));
      final id = (await servico.pendente())!.entrada['id_operacao'];
      final reiniciado = ServicoTransferencias(api, usuario);
      await reiniciado.iniciar();
      expect((await reiniciado.pendente())!.entrada['id_operacao'], id);
      await reiniciado.verificarPendente();
      expect(await reiniciado.pendente(), isNull);
      expect(api.chamadas.where((e) => e.method == 'POST'), hasLength(1));
    });
    test('duplo toque nao gera duas operacoes', () async {
      api.espera = Completer();
      final primeiro = servico.confirmar(origem, destino);
      final segundo = servico.confirmar(origem, destino);
      api.espera!.complete();
      await primeiro;
      await segundo;
      expect(api.chamadas.where((e) => e.method == 'POST'), hasLength(1));
    });
    test('conflito definitivo libera somente o recibo local', () async {
      api.recusar = 409;
      await expectLater(servico.confirmar(origem, destino),
          throwsA(isA<FalhaTransferencia>()));
      expect(await servico.pendente(), isNull);
    });
    test('rascunho bloqueia transferencia sem apagar produto', () async {
      const contexto = ContextoCarrinho(
          empresa: '32', tipo: 'comanda', idAtendimento: '101');
      final carrinhos = ArmazenamentoCarrinhos.instancia;
      await carrinhos.alterar(
          contexto, (itens) => itens.add(produtoCarrinho()));
      await expectLater(servico.confirmar(origem, destino),
          throwsA(isA<FalhaTransferencia>()));
      expect(api.chamadas, isEmpty);
      expect(await carrinhos.listar(contexto), hasLength(1));
    });
    test('operacao ou impressao pendente bloqueia uniao', () async {
      sqfliteFfiInit();
      final banco = await BancoLocal.abrir(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      BancoLocal.instancia = banco;
      addTearDown(() async {
        BancoLocal.instancia = null;
        await banco.db.close();
      });
      final escopo = BancoLocal.escopo(
          'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api1/',
          '32',
          '1');
      await banco.db.insert('operacoes', {
        'id': 'pedido',
        'escopo': escopo,
        'atendimento': '101',
        'acao': 'produtos',
        'estado': 'impressao',
        'dados': '{}',
        'impressoes': '[]',
        'destino': 'Comanda 1',
        'criado': 1
      });
      await expectLater(servico.confirmar(origem, destino),
          throwsA(isA<FalhaTransferencia>()));
      expect(api.chamadas, isEmpty);
      expect(await banco.operacoes(escopo), hasLength(1));
    });
    test('pendencia nao migra para outro servidor ou usuario', () async {
      api.cair = true;
      await expectLater(servico.confirmar(origem, destino),
          throwsA(isA<FalhaTransferencia>()));
      usuario.setUsuario(UsuarioModelo(id: '2', empresa: '32'));
      final outro = ServicoTransferencias(api, usuario);
      await outro.iniciar();
      expect(await outro.pendente(), isNull);
    });
  });

  Future<void> tela(WidgetTester tester, Widget child,
      {double largura = 393, double escala = 1, bool escuro = false}) async {
    tester.view.physicalSize = Size(largura, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
            theme: ThemeData(
                brightness: escuro ? Brightness.dark : Brightness.light,
                fontFamily: 'Roboto'),
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(escala)),
                child: child!),
            home: Scaffold(body: child))));
    await tester.pumpAndSettle();
  }

  for (final largura in [320.0, 393.0, 800.0]) {
    testWidgets('card compacto e confirmacao responsivos $largura',
        (tester) async {
      await tela(
          tester,
          ListView(padding: const EdgeInsets.all(12), children: [
            CardResumoAtendimento(
                nome: 'Comanda: 4',
                cliente: 'Bruno Masson',
                codigo: '',
                ocupada: true,
                fechamento: false,
                tipoMesa: false,
                atendimento: '10703',
                mesa: 'Mesa: 4',
                total: 'R\$ 344,00',
                tempo: const Text('Aberta ha 1 hora 3 min'),
                ultimoPedido: const Text('Ultimo pedido ha 17 min'),
                menu: IconButton(
                    onPressed: () {}, icon: const Icon(Icons.more_vert)),
                onAbrir: () {}),
            const SizedBox(height: 10),
            CardResumoAtendimento(
                nome: 'Comanda: 1',
                cliente: '',
                codigo: '',
                ocupada: false,
                fechamento: false,
                tipoMesa: false,
                tempo: const Text('Nunca utilizada'),
                onAbrir: () {}),
          ]),
          largura: largura);
      expect(tester.takeException(), isNull);
      if (largura == 393 &&
          const String.fromEnvironment('FONTE_TESTE').isNotEmpty) {
        expect(tester.getSize(find.byType(CardResumoAtendimento).first).height,
            lessThan(140));
      }
      await capturarTela(tester, 'transferencia_cards_${largura.toInt()}');
      final servico = ServicoTeste();
      await tela(
          tester,
          DialogoTransferencia(
              servico: servico, origem: origem, destino: destino),
          largura: largura,
          escala: largura == 320 ? 2 : 1,
          escuro: largura == 800);
      expect(tester.takeException(), isNull);
      expect(servico.envios, 0);
      expect(find.text('Confirmar uniao'), findsOneWidget);
      await capturarTela(
          tester, 'transferencia_confirmacao_${largura.toInt()}');
    });
  }

  testWidgets('arrastar so seleciona destino; soltar exige confirmacao',
      (tester) async {
    AlvoTransferencia? recebido;
    await tela(
        tester,
        Column(children: [
          AreaTransferencia(
              alvo: origem,
              child: const SizedBox(
                  width: 300, height: 100, child: Text('Origem'))),
          AreaTransferencia(
              alvo: destino,
              aoSoltar: (a, b) => recebido = a,
              child: const SizedBox(
                  width: 300, height: 100, child: Text('Destino'))),
        ]));
    final gesto =
        await tester.startGesture(tester.getCenter(find.text('Origem')));
    await tester.pump(const Duration(milliseconds: 600));
    await gesto.moveTo(tester.getCenter(find.text('Destino')));
    await tester.pump();
    expect(recebido, isNull);
    await gesto.up();
    await tester.pumpAndSettle();
    expect(recebido, origem);
  });
  testWidgets('escolher destino e confirmar envia uma vez', (tester) async {
    final servico = ServicoTeste();
    await tela(tester, DialogoTransferencia(servico: servico, origem: origem));
    await tester.tap(find.text(destino.nome));
    await tester.pumpAndSettle();
    expect(servico.envios, 0);
    await tester.tap(find.text('Confirmar uniao'));
    await tester.pumpAndSettle();
    expect(servico.envios, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('destino reutilizado impede confirmacao', (tester) async {
    final servico = ServicoTeste()
      ..recursos = [
        origem,
        const AlvoTransferencia(
            id: '2', atendimento: '999', nome: 'Comanda 2', tipo: 'comanda')
      ];
    await tela(
        tester,
        DialogoTransferencia(
            servico: servico, origem: origem, destino: destino));
    expect(find.textContaining('O destino mudou'), findsOneWidget);
    expect(find.text('Confirmar uniao'), findsNothing);
    expect(servico.envios, 0);
  });
  testWidgets('queda apresenta verificacao sem habilitar outra uniao',
      (tester) async {
    final servico = ServicoTeste()..falharEnvio = true;
    await tela(
        tester,
        DialogoTransferencia(
            servico: servico, origem: origem, destino: destino));
    await tester.tap(find.text('Confirmar uniao'));
    await tester.pumpAndSettle();
    expect(find.text('Verificar transferencia'), findsOneWidget);
    expect(find.text('Escolher outro destino'), findsNothing);
    await tester.tap(find.text('Verificar transferencia'));
    await tester.pumpAndSettle();
    expect(servico.envios, 1);
    expect(servico.verificacoes, 1);
  });
  testWidgets('historico mostra origem, destino, usuario e observacao',
      (tester) async {
    await tela(
        tester, HistoricoTransferencias(servico: ServicoTeste(), alvo: origem));
    expect(find.textContaining('Usuario #1'), findsOneWidget);
    expect(find.textContaining('Atendimentos #101 / #102'), findsOneWidget);
    expect(find.text('Cliente de teste'), findsOneWidget);
    await capturarTela(tester, 'transferencia_historico');
  });
}
