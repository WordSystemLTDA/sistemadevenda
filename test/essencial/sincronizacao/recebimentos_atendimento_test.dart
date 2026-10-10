import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/recebimentos_atendimento.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_conta_atendimento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;
import 'sincronizacao_test.dart' show SocketOfflineTeste;

class _ModuloRecebimentoOffline extends Module {
  final DioCliente api;
  final UsuarioProvedor usuario;
  final Server servidor;
  _ModuloRecebimentoOffline(this.api, this.usuario, this.servidor);
  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(ServicoCardapio(api, usuario));
    i.addInstance<ServicoFinalizarPagamento>(
        ServicoFinalizarPagamento(api, usuario));
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<Server>(servidor);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory pasta;
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late Sincronizador sync;
  late RecebimentosAtendimento recebimentos;
  var conectado = false;
  var perderResposta = false;
  var recusarAbertura = false;
  var saldoMudou = false;
  final recibos = <String, Map<String, dynamic>>{};
  final enviados = <Map<String, dynamic>>[];

  setUp(() async {
    conectado = perderResposta = recusarAbertura = saldoMudou = false;
    recibos.clear();
    enviados.clear();
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
    pasta = await Directory.systemTemp.createTemp('recebimento-offline-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/dados.db');
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '2', nome: 'Garçom'));
    sync = Sincronizador(api, usuario, SocketOfflineTeste(), banco: banco);
    Sincronizador.instancia = sync;
    api.cliente.interceptors.add(InterceptorsWrapper(onRequest: (op, handler) {
      if (!conectado) {
        handler.reject(
            DioException(
                requestOptions: op, type: DioExceptionType.connectionError),
            true);
        return;
      }
      final dados = Map<String, dynamic>.from(jsonDecode(op.data as String));
      enviados.add(dados);
      if (recusarAbertura && dados['acao'] == 'abertura' ||
          saldoMudou && dados.containsKey('recebimento_offline')) {
        handler.reject(DioException(
            requestOptions: op,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: op, statusCode: 409, data: {
              'protocolo': 1,
              'sucesso': false,
              'codigo': 'recurso_reutilizado',
              'mensagem': 'A conta mudou no servidor.'
            })));
        return;
      }
      final id = dados['id_operacao'] as String;
      final offline = dados['recebimento_offline'] as Map?;
      final pago = offline == null
          ? 0
          : (offline['pago_antes_centavos'] as int) +
              ((double.parse(dados['valor_lancamento']) -
                          double.parse(dados['valortroco'])) *
                      100)
                  .round();
      final recibo = recibos.putIfAbsent(
          id,
          () => {
                'protocolo': 1,
                'sucesso': true,
                'id_operacao': id,
                if (dados['acao'] == 'abertura') ...{
                  'id_comanda_pedido': '201',
                  'versao_atendimento': 'versao-201',
                  'numeroPedido': '31'
                },
                if (offline != null) ...{
                  'somaValorHistorico': (pago / 100).toStringAsFixed(2),
                  'finalizouPedido':
                      pago == offline['total_centavos'] ? '1' : '2',
                  'idVenda': pago == offline['total_centavos'] ? '301' : '0'
                },
              });
      if (perderResposta && offline != null) {
        perderResposta = false;
        handler.reject(DioException(
            requestOptions: op, type: DioExceptionType.receiveTimeout));
        return;
      }
      handler
          .resolve(Response(requestOptions: op, statusCode: 200, data: recibo));
    }));
    await sync.configurar();
    recebimentos = RecebimentosAtendimento(banco, sync.escopo);
    await banco.gravar(
        'estado:${sync.escopo}',
        jsonEncode({
          'recebimento_atendimento_offline': 1,
          'caixa_id': '7',
          'atendimentos': {
            '104': {'versao': 'versao-104'}
          }
        }));
    await banco.guardarConsulta(
        sync.escopo,
        CacheConsultas.chave(RequestOptions(
            path: 'config_bigchef/listar.php',
            queryParameters: {'empresa': '2'})),
        {'permitirfinalizarmesa': 'Sim', 'permitirfinalizarcomanda': 'Sim'});
  });

  tearDown(() async {
    await sync.enviarPendentes();
    sync.dispose();
    Sincronizador.instancia = null;
    BancoLocal.instancia = null;
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  Future<String> abrir(TipoCardapio tipo) async {
    final id = await AtendimentosLocais(banco, sync.escopo).abrir({
      'tipo': tipo.name,
      'empresa': '2',
      'id_usuario': '1',
      'id_mesa': tipo == TipoCardapio.mesa ? '5' : '0',
      'id_comanda': tipo == TipoCardapio.comanda ? '5' : '0',
      'detalhe': {
        'idMesa': tipo == TipoCardapio.mesa ? '5' : '0',
        'idComanda': tipo == TipoCardapio.comanda ? '5' : '0',
        'nome': '${tipo.nome}: 5',
        'nomeCliente': 'Cliente',
        'idCliente': '0'
      },
    }, sync.destino);
    await banco.db.insert('operacoes', {
      'id': BancoLocal.novoId(),
      'escopo': sync.escopo,
      'atendimento': id,
      'acao': 'produtos',
      'estado': 'pendente',
      'dados': jsonEncode({
        'empresa': '2',
        'id_usuario': '1',
        'tipo': tipo.name,
        'id_abertura': id.substring(6),
        'produtos': [produto().toMap()]
      }),
      'impressoes': '[]',
      'destino': sync.destino,
      'criado': DateTime.now().millisecondsSinceEpoch
    });
    return id;
  }

  Future<
          ({
            bool sucesso,
            String mensagem,
            bool finalizou,
            String idVenda,
            double totalPago
          })>
      pagar(String id, TipoCardapio tipo,
          {double valor = 50, int pessoas = 1, double troco = 0}) {
    return ServicoFinalizarPagamento(api, usuario).pagarContaAtendimento(
        id: id,
        idComanda: tipo == TipoCardapio.comanda ? '5' : '0',
        idMesa: tipo == TipoCardapio.mesa ? '5' : '0',
        cliente: '0',
        tipo: tipo,
        valorLancamento: valor,
        valorOriginal: 50,
        valorAPagar: 50,
        troco: troco,
        pagamentoSelecionado: 1,
        quantidadePessoas: pessoas,
        vencimento: DateTime.now(),
        produtosParaFinalizar: [],
        modoProdutoParcial: false,
        salvarOffline: true,
        nomeForma: 'Dinheiro');
  }

  for (final tipo in [TipoCardapio.comanda, TipoCardapio.mesa]) {
    test(
        '${tipo.nome} da empresa 2 aceita configuracao antiga com nomes das colunas',
        () async {
      await banco.guardarConsulta(
          sync.escopo,
          CacheConsultas.chave(RequestOptions(
            path: 'config_bigchef/listar.php',
            queryParameters: {'empresa': '2'},
          )),
          {
            'permitir_finalizar_mesa': 'Sim',
            'permitir_finalizar_comanda': 'Sim'
          });
      final id = await abrir(tipo);
      await recebimentos.preparar(id, tipo.name);
      expect((await pagar(id, tipo)).finalizou, true);
    });

    test(
        '${tipo.nome} continua bloqueada quando sua permissao esta desabilitada',
        () async {
      await banco.guardarConsulta(
          sync.escopo,
          CacheConsultas.chave(RequestOptions(
            path: 'config_bigchef/listar.php',
            queryParameters: {'empresa': '2'},
          )),
          {
            'permitirfinalizarmesa': tipo == TipoCardapio.mesa ? 'Não' : 'Sim',
            'permitirfinalizarcomanda':
                tipo == TipoCardapio.comanda ? 'Não' : 'Sim'
          });
      final id = await abrir(tipo);
      await expectLater(
          recebimentos.preparar(id, tipo.name),
          throwsA(isA<StateError>().having(
              (e) => e.message, 'mensagem', contains('não está habilitado'))));
      expect(
          (await banco.operacoes(sync.escopo))
              .where((op) => op['acao'] == 'recebimento'),
          isEmpty);
    });

    testWidgets(
        '${tipo.nome} percorre conferencia e pagamento offline pela interface',
        (tester) async {
      final id = (await tester.runAsync(() => abrir(tipo)))!;
      Modular.init(_ModuloRecebimentoOffline(api, usuario, sync.socket));
      addTearDown(Modular.destroy);
      tester.view.physicalSize = const Size(430, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: PaginaFinalizarContaAtendimento(
              idAtendimento: id,
              idComanda: tipo == TipoCardapio.comanda ? '5' : '0',
              idMesa: tipo == TipoCardapio.mesa ? '5' : '0',
              tipo: tipo,
              offline: true)));
      Future<void> estabilizar() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 15)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
      }

      await estabilizar();
      expect(find.text('Por produtos'), findsNothing);
      for (final chave in [
        'avancar_finalizacao_atendimento',
        'avancar_acrescimos_atendimento',
        'avancar_forma_pagamento_atendimento',
        'finalizar_pagamento_atendimento'
      ]) {
        await tester.tap(find.byKey(ValueKey(chave)));
        await estabilizar();
      }
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await estabilizar();
      expect(find.text('Conta finalizada'), findsOneWidget);
      expect(find.textContaining('sincronizado quando a conexão voltar'),
          findsOneWidget);
      final salvo =
          await tester.runAsync(() => recebimentos.detalhePendente(id));
      expect(salvo?.status, 'Finalizada');
      expect(salvo?.somaValorHistorico, '50.00');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    test(
        '${tipo.nome} finaliza sem confirmar abertura, preserva reinicio e envia abertura, itens, recebimento',
        () async {
      final id = await abrir(tipo);
      expect((await recebimentos.preparar(id, tipo.name)).valorTotal, '50.00');
      final pago = await pagar(id, tipo, valor: 60, troco: 10);
      expect(pago.sucesso, true);
      expect(pago.finalizou, true);
      await sync.enviarPendentes();
      expect(recibos, isEmpty);
      expect(
          (await ServicoCardapio(api, usuario).listarPorId(id, tipo, 'Não'))
              .status,
          'Finalizada');
      final alvo = sync.escopo;
      sync.dispose();
      await banco.db.close();
      banco = await BancoLocal.abrir(
          factory: databaseFactoryFfi, path: '${pasta.path}/dados.db');
      sync = Sincronizador(api, usuario, SocketOfflineTeste(), banco: banco);
      Sincronizador.instancia = sync;
      await sync.configurar();
      expect(sync.escopo, alvo);
      final locais = AtendimentosLocais(banco, alvo);
      expect((await locais.detalhe(id))['somaValorHistorico'], '50.00');
      final campo = tipo == TipoCardapio.mesa ? 'mesas' : 'comandas';
      final lista = await locais.projetarLista([
        {
          'titulo': 'Livres',
          campo: [
            {'id': '5', 'nome': '5', 'idComandaPedido': '0'}
          ]
        }
      ], tipo.name, '');
      expect(
          lista.expand((g) => g[campo] as List).single[
              tipo == TipoCardapio.mesa ? 'mesaOcupada' : 'comandaOcupada'],
          false);
      conectado = true;
      await banco.db.update('operacoes', {'proxima': 0});
      await sync.enviarPendentes();
      expect(enviados.map((e) => e['acao'] ?? 'recebimento'),
          ['abertura', 'produtos', 'recebimento']);
      expect(enviados.last['id'], '201');
      expect(enviados.last['recebimento_offline']['versao_atendimento'],
          'versao-201');
      expect(await banco.operacoes(alvo), isEmpty);
      expect(
          (await locais.projetarLista([
            {
              'titulo': 'Ocupadas',
              campo: [
                {'id': '5', 'nome': '5', 'idComandaPedido': '201'}
              ]
            }
          ], tipo.name, ''))
              .where((g) => g['titulo'] == 'Ocupadas')
              .single[campo],
          isEmpty);
    });
  }

  test('duas pessoas persistem duas parcelas e somente a ultima encerra',
      () async {
    final id = await abrir(TipoCardapio.comanda);
    await recebimentos.preparar(id, 'comanda');
    final primeira =
        await pagar(id, TipoCardapio.comanda, valor: 25, pessoas: 2);
    expect(primeira.finalizou, false);
    expect((await recebimentos.preparar(id, 'comanda')).somaValorHistorico,
        '25.00');
    final segunda =
        await pagar(id, TipoCardapio.comanda, valor: 25, pessoas: 2);
    expect(segunda.finalizou, true);
    await sync.enviarPendentes();
    conectado = true;
    await banco.db.update('operacoes', {'proxima': 0});
    await sync.enviarPendentes();
    final pagos =
        enviados.where((p) => p.containsKey('recebimento_offline')).toList();
    expect(pagos.map((p) => p['recebimento_offline']['pago_antes_centavos']),
        [0, 2500]);
    expect(recibos.values.last['somaValorHistorico'], '50.00');
  });

  test('configuracao da empresa 2 nao habilita recebimento em outra empresa',
      () async {
    final outraEmpresa = BancoLocal.escopo(sync.servidor, '3', '1');
    await banco.gravar('estado:$outraEmpresa',
        jsonEncode({'recebimento_atendimento_offline': 1, 'caixa_id': '7'}));
    await banco.guardarConsulta(
        outraEmpresa,
        CacheConsultas.chave(RequestOptions(
            path: 'cardapio/listar_por_id.php',
            queryParameters: {
              'id': '104',
              'codigoQrcode': 'null',
              'empresa': '3',
              'id_usuario': '1',
              'tipo': 'Comanda',
              'mostrar_itens': 'Sim',
            })),
        {
          'id': '104',
          'idComanda': '5',
          'status': 'Andamento',
          'versao_atendimento': 'versao-empresa-3',
          'produtos': [produto().toMap()],
          'valorTotal': '50.00',
        });
    await expectLater(
        RecebimentosAtendimento(banco, outraEmpresa).preparar('104', 'comanda'),
        throwsA(isA<StateError>().having((e) => e.message, 'mensagem',
            contains('configuração desta empresa'))));
  });

  test('resposta perdida reenvia o mesmo pagamento sem mudar os dados',
      () async {
    final id = await abrir(TipoCardapio.mesa);
    await recebimentos.preparar(id, 'mesa');
    await pagar(id, TipoCardapio.mesa);
    await sync.enviarPendentes();
    conectado = perderResposta = true;
    await banco.db.update('operacoes', {'proxima': 0});
    await sync.enviarPendentes();
    final primeira = enviados.last;
    final recibosAntes = recibos.length;
    await banco.db.update('operacoes', {'proxima': 0});
    await sync.enviarPendentes();
    expect(enviados.last, primeira);
    expect(recibos.length, recibosAntes);
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('conflito na abertura preserva pagamento e impede envio financeiro',
      () async {
    final id = await abrir(TipoCardapio.comanda);
    await recebimentos.preparar(id, 'comanda');
    await pagar(id, TipoCardapio.comanda);
    await sync.enviarPendentes();
    conectado = recusarAbertura = true;
    await banco.db.update('operacoes', {'proxima': 0});
    await sync.enviarPendentes();
    expect(enviados.every((e) => e['acao'] == 'abertura'), true);
    expect(
        (await banco.operacoes(sync.escopo))
            .where((o) => o['acao'] == 'recebimento')
            .single['estado'],
        'conflito');
  });

  test('conta remota salva usa saldo existente e recusa mudanca no servidor',
      () async {
    await banco.guardarConsulta(
        sync.escopo,
        CacheConsultas.chave(RequestOptions(
            path: 'cardapio/listar_por_id.php',
            queryParameters: {
              'id': '104',
              'codigoQrcode': 'null',
              'empresa': '2',
              'id_usuario': '1',
              'tipo': 'Comanda',
              'mostrar_itens': 'Sim'
            })),
        {
          'id': '104',
          'idComanda': '5',
          'status': 'Andamento',
          'versao_atendimento': 'versao-104',
          'produtos': [produto().toMap()],
          'somaValorHistorico': '20.00',
          'valorTotal': '50.00'
        });
    await recebimentos.preparar('104', 'comanda');
    expect(
        (await pagar('104', TipoCardapio.comanda, valor: 30)).finalizou, true);
    await sync.enviarPendentes();
    conectado = saldoMudou = true;
    await banco.db.update('operacoes', {'proxima': 0});
    await sync.enviarPendentes();
    expect((await banco.operacoes(sync.escopo)).single['estado'], 'conflito');
    expect(recibos, isEmpty);
  });
}
