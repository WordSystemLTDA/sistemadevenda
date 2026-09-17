import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class SincronizadorPresente extends Fake implements Sincronizador {}

class ApiCancelamentoTeste extends Fake implements DioCliente {
  @override
  final Dio cliente = Dio();
  final chamadas = <RequestOptions>[];
  final corpos = <Map<String, dynamic>>[];
  bool falharConexao = false;

  ApiCancelamentoTeste() {
    cliente.interceptors.add(InterceptorsWrapper(onRequest: (opcoes, handler) {
      chamadas.add(opcoes);
      corpos.add(Map<String, dynamic>.from(
          jsonDecode(opcoes.data as String) as Map<String, dynamic>));
      if (falharConexao) {
        handler.reject(DioException(
          requestOptions: opcoes,
          type: DioExceptionType.connectionError,
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: opcoes,
        statusCode: 200,
        data: {
          'sucesso': true,
          'mensagem': 'Item cancelado e enviado para impressão.',
          'destino_impressao_caixa': {
            'nomeDaImpressora': 'Caixa',
            'tamanhoDoPapel': '80',
            'avancoPapel': '5',
            'nome': 'Caixa',
          },
        },
      ));
    }));
  }
}

Modeloworddadoscardapio atendimentoTeste() => Modeloworddadoscardapio(
      id: '98',
      idComanda: '1',
      idMesa: '0',
      status: 'Andamento',
      versaoAtendimento: 'versao-98',
    );

Modelowordprodutos produtoTeste() => Modelowordprodutos(
      id: '2',
      iditensvenda: '55',
      nome: 'Pizza de Queijos',
      codigo: '2',
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '64',
      categoria: '',
      nomeCategoria: '',
      habilTipo: '',
      ingredientes: [],
    );

void main() {
  late UsuarioProvedor usuario;
  late ApiCancelamentoTeste api;

  setUp(() {
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '32'));
    api = ApiCancelamentoTeste();
    Sincronizador.instancia = SincronizadorPresente();
  });

  tearDown(() {
    Sincronizador.instancia = null;
    usuario.dispose();
    api.cliente.close(force: true);
  });

  test('cancela item no servidor mesmo com sincronizador ativo', () async {
    final resposta = await ServicoCardapio(api, usuario).cancelarItemFinalizado(
      tipo: TipoCardapio.comanda,
      atendimento: atendimentoTeste(),
      produto: produtoTeste(),
      idMesa: '0',
      idComanda: '1',
      senhaAdmin: 'senha-certa',
    );

    expect(resposta.sucesso, isTrue);
    expect(api.chamadas.single.path, 'comandas/cancelar_item_finalizado.php');
    expect(api.corpos.single, containsPair('id_comanda_pedido', '98'));
    expect(api.corpos.single, containsPair('id_itens_venda', '55'));
    expect(
        api.corpos.single, containsPair('senha_admin_cancelar', 'senha-certa'));
  });

  test('mostra aviso de conexao somente quando a requisicao falha por rede',
      () async {
    api.falharConexao = true;

    final resposta = await ServicoCardapio(api, usuario).cancelarItemFinalizado(
      tipo: TipoCardapio.comanda,
      atendimento: atendimentoTeste(),
      produto: produtoTeste(),
      idMesa: '0',
      idComanda: '1',
      senhaAdmin: 'senha-certa',
    );

    expect(resposta.sucesso, isFalse);
    expect(
      resposta.mensagem,
      'Conecte ao servidor para cancelar item finalizado com senha Admin.',
    );
    expect(api.chamadas.single.path, 'comandas/cancelar_item_finalizado.php');
  });
}
