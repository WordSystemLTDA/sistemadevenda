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

void main() {
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
