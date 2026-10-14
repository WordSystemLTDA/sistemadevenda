import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AdapterClientes implements HttpClientAdapter {
  _AdapterClientes(this.resposta, {this.contentType = Headers.jsonContentType});
  final Map<String, dynamic> resposta;
  final String contentType;
  final chamadas = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    return ResponseBody.fromString(jsonEncode(resposta), 200, headers: {
      Headers.contentTypeHeader: [contentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final modo in ['online', 'local']) {
    group(modo, () {
      setUp(() => SharedPreferences.setMockInitialValues({
            'conexao': jsonEncode({
              'tipoConexao': modo,
              'servidor': '192.168.2.113',
              'porta': '9980',
            }),
          }));

      test('$modo mostra recusa de celular duplicado sem exigir ID na resposta',
          () async {
        final adapter = _AdapterClientes({
          'sucesso': false,
          'mensagem': 'Este celular já está cadastrado.',
        });
        final api = DioCliente()..cliente.httpClientAdapter = adapter;
        final usuario = UsuarioProvedor()
          ..setUsuario(
              UsuarioModelo(id: '311', empresa: '2', nome: 'Operador'));
        final provedor = ProvedorComanda(ServicoComandas(api, usuario));
        addTearDown(() => api.cliente.close());
        addTearDown(usuario.dispose);
        addTearDown(provedor.dispose);

        final resposta =
            await provedor.inserirCliente('Cliente', '(44) 99999-1111', '', '');

        expect(resposta.sucesso, isFalse);
        expect(resposta.idcliente, isEmpty);
        expect(resposta.mensagem, 'Este celular já está cadastrado.');
        expect(adapter.chamadas, hasLength(1));
        final chamada = adapter.chamadas.single;
        expect(chamada.uri.scheme, modo == 'online' ? 'https' : 'http');
        expect(chamada.uri.host,
            modo == 'online' ? 'bigchef.com.br' : '192.168.2.113');
        expect(chamada.uri.path,
            '/sistema/apis_restaurantes/api_restaurantes_venda/api42/comandas/inserir_cliente.php');
        expect(chamada.data['empresa'], '2');
        expect(chamada.data['acao'], 'cadastrar');
        expect(chamada.data, isNot(contains('id')));
      });

      test('$modo aceita ID numerico confirmado pelo servidor', () async {
        final adapter = _AdapterClientes({
          'sucesso': true,
          'idcliente': 7,
          'nomecliente': "Cliente d'Agua",
          'mensagem': 'Cliente cadastrado',
        });
        final api = DioCliente()..cliente.httpClientAdapter = adapter;
        final usuario = UsuarioProvedor()
          ..setUsuario(
              UsuarioModelo(id: '311', empresa: '2', nome: 'Operador'));
        addTearDown(() => api.cliente.close());
        addTearDown(usuario.dispose);

        final resposta = await ServicoComandas(api, usuario)
            .inserirCliente("Cliente d'Agua", '', '', "Portao d'agua");

        expect(resposta.sucesso, isTrue);
        expect(resposta.idcliente, '7');
        expect(resposta.nomecliente, "Cliente d'Agua");
        expect(adapter.chamadas.single.data['obs'], "Portao d'agua");
      });

      test('$modo salva cliente sem email quando resposta tem header de texto',
          () async {
        final adapter = _AdapterClientes({
          'sucesso': true,
          'idcliente': 8,
          'nomecliente': 'Cliente sem email',
          'mensagem': 'Cliente cadastrado',
        }, contentType: 'text/html');
        final api = DioCliente()..cliente.httpClientAdapter = adapter;
        final usuario = UsuarioProvedor()
          ..setUsuario(
              UsuarioModelo(id: '311', empresa: '2', nome: 'Operador'));
        addTearDown(() => api.cliente.close());
        addTearDown(usuario.dispose);
        final resposta = await ServicoComandas(api, usuario)
            .inserirCliente('Cliente sem email', '', '', '');
        expect(resposta.sucesso, isTrue);
        expect(resposta.idcliente, '8');
        expect(adapter.chamadas, hasLength(1));
        expect(adapter.chamadas.single.data['email'], isEmpty);
        expect(adapter.chamadas.single.data, isNot(contains('cpf')));
      });

      test('$modo nao confirma cadastro sem ID valido', () async {
        final api = DioCliente()
          ..cliente.httpClientAdapter = _AdapterClientes({'sucesso': true});
        final usuario = UsuarioProvedor()
          ..setUsuario(
              UsuarioModelo(id: '311', empresa: '2', nome: 'Operador'));
        final provedor = ProvedorComanda(ServicoComandas(api, usuario));
        addTearDown(() => api.cliente.close());
        addTearDown(usuario.dispose);
        addTearDown(provedor.dispose);

        final resposta = await provedor.inserirCliente('Cliente', '', '', '');

        expect(resposta.sucesso, isFalse);
        expect(resposta.mensagem,
            'O servidor não confirmou o cadastro do cliente.');
      });
    });
  }
}
