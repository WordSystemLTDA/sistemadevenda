import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class DioPesquisa extends Fake implements DioCliente {
  final requisicoes = <RequestOptions>[];
  @override
  final cliente = Dio(BaseOptions(baseUrl: 'http://localhost/'));

  DioPesquisa() {
    cliente.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requisicoes.add(options);
      handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: []));
    }));
  }
}

void main() {
  test('buscas preservam acentos e caracteres especiais sem alterar filtros',
      () async {
    final dio = DioPesquisa();
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '32'));
    addTearDown(usuario.dispose);
    addTearDown(() => dio.cliente.close());
    const pesquisa = 'Açaí & Cia #2 + limão?';

    await ServicoProduto(dio, usuario).listarPorNome(pesquisa, '0', '10');
    await ServicoBalcao(dio, usuario)
        .listar(1, 30, pesquisa, '2026-09-10', '2026-09-10', '05:00:00');
    await ServicoComandas(dio, usuario).listar(pesquisa);
    await ServicoMesas(dio, usuario).listar(pesquisa);

    for (final requisicao in dio.requisicoes) {
      expect(requisicao.uri.queryParameters['pesquisa'], pesquisa);
      expect(requisicao.uri.fragment, isEmpty);
    }
    expect(dio.requisicoes.first.uri.queryParameters['categoria'], '0');
    expect(dio.requisicoes[1].uri.queryParameters['id_empresa'], '32');
    expect(dio.requisicoes.last.uri.queryParameters['empresa'], '32');
  });
}
