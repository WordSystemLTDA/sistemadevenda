import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/voz/acao_pedido_voz.dart';
import 'package:app/src/modulos/voz/falha_pedido_voz.dart';
import 'package:app/src/modulos/voz/servico_pedido_voz.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class AdaptadorVozTeste implements HttpClientAdapter {
  int status = 200;
  Object sessao = {'sucesso': true, 'protocolo': 1, 'token': 'token-teste'};
  Object capacidades = {'sucesso': true, 'protocolo': 1, 'destino_voz': 1};
  Object? pedido;
  final chamadas = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    final dados = options.path == 'voz/sessao.php'
        ? sessao
        : options.method == 'POST'
            ? pedido ?? capacidades
            : capacidades;
    return ResponseBody.fromString(jsonEncode(dados), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ServicoPedidoVoz servico;
  late AdaptadorVozTeste adaptador;
  late UsuarioProvedor usuario;

  setUp(() {
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '7', empresa: '32', senha: 'senha-teste'));
    adaptador = AdaptadorVozTeste();
    final cliente = Dio(BaseOptions(baseUrl: 'http://192.168.2.113/api1/'))
      ..httpClientAdapter = adaptador;
    servico = ServicoPedidoVoz(
        servidor: cliente.options.baseUrl,
        usuario: usuario,
        clienteVoz: cliente);
  });
  tearDown(() {
    servico.dispose();
    usuario.dispose();
  });

  test(
      'sessao usa a empresa logada e envia apenas o token nas proximas chamadas',
      () async {
    await servico.verificar();
    expect(adaptador.chamadas, hasLength(2));
    expect(adaptador.chamadas.first.data,
        {'empresa': '32', 'id_usuario': '7', 'senha': 'senha-teste'});
    expect(adaptador.chamadas.last.headers['X-Garcom-Voz'], 'token-teste');
    expect(adaptador.chamadas.last.data, isNull);
  });

  test('disponibilidade nao cria token nem consulta catalogo', () async {
    adaptador.sessao = {
      'sucesso': true,
      'protocolo': 2,
      'habilitado': true,
      'provedor': 'openai'
    };
    expect(await servico.disponivel(), isTrue);
    expect(adaptador.chamadas, hasLength(1));
    expect(adaptador.chamadas.single.data, {
      'empresa': '32',
      'id_usuario': '7',
      'senha': 'senha-teste',
      'somente_disponibilidade': true,
    });
    expect(adaptador.chamadas.single.headers['X-Garcom-Voz'], isNull);
  });

  test('disponibilidade desativada oculta a voz', () async {
    adaptador.sessao = {
      'sucesso': true,
      'protocolo': 2,
      'habilitado': false,
      'provedor': ''
    };
    expect(await servico.disponivel(), isFalse);
    expect(adaptador.chamadas, hasLength(1));
  });

  test(
      'protocolo2 envia rascunho e contexto e preserva pergunta sem consultar catálogo',
      () async {
    adaptador.sessao = {
      'sucesso': true,
      'protocolo': 2,
      'token': 'token-teste'
    };
    adaptador.capacidades = {
      'sucesso': true,
      'protocolo': 2,
      'provedor': 'local',
      'timeout_segundos': 120
    };
    adaptador.pedido = {
      'sucesso': true,
      'protocolo': 2,
      'texto': 'Uma pizza',
      'pedido': {'itens': [], 'esclarecimento': 'Qual tamanho?'}
    };
    await servico.verificar();
    expect(servico.suportaLote, isTrue);
    await expectLater(
        servico.interpretarLote(
            texto: 'Uma pizza',
            rascunho: {'itens': [], 'esclarecimento': ''},
            contexto: {'historico': [], 'pergunta': ''}),
        throwsA(isA<EsclarecimentoPedidoVoz>()
            .having((e) => e.texto, 'texto', 'Uma pizza')));
    final chamada = adaptador.chamadas.last;
    final campos = Map.fromEntries((chamada.data as FormData).fields);
    expect(campos['protocolo'], '2');
    expect(
        jsonDecode(campos['rascunho']!), {'itens': [], 'esclarecimento': ''});
    expect(jsonDecode(campos['contexto']!), {'historico': [], 'pergunta': ''});
    expect(campos.containsKey('senha'), isFalse);
    expect(chamada.headers['X-Garcom-Voz'], 'token-teste');
    expect(chamada.receiveTimeout, const Duration(seconds: 260));
  });

  test('comando de busca retorna o termo sem montar ou adicionar produto',
      () async {
    adaptador.sessao = {
      'sucesso': true,
      'protocolo': 2,
      'token': 'token-teste'
    };
    adaptador.capacidades = {
      'sucesso': true,
      'protocolo': 2,
      'provedor': 'openai',
      'timeout_segundos': 120
    };
    adaptador.pedido = {
      'sucesso': true,
      'protocolo': 2,
      'texto': 'Busque uma Coca-Cola de 1 litro',
      'pedido': {
        'itens': [
          {
            'tipo': 'produto',
            'produto': 'Coca-Cola 1L',
            'tamanho': '',
            'quantidade': 1,
            'sabores': [],
            'bordas': [],
            'adicionais': [],
            'ingredientes': [],
            'retiradas': [],
            'acompanhamentos': [],
            'cortesias': [],
            'observacao': '',
          }
        ],
        'esclarecimento': ''
      }
    };

    await servico.verificar();
    final lote =
        await servico.interpretarLote(texto: 'Busque uma Coca-Cola de 1 litro');

    expect(lote.acao, AcaoPedidoVoz.buscar);
    expect(lote.termoBusca, 'Coca-Cola 1L');
    expect(lote.itens, isEmpty);
    expect(adaptador.chamadas, hasLength(3));
  });

  for (final status in [401, 429, 503]) {
    test('preserva o motivo da falha da API com status $status', () async {
      adaptador.status = status;
      adaptador.sessao = {
        'sucesso': false,
        'mensagem': 'Motivo retornado pela API'
      };
      await expectLater(
          servico.verificar(),
          throwsA(isA<FalhaPedidoVoz>().having((e) => e.toString(), 'mensagem',
              contains('Motivo retornado pela API'))));
      expect(adaptador.chamadas, hasLength(1));
    });
  }

  test('erro sem JSON usa mensagem de conexao', () async {
    adaptador.status = 502;
    adaptador.sessao = 'Bad gateway';
    await expectLater(
        servico.verificar(),
        throwsA(isA<FalhaPedidoVoz>().having((e) => e.toString(), 'mensagem',
            contains('conectar ao serviço de voz'))));
  });

  for (final token in [null, '', 42]) {
    test('sessao sem token valido nao consulta nem envia pedido ($token)',
        () async {
      adaptador.sessao = {'sucesso': true, 'protocolo': 1, 'token': token};
      await expectLater(servico.verificar(), throwsA(isA<FalhaPedidoVoz>()));
      expect(adaptador.chamadas, hasLength(1));
    });
  }

  test('HTTP conserva caminho e porta somente para IP privado ou loopback', () {
    for (final host in [
      '10.0.0.1',
      '172.16.0.1',
      '172.31.255.254',
      '192.168.2.113',
      '127.0.0.1',
      'localhost',
      '[::1]'
    ]) {
      final endereco = 'http://$host:8080/sistema/api1/';
      expect(ServicoPedidoVoz.enderecoSeguro(endereco), endereco);
    }
    for (final host in [
      '172.15.0.1',
      '172.32.0.1',
      '192.169.0.1',
      '8.8.8.8',
      '10.0.0.1.example',
      'restaurante.example'
    ]) {
      expect(
          Uri.parse(ServicoPedidoVoz.enderecoSeguro('http://$host/api1/'))
              .scheme,
          'https');
    }
    expect(ServicoPedidoVoz.enderecoSeguro('https://192.168.2.113:8443/api1/'),
        'https://192.168.2.113:8443/api1/');
  });
}
