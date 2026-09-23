import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/utils/finalizacao_com_preparo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Interface do plugin usada apenas para simular falhas reais de persistencia.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class ArmazenamentoFalhando extends InMemorySharedPreferencesStore {
  ArmazenamentoFalhando(this.lancarExcecao) : super.empty();
  final bool lancarExcecao;
  bool falhar = false;
  String? chaveFalha;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    if (falhar && (chaveFalha == null || key == chaveFalha)) {
      if (lancarExcecao) throw StateError('Disco indisponivel');
      return false;
    }
    return super.setValue(valueType, key, value);
  }
}

String mensagem(String id) => jsonEncode({
      'idRequisicao': id,
      'tipoImpressao': '1',
      'tipo': 'Comanda',
      'produtos': [
        {'nome': 'Pizza', 'quantidade': 1}
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('recupera antiga pausa por consultas mas conserva pausa do spooler',
      () async {
    SharedPreferences.setMockInitialValues({
      FilaImpressao.chave: jsonEncode([
        ImpressaoPendente(mensagem('consulta'),
                estado: EstadoImpressao.pausada,
                erro:
                    'Recuperação pausada. Confira a cozinha ou limpe a pendência.')
            .toMap(),
        ImpressaoPendente(mensagem('spooler'),
                estado: EstadoImpressao.pausada,
                erro: 'Impressora sem confirmacao')
            .toMap(),
      ])
    });
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.carregar();
    expect(fila.itens.first.estado, EstadoImpressao.semConfirmacao);
    expect(fila.itens.last.estado, EstadoImpressao.pausada);
  });

  for (final salvo in ['{incompleto', '{}', '[{}]']) {
    test('leitura invalida preserva comprovantes e impede sobrescrita: $salvo',
        () async {
      SharedPreferences.setMockInitialValues({FilaImpressao.chave: salvo});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await expectLater(fila.carregar(), throwsStateError);
      await expectLater(fila.registrar([mensagem('novo')]), throwsStateError);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(FilaImpressao.chave), salvo);
    });
  }

  for (final lancarExcecao in [false, true]) {
    test('falha ao persistir nao simula fila gravada (excecao: $lancarExcecao)',
        () async {
      final armazenamento = ArmazenamentoFalhando(lancarExcecao);
      SharedPreferencesStorePlatform.instance = armazenamento;
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      armazenamento.falhar = true;
      await expectLater(fila.registrar([mensagem('disco')]), throwsStateError);
      expect(fila.itens, isEmpty);
      armazenamento.falhar = false;
      await fila.registrar([mensagem('disco')]);
      armazenamento.falhar = true;
      await expectLater(fila.confirmar('disco'), throwsStateError);
      expect(fila.itens.single.id, 'disco');
      final restaurada = FilaImpressao();
      addTearDown(restaurada.dispose);
      await restaurada.carregar();
      expect(restaurada.itens.single.id, 'disco');
    });
  }

  test(
      'comprovante ja esta salvo durante registro do pedido e antes de limpar carrinho',
      () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    final finalizacao = FinalizacaoComPreparo();
    var limpou = false;
    await finalizacao.executar(
      prepararImpressao: () => [mensagem('protegida')],
      salvarImpressaoAntesDoPedido: (mensagens) =>
          fila.registrar(mensagens, estado: EstadoImpressao.aguardandoPedido),
      cancelarImpressaoPreparada: fila.cancelarPreparacao,
      registrarPedido: () async {
        final restaurada = FilaImpressao();
        addTearDown(restaurada.dispose);
        await restaurada.carregar();
        expect(restaurada.itens.single.id, 'protegida');
        expect(
            restaurada.itens.single.estado, EstadoImpressao.aguardandoPedido);
        return true;
      },
      enviarImpressao: (mensagens) => fila.registrar(mensagens),
      limparCarrinho: () async {
        expect(fila.itens.single.estado, EstadoImpressao.aguardandoEnvio);
        limpou = true;
      },
    );
    expect(limpou, isTrue);
  });

  test('falha ao salvar impressao libera registro do pedido e avisa usuario',
      () async {
    final finalizacao = FinalizacaoComPreparo();
    var avisos = 0;
    var limpezas = 0;
    expect(
        await finalizacao.executar(
          prepararImpressao: () => [mensagem('nao-salva')],
          salvarImpressaoAntesDoPedido: (_) async =>
              throw StateError('Disco cheio'),
          registrarPedido: () async => true,
          enviarImpressao: (_) async => throw StateError('Disco cheio'),
          limparCarrinho: () async {
            limpezas++;
          },
          aoFalharImpressao: (_) => avisos++,
        ),
        isTrue);
    expect(avisos, 2);
    expect(limpezas, 1);
    expect(finalizacao.erroImpressao, isA<StateError>());
  });

  test(
      'API sem resposta conserva comprovante bloqueado; pedido recusado cancela preparacao',
      () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    Future<bool> executar(bool timeout) => FinalizacaoComPreparo().executar(
          prepararImpressao: () => [mensagem('api')],
          salvarImpressaoAntesDoPedido: (mensagens) => fila.registrar(mensagens,
              estado: EstadoImpressao.aguardandoPedido),
          cancelarImpressaoPreparada: fila.cancelarPreparacao,
          registrarPedido: () async {
            if (timeout) throw StateError('API sem resposta');
            return false;
          },
          enviarImpressao: (_) async => fail('Nao deve imprimir'),
          limparCarrinho: () async => fail('Nao deve limpar'),
        );
    await expectLater(executar(true), throwsStateError);
    expect(fila.itens.single.estado, EstadoImpressao.aguardandoPedido);
    expect(await fila.iniciarEnvio('api'), isFalse);
    expect(await executar(false), isFalse);
    expect(fila.itens, isEmpty);
  });

  test('grava destinos simultaneos sem perder mensagens ou ACKs', () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await Future.wait(
        List.generate(30, (i) => fila.registrar([mensagem('$i')])));
    expect(fila.itens, hasLength(30));
    await Future.wait([
      fila.registrar([mensagem('nova')]),
      fila.confirmar('0'),
      fila.confirmar('1'),
    ]);
    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(restaurada.itens, hasLength(29));
    expect(restaurada.itens.map((e) => e.id), contains('nova'));
    expect(restaurada.itens.map((e) => e.id), isNot(contains('0')));
  });

  test('nao expira nem descarta impressao por limite de fila', () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila
        .registrar(List.generate(205, (i) => mensagem('1000000000000_$i')));
    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(restaurada.itens, hasLength(205));
  });

  test('envio sem ACK exige conferencia mesmo depois de reiniciar', () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('pizza'), mensagem('bebida')]);
    expect(await fila.iniciarEnvio('pizza'), isTrue);
    expect(await fila.iniciarEnvio('pizza'), isFalse);
    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(await restaurada.iniciarEnvio('pizza'), isFalse);
    expect(await restaurada.iniciarEnvio('bebida'), isTrue);
    await restaurada.registrarErro('pizza', 'Impressora indisponivel');
    expect(restaurada.itens.first.erro, 'Impressora indisponivel');
    expect(await restaurada.iniciarEnvio('pizza'), isFalse);
    await restaurada.autorizarReenvio('pizza');
    expect(await restaurada.iniciarEnvio('pizza'), isTrue);
    await restaurada.confirmar('pizza');
    expect(restaurada.itens.map((e) => e.id), ['bebida']);
  });

  test('reenvio manual move a pendencia para o servidor atual', () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('trocar-manualmente')],
        servidor: 'cozinha-antiga:9980');
    await fila.iniciarEnvio('trocar-manualmente', agora: DateTime(2026));

    await fila.autorizarReenvio('trocar-manualmente',
        manual: true, servidor: 'cozinha-nova:9981');

    final item = fila.itens.single;
    expect(item.id, 'trocar-manualmente');
    expect(item.servidor, 'cozinha-nova:9981');
    expect(item.estado, EstadoImpressao.aguardandoEnvio);
    expect(item.tentativas, 0);
    expect(item.ultimaTentativa, isNull);
    expect(item.dados['retomadaImpressao'], isNotNull);
  });

  test('troca servidor apenas para impressoes que nunca foram enviadas',
      () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([
      mensagem('nao-enviada'),
      mensagem('sem-confirmacao'),
      mensagem('falha-no-socket'),
      jsonEncode({
        ...jsonDecode(mensagem('outra-empresa')),
        'idEmpresa': '31',
      }),
    ], servidor: 'cozinha-antiga:9980');
    await fila.iniciarEnvio('sem-confirmacao');
    await fila.iniciarEnvio('falha-no-socket');
    await fila.registrarErro('falha-no-socket',
        'Conexao interrompida. Aguardando recuperacao automatica.');

    final transferidas = await fila
        .transferirNaoEnviadasParaServidor('cozinha-nova:9980', empresa: '32');

    expect(transferidas, {'nao-enviada', 'falha-no-socket'});
    expect(fila.itens.firstWhere((item) => item.id == 'nao-enviada').servidor,
        'cozinha-nova:9980');
    expect(
        fila.itens.firstWhere((item) => item.id == 'sem-confirmacao').servidor,
        'cozinha-antiga:9980');
    final recuperada =
        fila.itens.firstWhere((item) => item.id == 'falha-no-socket');
    expect(recuperada.servidor, 'cozinha-nova:9980');
    expect(recuperada.estado, EstadoImpressao.aguardandoEnvio);
    expect(recuperada.tentativas, 0);
    expect(fila.itens.firstWhere((item) => item.id == 'outra-empresa').servidor,
        'cozinha-antiga:9980');
  });

  test('migra fila antiga sem reenviar pedidos de resultado desconhecido',
      () async {
    SharedPreferences.setMockInitialValues({
      FilaImpressao.chaveLegada: [mensagem('antiga'), '{"tipo":"Mesa"}'],
    });
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.carregar();
    expect(fila.itens.single.estado, EstadoImpressao.semConfirmacao);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(FilaImpressao.chaveLegada), ['{"tipo":"Mesa"}']);
  });

  test('confirma apenas a requisicao correta e nao ressuscita ACK atrasado',
      () async {
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('pizza'), mensagem('bebida')]);
    await fila.iniciarEnvio('pizza');
    await fila.confirmar('pizza');
    await fila.registrarErro('pizza', 'Erro atrasado');
    await fila.confirmar('desconhecida');
    expect(fila.itens.map((e) => e.id), ['bebida']);
  });

  test('reinicio nao registra novamente impressao com ACK ja salvo', () async {
    final fila = FilaImpressao();
    await fila.registrar([mensagem('confirmada')]);
    await fila.iniciarEnvio('confirmada');
    await fila.confirmar('confirmada');
    fila.dispose();

    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.registrar([mensagem('confirmada'), mensagem('nova')]);
    expect(restaurada.itens.map((item) => item.id), ['nova']);
  });

  test('ACK duravel impede repeticao se falhar a remocao da fila', () async {
    final armazenamento = ArmazenamentoFalhando(false);
    SharedPreferencesStorePlatform.instance = armazenamento;
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('confirmada')]);
    await fila.iniciarEnvio('confirmada');
    armazenamento
      ..chaveFalha = 'flutter.${FilaImpressao.chave}'
      ..falhar = true;
    await expectLater(fila.confirmar('confirmada'), throwsStateError);
    armazenamento.falhar = false;

    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(restaurada.itens, isEmpty);
    await restaurada.registrar([mensagem('confirmada')]);
    expect(restaurada.itens, isEmpty);
  });

  test('migracao legada nao recupera impressao finalizada anteriormente',
      () async {
    SharedPreferences.setMockInitialValues({
      FilaImpressao.chaveConfirmadas: ['confirmada'],
      FilaImpressao.chaveLegada: [mensagem('confirmada'), mensagem('pendente')],
    });
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.carregar();
    expect(fila.itens.map((item) => item.id), ['pendente']);
    expect(fila.itens.single.estado, EstadoImpressao.semConfirmacao);
  });

  test('falha de impressao nao prende finalizacao nem repete pedido', () async {
    final finalizacao = FinalizacaoComPreparo();
    final carrinho = [mensagem('pizza'), mensagem('bebida')];
    var registros = 0;
    var envios = 0;
    var limpezas = 0;
    Future<bool> executar() => finalizacao.executar(
          prepararImpressao: () => carrinho,
          registrarPedido: () async {
            registros++;
            return true;
          },
          enviarImpressao: (mensagens) async {
            envios++;
            expect(mensagens, hasLength(2));
            if (envios == 1) throw StateError('Disco cheio');
          },
          limparCarrinho: () async {
            limpezas++;
            carrinho.clear();
          },
        );
    expect(await executar(), isTrue);
    expect(limpezas, 1);
    expect(finalizacao.pedidoRegistrado, isTrue);
    carrinho.add(mensagem('nao-pertence-ao-pedido'));
    expect(await executar(), isTrue);
    expect(registros, 1);
    expect(envios, 1);
    expect(limpezas, 1);
  });

  test('falha ao limpar nao repete impressao nem grava outro pedido', () async {
    final finalizacao = FinalizacaoComPreparo();
    var registros = 0;
    var envios = 0;
    var limpezas = 0;
    Future<bool> executar() => finalizacao.executar(
          prepararImpressao: () => [mensagem('pizza')],
          registrarPedido: () async {
            registros++;
            return true;
          },
          enviarImpressao: (_) async {
            envios++;
          },
          limparCarrinho: () async {
            if (++limpezas == 1) throw StateError('Falha');
          },
        );
    await expectLater(executar(), throwsStateError);
    expect(await executar(), isTrue);
    expect(registros, 1);
    expect(envios, 1);
    expect(limpezas, 2);
  });

  test('pedido recusado nao imprime nem limpa o carrinho', () async {
    final finalizacao = FinalizacaoComPreparo();
    expect(
        await finalizacao.executar(
          prepararImpressao: () => [mensagem('pizza')],
          registrarPedido: () async => false,
          enviarImpressao: (_) async => fail('Nao deve imprimir'),
          limparCarrinho: () async => fail('Nao deve limpar'),
        ),
        isFalse);
  });
}
