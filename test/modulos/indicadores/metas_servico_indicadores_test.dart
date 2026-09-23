import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:app/src/modulos/indicadores/servico_indicadores.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'indicadores_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late DioCliente api;
  late BancoLocal banco;
  late UsuarioProvedor usuarios;
  late ServicoIndicadores servico;
  late List<RequestOptions> requisicoes;
  String servidor = 'http://servidor/';
  Object? falha;
  Object? respostaSalvar;
  bool apiAntiga = false;
  Completer<void>? espera;
  Completer<void>? requisicaoRecebida;
  final data = DateTime(2026, 9, 12);
  const metas = MetasIndicadores(
    consumoDiarioCentavos: 125000,
    atendimentosDiarios: 25,
    ticketMedioCentavos: 5000,
  );
  String chave(String escopo) =>
      'indicadores:${BancoLocal.escopo(servidor, usuarios.usuario!.empresa!, usuarios.usuario!.id!)}${escopo == 'pessoal' ? ':pessoal' : ''}';
  Matcher falhaCom(String mensagem) => throwsA(isA<FalhaIndicadores>()
      .having((erro) => erro.mensagem, 'mensagem', contains(mensagem)));

  setUp(() async {
    falha = null;
    respostaSalvar = {'sucesso': true};
    apiAntiga = false;
    espera = null;
    requisicaoRecebida = null;
    requisicoes = [];
    servidor = 'http://servidor/';
    SharedPreferences.setMockInitialValues({});
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    usuarios = fixture.administrador();
    api = DioCliente();
    api.cliente.interceptors.clear();
    api.cliente.interceptors
        .add(InterceptorsWrapper(onRequest: (op, handler) async {
      requisicoes.add(op);
      if (requisicaoRecebida?.isCompleted == false) {
        requisicaoRecebida!.complete();
      }
      await espera?.future;
      if (falha is int) {
        handler.reject(DioException(
            requestOptions: op,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: op, statusCode: falha as int)));
        return;
      }
      if (falha == 'offline') {
        handler.reject(DioException(
            requestOptions: op, type: DioExceptionType.connectionError));
        return;
      }
      final dados = op.data as Map;
      final escopo = dados['escopo'] as String;
      handler.resolve(Response(
        requestOptions: op,
        statusCode: 200,
        data: op.path.endsWith('salvar_metas.php')
            ? respostaSalvar
            : {
                'sucesso': true,
                'resultado': {
                  ...fixture.relatorio(grupos: [
                    fixture.grupo(
                      quantidade: escopo == 'pessoal' ? 2 : 8,
                      centavos: escopo == 'pessoal' ? 8500 : 32000,
                    ),
                  ]),
                  if (!apiAntiga) 'escopo': escopo,
                  if (!apiAntiga) 'suporte_metas': true,
                  if (!apiAntiga) 'metas': metas.toMap(),
                },
              },
      ));
    }));
    servico = ServicoIndicadores(api, usuarios,
        banco: banco, servidor: () async => servidor);
  });

  tearDown(() async {
    api.cliente.close(force: true);
    await banco.db.close();
    usuarios.dispose();
  });

  test('consulta pessoal autentica POST e transmite escopo e período',
      () async {
    final modelo = await servico.consultar(data, data, escopo: 'pessoal');
    final pedido = requisicoes.single;

    expect(pedido.method, 'POST');
    expect(pedido.path, 'indicadores/listar.php');
    expect(pedido.queryParameters, isEmpty);
    expect(pedido.data, {
      'id_usuario': '1',
      'empresa': '32',
      'usuario': 'gestor',
      'senha': 'teste',
      'escopo': 'pessoal',
      'inicio': '2026-09-12',
      'fim': '2026-09-12',
    });
    expect(pedido.extra['semCache'], isTrue);
    expect(pedido.extra['servidorFixo'], servidor);
    expect(modelo.pessoal, isTrue);
    expect(modelo.suporteMetas, isTrue);
    expect(modelo.metas!.toMap(), metas.toMap());
    expect(await banco.ler(chave('pessoal')), isNot(contains('senha')));
  });

  test('API antiga atende empresa mas não apresenta totais como pessoais',
      () async {
    apiAntiga = true;
    final empresa = await servico.consultar(data, data);
    expect(empresa.pessoal, isFalse);
    expect(empresa.suporteMetas, isFalse);
    await expectLater(servico.consultar(data, data, escopo: 'pessoal'),
        falhaCom('Atualize a API'));
    expect(await banco.ler(chave('pessoal')), isNull);
  });

  test('empresa e pessoal têm caches independentes para o mesmo usuário',
      () async {
    await servico.consultar(data, data);
    await servico.consultar(data, data, escopo: 'pessoal');
    falha = 'offline';

    final empresa = await servico.consultar(data, data);
    final pessoal = await servico.consultar(data, data, escopo: 'pessoal');
    expect(empresa.offline, isTrue);
    expect(pessoal.offline, isTrue);
    expect(empresa.resumir(CanalIndicadores.todos).consumoCentavos, 32000);
    expect(pessoal.resumir(CanalIndicadores.todos).consumoCentavos, 8500);
    expect(empresa.resumir(CanalIndicadores.todos).quantidade, 8);
    expect(pessoal.resumir(CanalIndicadores.todos).quantidade, 2);
  });

  test('permissão revogada invalida as duas visões antes de ficar offline',
      () async {
    await servico.consultar(data, data);
    await servico.consultar(data, data, escopo: 'pessoal');
    falha = 403;
    await expectLater(servico.consultar(data, data, escopo: 'pessoal'),
        throwsA(isA<FalhaIndicadores>()));
    expect(await banco.ler(chave('empresa')), '');
    expect(await banco.ler(chave('pessoal')), '');
    falha = 'offline';
    await expectLater(
        servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
  });

  test('sem cache pessoal não reutiliza consulta da empresa nem cache inválido',
      () async {
    await servico.consultar(data, data);
    falha = 'offline';
    await expectLater(servico.consultar(data, data, escopo: 'pessoal'),
        falhaCom('Não há consulta recente'));

    // Um payload antigo ou gravado no escopo errado também não é mostrado.
    await banco.gravar(chave('pessoal'), jsonEncode(fixture.relatorio()));
    await expectLater(servico.consultar(data, data, escopo: 'pessoal'),
        falhaCom('Não há consulta recente'));
  });

  test(
      'salvar envia contrato de metas em centavos e mantém credenciais no POST',
      () async {
    await servico.salvarMetas(metas, escopo: 'pessoal');
    final pedido = requisicoes.single;
    expect(pedido.method, 'POST');
    expect(pedido.path, 'indicadores/salvar_metas.php');
    expect(pedido.data, {
      'id_usuario': '1',
      'empresa': '32',
      'usuario': 'gestor',
      'senha': 'teste',
      'escopo': 'pessoal',
      'consumo_diario_centavos': 125000,
      'atendimentos_diarios': 25,
      'ticket_medio_centavos': 5000,
    });
    expect(pedido.extra['semCache'], isTrue);
    expect(pedido.extra['servidorFixo'], servidor);
    expect(pedido.queryParameters, isEmpty);
  });

  test('salvar com sucesso invalida somente cache do escopo alterado',
      () async {
    await servico.consultar(data, data);
    await servico.consultar(data, data, escopo: 'pessoal');
    final empresaAntes = await banco.ler(chave('empresa'));
    respostaSalvar = jsonEncode({'sucesso': true});

    await servico.salvarMetas(metas, escopo: 'pessoal');
    expect(await banco.ler(chave('pessoal')), '');
    expect(await banco.ler(chave('empresa')), empresaAntes);
    falha = 'offline';
    await expectLater(servico.consultar(data, data, escopo: 'pessoal'),
        falhaCom('Não há consulta recente'));
    expect((await servico.consultar(data, data)).offline, isTrue);
  });

  test('HTTP 200 com sucesso falso não salva nem limpa resultado anterior',
      () async {
    await servico.consultar(data, data, escopo: 'pessoal');
    final antes = await banco.ler(chave('pessoal'));
    respostaSalvar = {'sucesso': false, 'mensagem': 'Falha no banco'};

    await expectLater(servico.salvarMetas(metas, escopo: 'pessoal'),
        falhaCom('Não foi possível salvar'));
    expect(await banco.ler(chave('pessoal')), antes);
  });

  for (final status in [404, 503]) {
    test('HTTP $status ao salvar informa indisponibilidade de metas', () async {
      falha = status;
      await expectLater(servico.salvarMetas(metas, escopo: 'empresa'),
          falhaCom('metas ainda não estão disponíveis'));
    });
  }

  for (final erro in ['offline', 500]) {
    test('falha $erro ao salvar informa erro e não finge sucesso', () async {
      falha = erro;
      await expectLater(servico.salvarMetas(metas, escopo: 'pessoal'),
          falhaCom('Não foi possível salvar'));
    });
  }

  test('retorno inválido HTTP 200 ao salvar oferece erro compreensível',
      () async {
    respostaSalvar = '<html>Servidor em manutenção</html>';
    await expectLater(servico.salvarMetas(metas, escopo: 'pessoal'),
        throwsA(isA<FalhaIndicadores>()));
  });

  for (final troca in ['usuario', 'servidor']) {
    test('resposta de salvar após trocar $troca não confirma a sessão antiga',
        () async {
      await servico.consultar(data, data, escopo: 'pessoal');
      final chaveAntiga = chave('pessoal');
      final antes = await banco.ler(chaveAntiga);
      espera = Completer<void>();
      requisicaoRecebida = Completer<void>();
      final salvamento = servico.salvarMetas(metas, escopo: 'pessoal');
      final verificacao = expectLater(salvamento, falhaCom('sessão mudou'));
      await requisicaoRecebida!.future;
      if (troca == 'usuario') {
        usuarios.setUsuario(UsuarioModelo(id: '2', empresa: '32', nivel: '1'));
      } else {
        servidor = 'http://outro-servidor/';
      }
      espera!.complete();
      await verificacao;
      expect(await banco.ler(chaveAntiga), antes);
    });
  }

  test('escopo inválido ou usuário sem acesso não consulta nem salva metas',
      () async {
    await expectLater(servico.consultar(data, data, escopo: 'outro'),
        throwsA(isA<FalhaIndicadores>()));
    await expectLater(servico.salvarMetas(metas, escopo: 'outro'),
        throwsA(isA<FalhaIndicadores>()));
    usuarios.setUsuario(UsuarioModelo(id: '5', empresa: '32', nivel: '5'));
    await expectLater(servico.salvarMetas(metas, escopo: 'pessoal'),
        throwsA(isA<FalhaIndicadores>()));
    expect(requisicoes, isEmpty);
  });
}
