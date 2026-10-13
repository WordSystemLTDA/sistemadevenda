import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'delivery_test.dart' show AdaptadorDelivery, pedidoTeste;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ações do menu Online usam API42, empresa e pedido atuais', () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'online',
        'servidor': '192.168.2.113',
        'porta': '9980',
      }),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '2'));
    addTearDown(usuario.dispose);
    addTearDown(() => dio.cliente.close());
    final servico = ServicoDelivery(dio, usuario);
    final pedido = pedidoTeste(campos: {'idopcoescarrossel': '11'});
    for (final acao in [
      'clonarCompleto',
      'mensagem1',
      'mensagem2',
      'mensagem3',
      'pix',
      'endereco',
      'retirada',
      'confirmar',
      'pagamentos',
      'alterarPagamento',
      'entrega',
      'venda',
      'enviarNota',
      'cancelar',
    ]) {
      await servico.acao(acao, pedido, {'idDelivery': pedido.id});
      final chamada = adapter.chamadas.last;
      expect(chamada.uri.scheme, 'https');
      expect(chamada.uri.host, 'bigchef.com.br');
      expect(chamada.uri.path,
          '/sistema/apis_restaurantes/api_restaurantes_venda/api42/delivery/acoes_pedido.php');
      final payload = jsonDecode(chamada.data as String) as Map;
      expect(payload['empresa'], '2');
      expect(payload['id_usuario'], '2');
      expect(payload['id'], '25');
      expect(payload['statusOrigem'], '11');
      expect(payload['acao'], acao);
      if (acao == 'clonarCompleto') expect(payload['origemPedido'], 'garcom');
      expect(chamada.extra['semCache'], isTrue);
    }
  });

  for (final conexao in ['online', 'local']) {
    test('documentos fiscais em $conexao apontam à pasta da API', () async {
      SharedPreferences.setMockInitialValues({
        'conexao': jsonEncode({
          'tipoConexao': conexao,
          'servidor': '192.168.2.113',
          'porta': '9980',
        }),
      });
      final dio = DioCliente();
      addTearDown(() => dio.cliente.close());
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(id: '2', empresa: '2'));
      addTearDown(usuario.dispose);
      final servico = ServicoDelivery(dio, usuario);
      final chave = List.filled(44, '1').join();
      for (final modelo in ['55', '65']) {
        for (final ambiente in ['1', '2']) {
          for (final xml in [true, false]) {
            final pedido = pedidoTeste(campos: {
              'cp15': chave,
              'cp16': modelo,
              'docempresa': '27444723000166',
              'dataEmissao': '2026-10-13',
              'ambienteFiscal': ambiente,
            });
            final uri = await servico.documentoFiscal(pedido, xml: xml);
            expect(uri.host,
                conexao == 'online' ? 'bigchef.com.br' : '192.168.2.113');
            expect(uri.path,
                '/sistema/apis_restaurantes/fiscal/Arquivos_XML/${modelo == '55' ? 'NF-e' : 'NFCe'}/27444723000166/${ambiente == '2' ? 'homologacao' : 'producao'}/enviadas/aprovadas/26/10/$chave-${xml ? 'nfe.xml' : 'pdf.pdf'}');
          }
        }
      }
      expect(() => servico.documentoFiscal(pedidoTeste()), throwsStateError);
    });
  }
}
