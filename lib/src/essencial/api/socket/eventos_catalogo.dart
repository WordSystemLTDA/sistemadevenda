import 'package:flutter/foundation.dart';

/// Sinais de cadastro: os consumidores consultam a API, sem guardar respostas.
class EventosCatalogo extends ChangeNotifier {
  EventosCatalogo._();
  static final produtos = EventosCatalogo._();
  static final pagamentos = EventosCatalogo._();

  static const _tiposProdutos = {
    'produtos',
    'categorias',
    'cat_categorias',
    'cat_produtos',
    'sequencias_de_categoria',
    'cat_tamanhos_pizza',
    'tamanhos_pizza',
    'vincular_pizza',
    'sabores_de_bordas',
    'vincular_sabor_de_bordas',
    'cat_adicionais',
    'adicionais',
    'vincular_adicionais',
    'cat_acompanhamentos',
    'acompanhamentos',
    'vincular_acompanhamentos',
    'cat_cortesia',
    'cortesias',
    'cat_tamanhos',
    'tamanhos',
    'vincular_tamanhos',
    'ingredientes_cardapio',
    'vincular_cardapio',
    'desconto_por_produto',
    'cod_destino_de_impressao',
    'destino_de_impressao',
  };

  static void notificar(String tipo) {
    final normalizado = tipo.trim().toLowerCase();
    if (_tiposProdutos.contains(normalizado)) produtos.notifyListeners();
    if (const {'banco_pix', 'bancos', 'formas_pgtos'}.contains(normalizado)) {
      pagamentos.notifyListeners();
    }
  }
}
