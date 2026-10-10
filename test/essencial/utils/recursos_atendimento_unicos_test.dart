import 'package:app/src/essencial/utils/recursos_atendimento_unicos.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final tipo in ['comanda', 'mesa']) {
    final campo = tipo == 'mesa' ? 'mesas' : 'comandas';
    final ocupado = tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada';
    Map<String, dynamic> recurso(String id, String nome,
            {String? conta,
            bool fechamento = false,
            String? historico,
            String ativo = 'Sim'}) =>
        {
          'id': id,
          'nome': nome,
          'codigo': id,
          'ativo': ativo,
          ocupado: conta != null,
          if (conta != null) 'idComandaPedido': conta,
          'fechamento': fechamento,
          'valor': '25.00',
          if (historico != null) 'ultimaVezAbertoDataHora': historico
        };
    List<Map<String, dynamic>> lista(List<dynamic> livres,
            [List<dynamic> abertas = const []]) =>
        [
          {'titulo': 'Ocupadas', campo: abertas},
          {'titulo': 'Livres', campo: livres}
        ];
    List<Map> itens(List<Map<String, dynamic>> grupos) =>
        grupos.expand((g) => (g[campo] as List).cast<Map>()).toList();

    test('$tipo: dois IDs com mesmo nome preservam o cadastro com historico',
        () {
      final original = lista([
        recurso('11', 'Comanda: 1', historico: '2026-10-09T11:06:30.177769'),
        recurso('316', 'Comanda: 1'),
        recurso('12', 'Comanda: 2'),
        recurso('315', 'Comanda: 2'),
        recurso('13', 'Comanda: 3')
      ]);
      final normalizada = recursosAtendimentoUnicos(original, tipo);
      expect(itens(normalizada).map((r) => r['id']), ['11', '12', '13']);
      expect(itens(normalizada).first['ultimaVezAbertoDataHora'],
          '2026-10-09T11:06:30.177769');
      expect(itens(original), hasLength(5));
      expect(recursosAtendimentoUnicos(normalizada, tipo), normalizada);
    });
    test(
        '$tipo: livre duplicada nao substitui o ID, a conta ou o total de uma ocupada',
        () {
      final aberta = recurso('316', 'Comanda: 1', conta: '10866');
      final normalizada = recursosAtendimentoUnicos(
          lista([recurso('11', 'Comanda: 1'), recurso('12', 'Comanda: 2')],
              [aberta]),
          tipo);
      expect(normalizada.first[campo], [aberta]);
      expect(normalizada.last[campo], [recurso('12', 'Comanda: 2')]);
      expect(itens(normalizada), hasLength(2));
    });
    test(
        '$tipo: contas abertas distintas continuam acessiveis mesmo com nome repetido',
        () {
      final abertas = [
        recurso('11', '1', conta: '100'),
        recurso('316', '1', conta: '200', fechamento: true)
      ];
      final normalizada =
          recursosAtendimentoUnicos(lista([recurso('12', '1')], abertas), tipo);
      expect(
          itens(normalizada).map((r) => r['idComandaPedido']), ['100', '200']);
    });
    test('$tipo: conta repetida entre grupos fica somente em fechamento', () {
      final normalizada = recursosAtendimentoUnicos([
        {
          'titulo': 'Ocupadas',
          campo: [recurso('11', '1', conta: '100')]
        },
        {
          'titulo': 'em Fechamento',
          campo: [recurso('11', '1', conta: '100', fechamento: true)]
        },
        {
          'titulo': 'Livres',
          campo: [recurso('11', '1')]
        },
      ], tipo);
      expect(normalizada[0][campo], isEmpty);
      expect(normalizada[1][campo], hasLength(1));
      expect(normalizada[2][campo], isEmpty);
    });
    test(
        '$tipo: nomes normalizados, ativos e IDs distintos sem nome nao se confundem',
        () {
      final normalizada = recursosAtendimentoUnicos(
          lista([
            recurso('10', ' Mesa:  4 ', ativo: 'Não'),
            recurso('20', 'mesa: 4'),
            recurso('30', '', ativo: 'Sim'),
            recurso('31', ''),
          ]),
          tipo);
      expect(itens(normalizada).map((r) => r['id']), ['20', '30', '31']);
    });
  }
}
