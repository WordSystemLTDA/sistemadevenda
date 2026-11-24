import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comandas.dart';

void main() {
  const pasta = String.fromEnvironment('CARGA_PAINEL_DIR');
  for (final tipo in ['mesas', 'comandas']) {
    test('contrato real do painel mobile: $tipo em alto fluxo', () {
      final resultado =
          jsonDecode(File('$pasta/resultado.json').readAsStringSync());
      final quantidade = resultado['cenario'][tipo] as int;
      final itens = resultado['cenario']['itens_por_conta'] as int;
      final grupos =
          jsonDecode(File('$pasta/app_${tipo}_inicial.json').readAsStringSync())
              as List;
      final contas = <({String id, String? atendimento, String? valor})>[];
      for (final grupo in grupos) {
        if (tipo == 'mesas') {
          contas.addAll(MesasModel.fromMap(Map<String, dynamic>.from(grupo))
              .mesas!
              .map((m) =>
                  (id: m.id, atendimento: m.idComandaPedido, valor: m.valor)));
        } else {
          contas.addAll(ModeloComandas.fromMap(Map<String, dynamic>.from(grupo))
              .comandas!
              .map((c) =>
                  (id: c.id, atendimento: c.idComandaPedido, valor: c.valor)));
        }
      }
      final carga = contas.where((c) => int.parse(c.id) >= 1000).toList();
      expect(carga, hasLength(quantidade));
      expect(carga.map((c) => c.atendimento).toSet(), hasLength(quantidade));
      for (final conta in carga) {
        final indice = int.parse(conta.id) - 1000;
        expect(conta.atendimento,
            '${(tipo == 'mesas' ? 100000 : 200000) + indice}');
        final centavos =
            List.generate(itens, (j) => ((indice + j) % 16 + 1) * 25)
                .fold<int>(0, (a, b) => a + b);
        expect((double.parse(conta.valor!) * 100).round(), centavos);
      }
    },
        skip: pasta.isEmpty
            ? 'Execute o runner HTTP e informe --dart-define=CARGA_PAINEL_DIR=...'
            : false);
  }
}
