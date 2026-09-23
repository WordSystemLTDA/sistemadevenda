import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _AdapterCardapioFallback implements HttpClientAdapter {
  _AdapterCardapioFallback(this.almoco);

  final Map<String, dynamic> almoco;
  final chamadas = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    final caminho = options.uri.path;
    final desktopAntigo =
        jsonDecode(jsonEncode(almoco)) as Map<String, dynamic>;
    for (final dado in desktopAntigo['opcoesPacotes'][0]['dados'] as List) {
      (dado as Map).remove('permissoesMontagemCardapio');
    }
    final quebrado = Map<String, dynamic>.from(desktopAntigo)
      ..['idCategoriaCardapio'] = null
      ..['id_categoria_cardapio'] = null
      ..['opcoesPacotes'] = [desktopAntigo['opcoesPacotes'][1]];

    if (RegExp(
            r'/api_restaurantes_venda/api(?:1|37)/produtos/listar_por_id\.php$')
        .hasMatch(caminho)) {
      return _json(quebrado);
    }
    if (RegExp(
            r'/api_restaurantes_venda/api(?:1|37)/produtos/listar_por_categoria\.php$')
        .hasMatch(caminho)) {
      return _json([quebrado]);
    }
    if (caminho
        .endsWith('/api_desktop/1.0.01/produtos/listar_por_categoria.php')) {
      return _json([desktopAntigo]);
    }
    if (caminho.endsWith(
        '/api_desktop/1.0.01/cardapio/vincular_cardapio/listar_ingredientes_dia.php')) {
      return _json({
        'ingredientes': [
          {
            'idIngredienteCardapio': '6',
            'permitirSem': 'Não',
            'permitirPouco': 'Sim',
            'permitirNormal': 'Sim',
            'permitirMais': 'Sim',
            'permitirTrocar': 'Sim',
          },
          {
            'idIngredienteCardapio': '10',
            'permitirSem': 'Sim',
            'permitirPouco': 'Sim',
            'permitirNormal': 'Sim',
            'permitirMais': 'Sim',
            'permitirTrocar': 'Sim',
          },
          {
            'idIngredienteCardapio': '7',
            'permitirSem': 'Sim',
            'permitirPouco': 'Sim',
            'permitirNormal': 'Sim',
            'permitirMais': 'Sim',
            'permitirTrocar': 'Sim',
          },
        ],
      });
    }
    return _json([]);
  }

  ResponseBody _json(Object dados) => ResponseBody.fromString(
        jsonEncode(dados),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('consulta comum nao solicita ingredientes de outros dias', () async {
    final almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
    final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api1/');
    addTearDown(() => api.cliente.close(force: true));
    final adapter = _AdapterCardapioFallback(almoco);
    api.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    addTearDown(usuario.dispose);

    await ServicoProduto(api, usuario).listarPorId('436', '0');

    expect(
        adapter.chamadas[0].uri.queryParameters['modelo_recorrente'], isNull);
    expect(
        adapter.chamadas[1].uri.queryParameters['modelo_recorrente'], isNull);
  });

  test(
      'completa montagem pelo endpoint desktop quando API do garcom vem antiga',
      () async {
    final almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
    final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api1/');
    addTearDown(() => api.cliente.close(force: true));
    final adapter = _AdapterCardapioFallback(almoco);
    api.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    addTearDown(usuario.dispose);

    final produto = await ServicoProduto(api, usuario)
        .listarPorId('436', '0', modeloRecorrente: true);

    expect(produto!.idCategoriaCardapio, '3');
    expect(produto.opcoesPacotes!.map((e) => e.tipo), [8, 3]);
    expect(produto.opcoesPacotes!.first.dados!.map((e) => e.nome),
        ['Arroz', 'Carne de Panela', 'Feijão']);
    expect(
      produto.opcoesPacotes!.first.dados!.first
          .permiteMontagemCardapio(AcaoIngredienteCardapio.sem),
      isFalse,
    );
    expect(adapter.chamadas.map((e) => e.uri.path), [
      '/sistema/apis_restaurantes/api_restaurantes_venda/api1/produtos/listar_por_id.php',
      '/sistema/apis_restaurantes/api_desktop/1.0.01/produtos/listar_por_categoria.php',
      '/sistema/apis_restaurantes/api_desktop/1.0.01/cardapio/vincular_cardapio/listar_ingredientes_dia.php',
    ]);
    expect(adapter.chamadas[0].uri.queryParameters['modelo_recorrente'], 'Sim');
    expect(adapter.chamadas[1].uri.queryParameters['modelo_recorrente'], 'Sim');
  });

  test('api37 local tambem recupera a montagem pelo endpoint desktop',
      () async {
    final almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
    almoco['id'] = '151';
    almoco['codigo'] = '151';
    final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api37/');
    addTearDown(() => api.cliente.close(force: true));
    final adapter = _AdapterCardapioFallback(almoco);
    api.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
    addTearDown(usuario.dispose);

    final produto = await ServicoProduto(api, usuario).listarPorId('151', '0');

    expect(produto!.idCategoriaCardapio, '3');
    expect(produto.opcoesPacotes!.first.tipo, 8);
    expect(produto.opcoesPacotes!.first.dados!.map((item) => item.nome),
        ['Arroz', 'Carne de Panela', 'Feijão']);
    expect(adapter.chamadas.map((e) => e.uri.path).take(2), [
      '/sistema/apis_restaurantes/api_restaurantes_venda/api37/produtos/listar_por_id.php',
      '/sistema/apis_restaurantes/api_desktop/1.0.01/produtos/listar_por_categoria.php',
    ]);
  });

  test('listar categoria nao duplica leitura no desktop em segundo plano',
      () async {
    final almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
    final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api37/');
    addTearDown(() => api.cliente.close(force: true));
    final adapter = _AdapterCardapioFallback(almoco);
    api.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
    addTearDown(usuario.dispose);

    final produtos =
        await ServicoProduto(api, usuario).listarPorCategoria('0', 1);
    await Future<void>.delayed(Duration.zero);

    expect(produtos, hasLength(1));
    expect(adapter.chamadas, hasLength(1));
    expect(adapter.chamadas.single.uri.path,
        endsWith('/api37/produtos/listar_por_categoria.php'));
  });

  test('fallback desktop nao retém ingredientes de consulta concluida',
      () async {
    final almoco = jsonDecode(
            File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
        as Map<String, dynamic>;
    final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/api37/');
    addTearDown(() => api.cliente.close(force: true));
    final adapter = _AdapterCardapioFallback(almoco);
    api.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
    addTearDown(usuario.dispose);
    final servico = ServicoProduto(api, usuario);
    final antes = await servico.listarPorId('436', '0');
    expect(antes!.opcoesPacotes!.first.dados!.first.nome, 'Arroz');

    almoco['opcoesPacotes'][0]['dados'][0]['nome'] = 'Arroz integral';
    final depois = await servico.listarPorId('436', '0');

    expect(depois!.opcoesPacotes!.first.dados!.first.nome, 'Arroz integral');
    expect(
        adapter.chamadas.where((c) => c.uri.path
            .endsWith('/api_desktop/1.0.01/produtos/listar_por_categoria.php')),
        hasLength(2));
  });
}
