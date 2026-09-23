import 'package:flutter/foundation.dart';

/// Sinais de cadastro: os consumidores consultam a API, sem guardar respostas.
class EventosCatalogo extends ChangeNotifier {
  EventosCatalogo._();
  static final produtos = EventosCatalogo._();
  static final pagamentos = EventosCatalogo._();

  static const _tiposProdutos = {
    'produto',
    'produtos',
    'cardapio',
    'cardápio',
    'categoria',
    'categorias',
    'cat_categorias',
    'cat_produtos',
    'sequencias_de_categoria',
    'cat_tamanhos_pizza',
    'tamanhos_pizza',
    'vincular_pizza',
    'cat_sabores',
    'sabores',
    'vincular_sabores',
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
    'itens_retiradas',
    'lista_itens_retirada',
    'vincular_itens_retirada',
    'categorias_cardapio',
    'ingredientes_cardapio',
    'vincular_cardapio',
    'config_bigchef',
    'config_produtos',
    'desconto_por_produto',
    'cod_destino_de_impressao',
    'destino_de_impressao',
  };

  static const _tiposPagamentos = {'banco_pix', 'bancos', 'formas_pgtos'};

  /// Compartilha a classificacao com a sincronizacao sem disparar leituras.
  /// Eventos de pedidos e da conexao nao alteram o cadastro do cardapio.
  static bool ehProduto(String tipo) =>
      _tiposProdutos.contains(tipo.trim().toLowerCase());

  static bool ehPagamento(String tipo) =>
      _tiposPagamentos.contains(tipo.trim().toLowerCase());

  static void notificar(String tipo) {
    if (ehProduto(tipo)) produtos.notifyListeners();
    if (ehPagamento(tipo)) pagamentos.notifyListeners();
  }
}
