import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/sincronizacao/impressoes_aguardando_pedido.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, Object?> operacao(String estado, Object? mensagens) => {
        'estado': estado,
        'impressoes': jsonEncode(mensagens),
        'destino': '192.168.2.113:9990',
      };

  Map<String, Object?> comprovante(String id, {String empresa = '34'}) => {
        'idRequisicao': id,
        'idEmpresa': empresa,
        'tipoImpressao': '1',
      };

  test('conferencia nao altera dados, ignora incompletos e respeita empresa',
      () {
    final op = operacao('pendente', [
      jsonEncode(comprovante('local')),
      jsonEncode(comprovante('local')),
      jsonEncode(comprovante('legado', empresa: '')),
      jsonEncode(comprovante('outra', empresa: '81')),
      '{quebrado',
      5,
    ]);
    final original = jsonEncode(op);
    final itens = impressoesAguardandoPedido([
      op,
      operacao('concluido', [comprovante('concluido')]),
      operacao('arquivado', [comprovante('arquivado')]),
      {'estado': 'pendente', 'impressoes': '[quebrado'},
    ], empresa: '34');
    expect(itens.map((i) => i.id), ['local', 'legado']);
    expect(itens.map((i) => i.estado),
        everyElement(EstadoImpressao.aguardandoPedido));
    expect(itens.last.dados['idEmpresa'], '34');
    expect(jsonEncode(op), original);
  });

  test('conflito exige conferencia e nao mistura canais Local e Online', () {
    const escopo = 'online|bigchef.com.br|34';
    final online = {
      ...comprovante('online'),
      'escopoAtualizacao': escopo,
    };
    final conflito = operacao('conflito', [comprovante('conflito')])
      ..['erro'] = 'Atendimento encerrado';
    final local = impressoesAguardandoPedido([
      conflito,
      operacao('pendente', [online]),
    ], empresa: '34');
    expect(local.single.id, 'conflito');
    expect(local.single.erro, contains('Atendimento encerrado'));
    final itensOnline = impressoesAguardandoPedido([
      operacao('pendente', [online]),
    ], empresa: '34', escopoOnline: escopo);
    expect(itensOnline.single.dados['escopoAtualizacao'], escopo);
    expect(impressoesAguardandoPedido([conflito], empresa: ''), isEmpty);
  });
}
