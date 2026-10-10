/// Consolida cadastros repetidos sem trocar a identidade de um atendimento.
/// Se houver duas contas abertas distintas, ambas continuam acessiveis.
List<Map<String, dynamic>> recursosAtendimentoUnicos(
    List<dynamic> grupos, String tipo) {
  final campo = tipo == 'mesa' ? 'mesas' : 'comandas';
  final ocupado = tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada';
  final copia = [
    for (final grupo in grupos) Map<String, dynamic>.from(grupo as Map),
  ];
  final candidatos = <({int grupo, int indice, Map<String, dynamic> dados})>[];
  for (var g = 0; g < copia.length; g++) {
    final itens = copia[g][campo] as List? ?? [];
    for (var i = 0; i < itens.length; i++) {
      candidatos.add((
        grupo: g,
        indice: i,
        dados: Map<String, dynamic>.from(itens[i] as Map)
      ));
    }
  }
  bool aberto(Map<String, dynamic> r) =>
      r[ocupado] == true || r['fechamento'] == true;
  String id(Map<String, dynamic> r) => '${r['id'] ?? ''}'.trim();
  String nome(Map<String, dynamic> r) =>
      '${r['nome'] ?? ''}'.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  bool preferir(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (aberto(a) != aberto(b)) return aberto(a);
    if (aberto(a) && a['fechamento'] != b['fechamento']) {
      return a['fechamento'] == true;
    }
    final ativoA = '${a['ativo'] ?? ''}'.toLowerCase() == 'sim';
    final ativoB = '${b['ativo'] ?? ''}'.toLowerCase() == 'sim';
    if (ativoA != ativoB) return ativoA;
    final dataA = DateTime.tryParse('${a['ultimaVezAbertoDataHora'] ?? ''}');
    final dataB = DateTime.tryParse('${b['ultimaVezAbertoDataHora'] ?? ''}');
    if ((dataA != null) != (dataB != null)) return dataA != null;
    final idA = int.tryParse(id(a));
    final idB = int.tryParse(id(b));
    if (idA != null && idB != null) return idA < idB;
    return false;
  }

  final ativosPorId =
      <String, ({int grupo, int indice, Map<String, dynamic> dados})>{};
  for (final c in candidatos.where((c) => aberto(c.dados))) {
    final conta = '${c.dados['idComandaPedido'] ?? ''}'.trim();
    final key = conta.isNotEmpty && conta != '0'
        ? 'conta:$conta'
        : 'recurso:${id(c.dados)}';
    final anterior = ativosPorId[key];
    if (anterior == null || preferir(c.dados, anterior.dados)) {
      ativosPorId[key] = c;
    }
  }
  final idsAbertos = ativosPorId.values.map((c) => id(c.dados)).toSet();
  final ativos = ativosPorId.values.toList();
  final familias =
      <String, List<({int grupo, int indice, Map<String, dynamic> dados})>>{};
  for (final c in candidatos) {
    if (aberto(c.dados) && !ativos.contains(c) ||
        !aberto(c.dados) && idsAbertos.contains(id(c.dados))) {
      continue;
    }
    final n = nome(c.dados);
    final key = n.isNotEmpty ? 'nome:$n' : 'id:${id(c.dados)}';
    familias.putIfAbsent(key, () => []).add(c);
  }
  final escolhidos = <String>{};
  for (final familia in familias.values) {
    final abertas = familia.where((c) => aberto(c.dados)).toList();
    if (abertas.isNotEmpty) {
      for (final c in abertas) {
        escolhidos.add('${c.grupo}:${c.indice}');
      }
    } else {
      var escolhido = familia.first;
      for (final c in familia.skip(1)) {
        if (preferir(c.dados, escolhido.dados)) escolhido = c;
      }
      escolhidos.add('${escolhido.grupo}:${escolhido.indice}');
    }
  }
  return [
    for (var g = 0; g < copia.length; g++)
      {
        ...copia[g],
        campo: [
          for (final c in candidatos.where((c) => c.grupo == g))
            if (escolhidos.contains('${c.grupo}:${c.indice}')) c.dados,
        ],
      },
  ];
}
