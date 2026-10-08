/// Identifica avisos da mesma empresa e API; nunca transporta pedidos ou comandos.
class CanalAtualizacaoOnline {
  static const chaveEscopo = 'escopoAtualizacao';
  static const parametroEscopo = 'escopo_atualizacao';

  static String? criarEscopo(String api, String empresa) {
    final uri = Uri.tryParse(api);
    final id = int.tryParse(empresa.trim());
    if (uri == null || uri.host.isEmpty || id == null || id <= 0) return null;
    return 'online|${uri.host.toLowerCase()}|$id';
  }

  static const _tipos = {
    'mesa',
    'mesas',
    'comanda',
    'comandas',
    'balcao',
    'balcão',
    'delivery',
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
    'banco_pix',
    'bancos',
    'formas_pgtos',
  };

  /// Retorna somente a invalidacao da tela. Dados comerciais, impressao,
  /// respostas e comandos de banco nao pertencem a este canal.
  static Map<String, dynamic>? aviso(Map<String, dynamic> dados) {
    final tipo = (dados['tipo'] ?? '').toString().trim();
    final normalizado = tipo.toLowerCase();
    if (dados['tipoImpressao'] != null || !_tipos.contains(normalizado)) {
      return null;
    }
    return {
      'tipo': switch (normalizado) {
        'mesas' => 'Mesa',
        'comandas' => 'Comanda',
        _ => tipo,
      }
    };
  }
}
