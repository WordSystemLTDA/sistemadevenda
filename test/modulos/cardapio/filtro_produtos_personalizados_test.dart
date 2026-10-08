import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('online api39 envia empresa 2 para categorias e produtos', () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'online',
        'servidor': '192.168.2.113',
        'porta': '9980',
      }),
    });
    final api = DioCliente();
    final adapter = _AdapterEmpresa2();
    api.cliente.httpClientAdapter = adapter;
    addTearDown(() => api.cliente.close(force: true));
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '123', empresa: '2'));
    addTearDown(usuario.dispose);

    final categorias = await ServicosCategoria(api, usuario).listar();
    final produtos =
        await ServicoProduto(api, usuario).listarPorCategoria('0', 1);

    expect(categorias.map((categoria) => categoria.id), ['0', '1']);
    expect(produtos.map((produto) => produto.id), ['15']);
    expect(adapter.chamadas, hasLength(2));
    for (final chamada in adapter.chamadas) {
      expect(chamada.uri.scheme, 'https');
      expect(chamada.uri.host, 'bigchef.com.br');
      expect(
          chamada.uri.path,
          startsWith(
              '/sistema/apis_restaurantes/api_restaurantes_venda/api39/'));
      expect(chamada.uri.queryParameters['empresa'], '2');
    }
    expect(adapter.chamadas.last.uri.queryParameters['id_usuario'], '123');
  });

  test('catalogo mostra somente produtos personalizados quando habilitado',
      () async {
    final api = DioCliente(servidor: 'http://localhost/api37/');
    final adapter = _AdapterProdutos();
    api.cliente.httpClientAdapter = adapter;
    addTearDown(() => api.cliente.close(force: true));

    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'))
      ..setConfigBigChef(ModeloConfigBigchef.fromMap({
        'mostrar_apenas_produtos_ativo_venda': 'Sim',
      }));
    addTearDown(usuario.dispose);

    final produtos =
        await ServicoProduto(api, usuario).listarPorCategoria('0', 1);

    expect(produtos.map((produto) => produto.id), ['2']);
    expect(
      adapter.ultimaRequisicao.uri
          .queryParameters['mostrar_apenas_produtos_ativo_venda'],
      'Sim',
    );
  });

  test('configuracao desabilitada preserva todos os produtos', () async {
    final api = DioCliente(servidor: 'http://localhost/api37/');
    final adapter = _AdapterProdutos();
    api.cliente.httpClientAdapter = adapter;
    addTearDown(() => api.cliente.close(force: true));

    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'))
      ..setConfigBigChef(ModeloConfigBigchef.fromMap({
        'mostrar_apenas_produtos_ativo_venda': 'Não',
      }));
    addTearDown(usuario.dispose);

    final produtos =
        await ServicoProduto(api, usuario).listarPorCategoria('0', 1);

    expect(produtos, hasLength(2));
    expect(
      adapter.ultimaRequisicao.uri.queryParameters,
      isNot(contains('mostrar_apenas_produtos_ativo_venda')),
    );
  });

  test('nao mostra categorias sem produtos vinculados', () async {
    final api = DioCliente(servidor: 'http://localhost/api37/');
    final adapter = _AdapterCategorias();
    api.cliente.httpClientAdapter = adapter;
    addTearDown(() => api.cliente.close(force: true));

    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    addTearDown(usuario.dispose);

    final categorias = await ServicosCategoria(api, usuario).listar();

    expect(categorias.map((categoria) => categoria.id), ['0', '12']);
  });
}

class _AdapterEmpresa2 implements HttpClientAdapter {
  final chamadas = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    final dados = options.uri.path.endsWith('/categorias/listar.php')
        ? [
            {'id': '0', 'nomeCategoria': 'Todos', 'quantidadeProdutos': '1'},
            {'id': '1', 'nomeCategoria': 'Bebidas', 'quantidadeProdutos': '1'},
          ]
        : [_AdapterProdutos()._produto('15', 'Sim')];
    return ResponseBody.fromString(jsonEncode(dados), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

class _AdapterProdutos implements HttpClientAdapter {
  late RequestOptions ultimaRequisicao;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    ultimaRequisicao = options;
    return ResponseBody.fromString(
      jsonEncode([
        _produto('1', 'Não'),
        _produto('2', 'Sim'),
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _produto(String id, String personalizado) => {
        'id': id,
        'nome': 'Produto $id',
        'codigo': id,
        'estoque': '0',
        'tamanho': '',
        'foto': '',
        'ativo': 'Sim',
        'descricao': '',
        'valorVenda': '10',
        'categoria': '0',
        'nomeCategoria': '',
        'habilTipo': 'Normal',
        'ingredientes': [],
        'ativar_produto_personalizado_no_cardapio': personalizado,
      };

  @override
  void close({bool force = false}) {}
}

class _AdapterCategorias implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode([
        _categoria('0', 'Todos', '1'),
        _categoria('12', 'Bebidas', '1'),
        _categoria('13', 'Categoria vazia', '0'),
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, dynamic> _categoria(String id, String nome, String quantidade) =>
      {
        'id': id,
        'nomeCategoria': nome,
        'quantidadeProdutos': quantidade,
      };

  @override
  void close({bool force = false}) {}
}
