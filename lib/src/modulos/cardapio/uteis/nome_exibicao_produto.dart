import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

final _proporcaoNoInicio = RegExp(r'^\(\d+(?:/\d+)?\)\s+');
final _codigoComProporcaoNoInicio = RegExp(r'^\S+\s+-\s+\(\d+(?:/\d+)?\)\s+');

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
  // O snapshot de preparo ja pode conter codigo e fracao no proprio nome.
  // Preserve esse formato ao reabrir o pedido, sem aplicar os prefixos de novo.
  if (_codigoComProporcaoNoInicio.hasMatch(sabor.nome)) return sabor.nome;
  final codigo = sabor.codigo?.trim() ?? '';
  final imprimirCodigo =
      sabor.imprimirCodigoProdutoPreparo == 'Sim' && codigo.isNotEmpty;
  final prefixo = '$codigo - ';
  final nomeSemCodigo = imprimirCodigo && sabor.nome.startsWith(prefixo)
      ? sabor.nome.substring(prefixo.length)
      : sabor.nome;
  final nome = proporcao == null ||
          proporcao.isEmpty ||
          _proporcaoNoInicio.hasMatch(nomeSemCodigo)
      ? nomeSemCodigo
      : '($proporcao) $nomeSemCodigo';

  return imprimirCodigo ? '$prefixo$nome' : nome;
}
