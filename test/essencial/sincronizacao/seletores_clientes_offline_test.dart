import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/clientes/servicos/servico_clientes.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
          RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async =>
      throw DioException(
          requestOptions: o, type: DioExceptionType.connectionError);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late Server server;
  late Sincronizador sync;
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    BancoLocal.instancia = banco;
    api = DioCliente()..cliente.httpClientAdapter = _Offline();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    server = Server();
    sync = Sincronizador(api, usuario, server, banco: banco);
    await sync.configurar();
    await banco.gravar(
        'clientes-completos:${sync.escopo}',
        jsonEncode(List.generate(
            40,
            (i) => {
                  'id': '${i + 1}',
                  'nome': 'Cliente ${i + 1}',
                  'nome_puro': 'Cliente ${i + 1}',
                  'razao_social': i == 39 ? 'Açaí São João' : '',
                  'celular': i == 39 ? '(44) 99921-3336' : '',
                })));
  });
  tearDown(() async {
    sync.dispose();
    server.dispose();
    usuario.dispose();
    api.cliente.close(force: true);
    BancoLocal.instancia = null;
    await banco.db.close();
  });
  void restaurarEscopo() {
    Sincronizador.instancia = sync;
    sync.escopo = '';
    api.cache!.escopo = '';
  }

  for (final modulo in ['Delivery', 'Mesa', 'Comanda', 'Balcao']) {
    test('$modulo restaura escopo e busca cliente offline por razao e celular',
        () async {
      final Future<List<dynamic>> Function(String) buscar = switch (modulo) {
        'Mesa' => ServicoMesas(api, usuario).listarClientes,
        'Comanda' => ServicoComandas(api, usuario).listarClientes,
        _ => ServicoBalcao(api, usuario).listarClientes,
      };
      restaurarEscopo();
      for (final termo in [
        'acai sao joao',
        '3336',
        '44999213336',
        '(44) 99921-3336'
      ]) {
        expect((await buscar(termo)).single['id'], '40');
      }
      expect(await buscar('inexistente'), isEmpty);
      expect(await buscar(''), hasLength(40));
    });
  }
  test(
      'cadastro de clientes usa paginacao completa offline pelo servico Delivery',
      () async {
    restaurarEscopo();
    final servico = ServicoClientes(ServicoDelivery(api, usuario));
    final primeira = await servico.listarClientes('');
    expect(primeira.clientes, hasLength(15));
    expect(primeira.clientes.first.id, '40');
    expect(primeira.temMais, isTrue);
    final segunda =
        await servico.listarClientes('', antesId: primeira.proximoId);
    expect(segunda.clientes.first.id, '25');
    expect((await servico.listarClientes('3336')).clientes.single.id, '40');
  });
  test('balcao e delivery consultam o mesmo endereco padrao salvo offline',
      () async {
    final endereco = {
      'id': '7',
      'endereco': 'Rua Teste',
      'cep': '86790000',
      'numero': '169',
      'complemento': '',
      'padrao': 'Sim',
      'bairro': 'Centro',
      'cidade': 'Lobato',
      'tamanhoLista': 1
    };
    await banco.guardarConsulta(
        sync.escopo,
        CacheConsultas.chave(RequestOptions(
            path: 'enderecos_clientes/listar_por_cliente.php',
            queryParameters: {
              'empresa': '32',
              'id_usuario': '1',
              'cliente': '40',
              'pesquisa': '',
            })),
        [endereco]);
    restaurarEscopo();
    expect(
        (await ServicoBalcao(api, usuario).listarEnderecosClientes('', '40'))
            .single
            .id,
        '7');
    final salvos = await ServicoDelivery(api, usuario).consultar(
        'enderecos_clientes/listar_por_cliente.php',
        {'cliente': '40', 'pesquisa': ''});
    expect(salvos.single['padrao'], 'Sim');
  });
  test(
      'queda no meio da preparacao aproveita paginas ja baixadas sem usar outra empresa',
      () async {
    await banco.db.delete('documentos',
        where: 'chave = ?', whereArgs: ['clientes-completos:${sync.escopo}']);
    await banco.guardarConsulta(
        sync.escopo,
        CacheConsultas.chave(RequestOptions(
            path: 'comandas/listar_clientes.php',
            queryParameters: {
              'empresa': '32',
              'id_usuario': '1',
              'pesquisa': '',
              'paginado': '1',
            })),
        {
          'dados': [
            {'id': '40', 'nome': 'Bruno', 'celular': '(44) 99921-3336'}
          ],
          'tem_mais': true,
          'proximo_id': '40'
        });
    final clientes = await ServicoBalcao(api, usuario).listarClientes('3336');
    expect(clientes.single['id'], '40');
    api.cache!
      ..escopo = 'outra-empresa'
      ..empresa = '33';
    usuario.setUsuario(UsuarioModelo(id: '1', empresa: '33'));
    await expectLater(ServicoBalcao(api, usuario).listarClientes('3336'),
        throwsA(isA<DioException>()));
  });
}
