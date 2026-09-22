import 'package:app/src/modulos/voz/acao_pedido_voz.dart';
import 'package:app/src/modulos/voz/pedido_falado.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('comandos de inclusão adicionam ao carrinho', () {
    expect(identificarAcaoPedidoVoz('Coloca uma Coca-Cola de 1 litro'),
        AcaoPedidoVoz.adicionar);
    expect(identificarAcaoPedidoVoz('Adicione uma Coca-Cola de 1 litro'),
        AcaoPedidoVoz.adicionar);
  });

  test('comandos de consulta apenas pesquisam o cardápio', () {
    expect(identificarAcaoPedidoVoz('Busque uma Coca-Cola de 1 litro'),
        AcaoPedidoVoz.buscar);
    expect(identificarAcaoPedidoVoz('Lista para mim a Coca-Cola de 1 litro'),
        AcaoPedidoVoz.buscar);
    expect(identificarAcaoPedidoVoz('Quero que mostre uma Coca-Cola'),
        AcaoPedidoVoz.buscar);
  });

  test('pesquisa usa o nome interpretado do produto', () {
    const pedido = PedidoFalado(
      pizza: false,
      produto: 'Coca-Cola 1L',
      tamanho: '',
      quantidade: 1,
      sabores: [],
      bordas: [],
      adicionais: [],
      observacao: '',
    );
    expect(termoBuscaPedidoVoz([pedido]), 'Coca-Cola 1L');
  });
}
