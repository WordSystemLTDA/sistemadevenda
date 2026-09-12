import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ValoresPizza {
  static int _centavos(String? valor) =>
      ((double.tryParse(valor ?? '') ?? 0) * 100).round();

  static double calcular(List<ModeloDadosOpcoesPacotes> dados, String? modelo) {
    if (dados.isEmpty) return 0;
    final valores = dados.map((d) => _centavos(d.valorOriginal ?? d.valor));
    final total = modelo == 'maior'
        ? valores.reduce((a, b) => a > b ? a : b)
        : (valores.reduce((a, b) => a + b) / dados.length).round();
    return total / 100;
  }

  static List<ModeloDadosOpcoesPacotes> ratear(
      List<ModeloDadosOpcoesPacotes> dados, String? modelo) {
    if (dados.isEmpty) return [];
    final valores =
        dados.map((d) => _centavos(d.valorOriginal ?? d.valor)).toList();
    final total = (calcular(dados, modelo) * 100).round();
    final parcelas =
        modelo == 'maior' ? List.filled(dados.length, total) : valores;
    final centavos = parcelas.map((v) => v ~/ dados.length).toList();
    final ordem = List.generate(dados.length, (i) => i)
      ..sort((a, b) {
        final diferenca =
            (parcelas[b] % dados.length).compareTo(parcelas[a] % dados.length);
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
