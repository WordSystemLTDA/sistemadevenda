import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _CatalogoAdapter implements HttpClientAdapter {
  dynamic resposta;
  bool offline = false;
  int consultas = 0;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    consultas++;
    if (offline) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(resposta), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const servidor = 'http://cozinha/api1/';
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late ServicoProduto produtos;
  late _CatalogoAdapter adapter;
  late Map<String, dynamic> almoco;

  setUp(() async {
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    BancoLocal.instancia = banco;
    api = DioCliente(servidor: servidor);
    api.cache!
      ..servidor = servidor
      ..empresa = '32'
      ..escopo = 'teste-cardapio';
    adapter = _CatalogoAdapter();
    api.cliente.httpClientAdapter = adapter;
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    produtos = ServicoProduto(api, usuario);
    almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  tearDown(() async {
    api.cliente.close(force: true);
    usuario.dispose();
    BancoLocal.instancia = null;
    await banco.db.close();
  });

  Future<void> guardar(
          String rota, Map<String, dynamic> parametros, dynamic valor) =>
      banco.guardarConsulta(
          'teste-cardapio',
          CacheConsultas.chave(RequestOptions(
            path: rota,
            baseUrl: servidor,
            queryParameters: parametros,
          )),
          valor);

  Map<String, dynamic> getDetalhe() => {
        'id': '436',
        'empresa': '32',
        'id_usuario': '1',
        'id_tamanhos_pizza': '0',
      };

  test(
      'primeiro acesso substitui catalogo antigo sem vinculo por resposta nova',
      () async {
    final antigo = Map<String, dynamic>.from(almoco)
      ..remove('idCategoriaCardapio')
      ..remove('id_categoria_cardapio')
      ..['opcoesPacotes'] = [];
    await guardar('produtos/listar_por_categoria.php', {
      'categoria': '62',
      'empresa': '32',
      'id_usuario': '1',
      'pagina': '1',
    }, [
      antigo
    ]);
    adapter.resposta = [almoco];
    final lista = await produtos.listarPorCategoria('62', 1);
    expect(adapter.consultas, 1);
    expect(lista.single.idCategoriaCardapio, '3');
    expect(lista.single.opcoesPacotes!.first.dados, hasLength(3));
    await produtos.listarPorCategoria('62', 1);
    expect(adapter.consultas, 2);
  });

  test(
      'detalhe atualiza ingredientes mesmo com cache recente e preserva offline',
      () async {
    final antigo = Map<String, dynamic>.from(almoco)..['opcoesPacotes'] = [];
    await guardar('produtos/listar_por_id.php', getDetalhe(), antigo);
    adapter.resposta = almoco;
    final online = await produtos.listarPorId('436', '0');
    expect(adapter.consultas, 1);
    expect(online!.opcoesPacotes!.first.dados, hasLength(3));
    adapter.offline = true;
    final offline = await produtos.listarPorId('436', '0');
    expect(offline!.idCategoriaCardapio, '3');
    expect(offline.opcoesPacotes!.first.dados!.map((i) => i.nome),
        ['Arroz', 'Carne de Panela', 'Feijão']);
    await produtos.listarPorId('436', '0');
    expect(adapter.consultas, 2);
  });

  test('produto comum tambem consulta o preco atual com cache recente',
      () async {
    final comum = Map<String, dynamic>.from(almoco)
      ..['idCategoriaCardapio'] = '0'
      ..['id_categoria_cardapio'] = '0'
      ..['opcoesPacotes'] = [];
    await guardar('produtos/listar_por_id.php', getDetalhe(), comum);
    adapter.resposta = {...comum, 'valorVenda': '23.00'};
    final produto = await produtos.listarPorId('436', '0');
    expect(produto!.opcoesPacotes, isEmpty);
    expect(produto.valorVenda, '23.00');
    expect(adapter.consultas, 1);
  });

  test('produto novo aparece na proxima leitura sem esperar expirar cache',
      () async {
    adapter.resposta = [almoco];
    expect(await produtos.listarPorCategoria('62', 1), hasLength(1));
    adapter.resposta = [
      almoco,
      {...almoco, 'id': '999', 'nome': 'Produto novo'}
    ];
    expect(await produtos.listarPorCategoria('62', 1), hasLength(2));
    expect(adapter.consultas, 2);
  });

  for (final rota in [
    'categorias/listar.php',
    'tela_nfe_saida/listar_bancos.php',
    'mesas/listar.php',
    'comandas/listar.php',
    'balcao/listar.php',
  ]) {
    test('$rota consulta inclusoes mesmo com retrato recente', () async {
      final parametros = rota.startsWith('tela_nfe_saida')
          ? {'id_empresa': '32'}
          : {'empresa': '32'};
      await guardar(rota, parametros, {'nome': 'Antigo'});
      adapter.resposta = {'nome': 'Novo'};
      final resposta = await api.cliente.get(rota, queryParameters: parametros);
      expect(resposta.data['nome'], 'Novo');
      expect(resposta.extra['cacheLocal'], isNot(true));
    });
  }

  test('parametro anticache nao multiplica as chaves offline', () {
    RequestOptions consulta(String token) => RequestOptions(
          path: 'produtos/listar.php',
          queryParameters: {'empresa': '32', '_consulta_atual': token},
        );
    expect(CacheConsultas.chave(consulta('1')),
        CacheConsultas.chave(consulta('2')));
  });
}
