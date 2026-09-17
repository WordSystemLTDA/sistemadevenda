import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
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
    final quebrado = Map<String, dynamic>.from(almoco)
      ..['idCategoriaCardapio'] = null
      ..['id_categoria_cardapio'] = null
      ..['opcoesPacotes'] = [almoco['opcoesPacotes'][1]];

    if (caminho
        .endsWith('/api_restaurantes_venda/api1/produtos/listar_por_id.php')) {
      return _json(quebrado);
    }
    if (caminho
        .endsWith('/api_desktop/1.0.01/produtos/listar_por_categoria.php')) {
      return _json([almoco]);
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

    final produto = await ServicoProduto(api, usuario).listarPorId('436', '0');

    expect(produto!.idCategoriaCardapio, '3');
    expect(produto.opcoesPacotes!.map((e) => e.tipo), [8, 3]);
    expect(produto.opcoesPacotes!.first.dados!.map((e) => e.nome),
        ['Arroz', 'Carne de Panela', 'Feijão']);
    expect(adapter.chamadas.map((e) => e.uri.path), [
      '/sistema/apis_restaurantes/api_restaurantes_venda/api1/produtos/listar_por_id.php',
      '/sistema/apis_restaurantes/api_desktop/1.0.01/produtos/listar_por_categoria.php',
    ]);
  });
}
