import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

String nomeExibicaoProduto(Modelowordprodutos item) {
  final saboresPizza = (item.opcoesPacotesListaFinal ?? [])
      .where((opcao) => opcao.id == 10)
      .firstOrNull
      ?.dados;

  if (saboresPizza == null || saboresPizza.isEmpty) return item.nome;

  final totalSabores = saboresPizza.length;
  return saboresPizza.map((sabor) {
    final proporcao = sabor.quantimaximaselecao?.trim();
    final prefixo =
        proporcao == null || proporcao.isEmpty ? '1/$totalSabores' : proporcao;
    return nomeSaborPizza(sabor, prefixo);
  }).join('\n');
}

String nomeSaborPizza(
  ModeloDadosOpcoesPacotes sabor, [
  String? proporcao,
]) {
  final nome = proporcao == null || proporcao.isEmpty
      ? sabor.nome
      : '($proporcao) ${sabor.nome}';
  final codigo = sabor.codigo?.trim() ?? '';

  if (sabor.imprimirCodigoProdutoPreparo != 'Sim' || codigo.isEmpty) {
    return nome;
  }

  final prefixo = '$codigo - ';
  return nome.startsWith(prefixo) ? nome : '$prefixo$nome';
}
