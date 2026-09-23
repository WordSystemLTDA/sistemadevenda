import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/eventos_catalogo.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('classifica aliases e cadastros que alteram produtos e montagem', () {
    for (final tipo in [
      ' Produto ',
      'PRODUTOS',
      'Cardapio',
      'Cardápio',
      'categorias',
      'cat_produtos',
      'categorias_cardapio',
      'ingredientes_cardapio',
      'vincular_cardapio',
      'config_bigchef',
      'config_produtos',
      'cat_sabores',
      'sabores',
      'vincular_sabores',
      'itens_retiradas',
      'lista_itens_retirada',
      'vincular_itens_retirada',
    ]) {
      expect(EventosCatalogo.ehProduto(tipo), isTrue, reason: tipo);
      expect(EventosCatalogo.ehPagamento(tipo), isFalse, reason: tipo);
    }
  });

  test('pagamentos nao recarregam o catalogo de produtos', () {
    for (final tipo in [' Banco_Pix ', 'BANCOS', 'formas_pgtos']) {
      expect(EventosCatalogo.ehPagamento(tipo), isTrue, reason: tipo);
      expect(EventosCatalogo.ehProduto(tipo), isFalse, reason: tipo);
    }
  });

  test('pedidos e avisos da rede nao sao mudancas de catalogo', () {
    var produtos = 0;
    var pagamentos = 0;
    void produto() => produtos++;
    void pagamento() => pagamentos++;
    EventosCatalogo.produtos.addListener(produto);
    EventosCatalogo.pagamentos.addListener(pagamento);
    addTearDown(() {
      EventosCatalogo.produtos.removeListener(produto);
      EventosCatalogo.pagamentos.removeListener(pagamento);
    });

    for (final tipo in [
      'Mesa',
      'Comanda',
      'Delivery',
      'Balcão',
      'Rede',
      'PC',
      'PreparoPendente',
      'heartbeat_ping',
      '',
    ]) {
      expect(EventosCatalogo.ehProduto(tipo), isFalse, reason: tipo);
      expect(EventosCatalogo.ehPagamento(tipo), isFalse, reason: tipo);
      EventosCatalogo.notificar(tipo);
    }
    expect(produtos, 0);
    expect(pagamentos, 0);
  });

  test('reconciliacao Cardapio e eventos reais chegam imediatamente a tela',
      () {
    var produtos = 0;
    var pagamentos = 0;
    void produto() => produtos++;
    void pagamento() => pagamentos++;
    EventosCatalogo.produtos.addListener(produto);
    EventosCatalogo.pagamentos.addListener(pagamento);
    addTearDown(() {
      EventosCatalogo.produtos.removeListener(produto);
      EventosCatalogo.pagamentos.removeListener(pagamento);
    });

    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: 'Cardapio'));
    expect(produtos, 1);
    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: 'produtos'));
    expect(produtos, 2);
    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: ' banco_pix '));
    expect(produtos, 2);
    expect(pagamentos, 1);
  });
}
