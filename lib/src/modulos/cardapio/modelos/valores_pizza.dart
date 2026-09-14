import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ValoresPizza {
  static final RegExp _proporcaoNoInicio = RegExp(r'^\(\d+(?:/\d+)?\)\s+');
  static final RegExp _meioNoInicio =
      RegExp(r'^Meio\s+-\s+\(\d+(?:/\d+)?\)\s+', caseSensitive: false);

  static int _centavos(String? valor) =>
      ((double.tryParse(valor ?? '') ?? 0) * 100).round();

  static bool bordaSomenteMetade(List<ModeloDadosOpcoesPacotes> dados) =>
      dados.any((dado) => dado.somenteMetadeBorda);

  static int _divisorProporcaoBorda(List<ModeloDadosOpcoesPacotes> dados) =>
      bordaSomenteMetade(dados) ? dados.length * 2 : dados.length;

  static int _totalComProporcaoBorda(
          int centavos, List<ModeloDadosOpcoesPacotes> dados) =>
      bordaSomenteMetade(dados) ? (centavos / 2).round() : centavos;

  static String proporcaoBorda(ModeloDadosOpcoesPacotes dado, int totalBordas) {
    if (dado.somenteMetadeBorda) {
      return '1/${totalBordas <= 1 ? 2 : totalBordas * 2}';
    }
    return totalBordas <= 1 ? '1' : '1/$totalBordas';
  }

  static String nomeBorda(ModeloDadosOpcoesPacotes dado, int totalBordas) {
    final nome = dado.nome;
    final nomeLimpo = nome.trimLeft();
    if (_meioNoInicio.hasMatch(nomeLimpo) ||
        _proporcaoNoInicio.hasMatch(nomeLimpo)) {
      return nome;
    }
    return '(${proporcaoBorda(dado, totalBordas)}) $nome';
  }

  static String nomeBordaDetalhada(
      ModeloDadosOpcoesPacotes dado, int totalBordas) {
    final nome = nomeBorda(dado, totalBordas);
    if (!dado.somenteMetadeBorda) return nome;
    return _meioNoInicio.hasMatch(nome.trimLeft()) ? nome : 'Meio - $nome';
  }

  static String nomeBordaCarrinho(
          ModeloDadosOpcoesPacotes dado, int totalBordas) =>
      nomeBordaDetalhada(dado, totalBordas);

  static double calcular(List<ModeloDadosOpcoesPacotes> dados, String? modelo) {
    if (dados.isEmpty) return 0;
    final valores = dados.map((d) => _centavos(d.valorOriginal ?? d.valor));
    final totalInteiro = modelo == 'maior'
        ? valores.reduce((a, b) => a > b ? a : b)
        : (valores.reduce((a, b) => a + b) / dados.length).round();
    final total = _totalComProporcaoBorda(totalInteiro, dados);
    return total / 100;
  }

  static List<ModeloDadosOpcoesPacotes> ratear(
      List<ModeloDadosOpcoesPacotes> dados, String? modelo) {
    if (dados.isEmpty) return [];
    final somenteMetade = bordaSomenteMetade(dados);
    final valores =
        dados.map((d) => _centavos(d.valorOriginal ?? d.valor)).toList();
    final totalInteiro = modelo == 'maior'
        ? valores.reduce((a, b) => a > b ? a : b)
        : (valores.reduce((a, b) => a + b) / dados.length).round();
    final total = _totalComProporcaoBorda(totalInteiro, dados);
    final divisor = _divisorProporcaoBorda(dados);
    final parcelas =
        modelo == 'maior' ? List.filled(dados.length, totalInteiro) : valores;
    final centavos = parcelas.map((v) => v ~/ divisor).toList();
    final ordem = List.generate(dados.length, (i) => i)
      ..sort((a, b) {
        final diferenca =
            (parcelas[b] % divisor).compareTo(parcelas[a] % divisor);
        return diferenca == 0 ? a.compareTo(b) : diferenca;
      });
    // Distribui centavos restantes sem alterar o total cobrado.
    final restante =
        total - centavos.fold<int>(0, (soma, valor) => soma + valor);
    for (var i = 0; i < restante; i++) {
      centavos[ordem[i]]++;
    }
    return List.generate(
        dados.length,
        (i) => ModeloDadosOpcoesPacotes.fromMap({
              ...dados[i].toMap(),
              'valorOriginal': (valores[i] / 100).toStringAsFixed(2),
              'valor': (centavos[i] / 100).toStringAsFixed(2),
              if (somenteMetade) 'somenteMetadeBorda': true,
            }));
  }

  static double somar(ModeloOpcoesPacotes grupo) => (grupo.dados ?? []).fold(
      0.0,
      (soma, dado) =>
          soma + _centavos(dado.valor) * (dado.quantidade ?? 1) / 100);

  static double subtotal(Modelowordprodutos item, ModeloOpcoesPacotes grupo) {
    final opcoes = item.opcoesPacotesListaFinal ?? [];
    final tamanho = opcoes.where((o) => o.id == 9).firstOrNull;
    if (grupo.id == 10 && tamanho != null) return somar(tamanho);
    if (grupo.id == 6 &&
        tamanho != null &&
        (grupo.dados ?? []).any((d) => d.valorOriginal == null)) {
      // Carrinhos anteriores guardavam os precos inteiros das bordas.
      final outros = opcoes
          .where((o) => ![6, 9, 10].contains(o.id))
          .fold(0.0, (total, o) => total + somar(o));
      final borda = _centavos(item.valorVenda) / 100 - somar(tamanho) - outros;
      return double.parse(borda.clamp(0, double.infinity).toStringAsFixed(2));
    }
    return somar(grupo);
  }
}
