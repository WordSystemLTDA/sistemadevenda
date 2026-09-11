import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/utils/finalizacao_com_preparo.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test(
      'finalizacao preserva snapshot e tenta apenas impressao apos gravar pedido',
      () async {
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
    await expectLater(executar(), throwsStateError);
    expect(limpezas, 0);
    expect(finalizacao.pedidoRegistrado, isTrue);
    carrinho.add(mensagem('nao-pertence-ao-pedido'));
    expect(await executar(), isTrue);
    expect(registros, 1);
    expect(envios, 2);
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
