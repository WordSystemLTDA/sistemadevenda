import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

bool produtoVendidoPorPeso(Modelowordprodutos produto) =>
    normalizarBusca(produto.ativarEdQtd ?? '') == 'sim';

int quantidadeEmGramas(Modelowordprodutos produto) =>
    ((produto.quantidade ?? 0) * 1000).round();

String formatarQuantidadeEmGramas(Modelowordprodutos produto) =>
    '${quantidadeEmGramas(produto)} g';
