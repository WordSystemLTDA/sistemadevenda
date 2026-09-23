import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _grupo({
  String dia = '2026-09-22',
  int? hora = 12,
  String canal = 'Comanda',
  String status = 'Andamento',
  int quantidade = 1,
  int consumo = 4500,
}) =>
    {
      'dia': dia,
      'hora': hora,
      'canal': canal,
      'status': status,
      'quantidade': quantidade,
      'consumo_centavos': consumo,
    };

Map<String, dynamic> _relatorio({
  List<Map<String, dynamic>> grupos = const [],
  String inicio = '2026-09-22',
  String fim = '2026-09-22',
}) =>
    {
      'versao': 1,
      'inicio': inicio,
      'fim': fim,
      'atualizado_em': '2026-09-22T21:00:00',
      'grupos': grupos,
    };

void main() {
  test('resposta antiga continua válida sem metas ou comparação inventadas',
      () {
    final modelo = ModeloIndicadores.fromMap(_relatorio());

    expect(modelo.escopo, 'empresa');
    expect(modelo.pessoal, isFalse);
    expect(modelo.suporteMetas, isFalse);
    expect(modelo.metas, isNull);
    expect(modelo.comparacao, isNull);
    expect(modelo.resumirComparacao(CanalIndicadores.todos), isNull);
    expect(modelo.produtos, isEmpty);
  });

  test('ticket e cancelamento usam denominadores distintos e valores reais',
      () {
    final resumo = ModeloIndicadores.fromMap(_relatorio(grupos: [
      _grupo(quantidade: 3, consumo: 10000),
      _grupo(status: 'Cancelada', quantidade: 2, consumo: 45000),
    ])).resumir(CanalIndicadores.todos);

    expect(resumo.quantidade, 3);
    expect(resumo.consumoCentavos, 10000);
    expect(resumo.ticketMedioCentavos, 3333);
    expect(resumo.totalAtendimentos, 5);
    expect(resumo.taxaCancelamento, 40);
  });

  test('sem atendimento não produz divisão por zero nem pico fictício', () {
    final resumo =
        ModeloIndicadores.fromMap(_relatorio()).resumir(CanalIndicadores.todos);

    expect(resumo.ticketMedioCentavos, 0);
    expect(resumo.taxaCancelamento, 0);
    expect(resumo.finalizados, 0);
    expect(resumo.pico, isNull);
    expect(resumo.porHoraOperacional.length, 24);
    expect(resumo.porDia.single.consumoCentavos, 0);
  });

  test('status equivalentes são normalizados sem contar cancelados concluídos',
      () {
    final resumo = ModeloIndicadores.fromMap(_relatorio(grupos: [
      _grupo(status: 'Finalizada'),
      _grupo(status: 'FINALIZADO'),
      _grupo(status: ' Concluída '),
      _grupo(status: 'Concluído'),
      _grupo(status: 'Fechada'),
      _grupo(status: 'Encerrado'),
      _grupo(status: ' CANCELADO ', quantidade: 2, consumo: 8000),
      _grupo(status: 'Fechamento'),
      _grupo(status: 'Andamento'),
    ])).resumir(CanalIndicadores.todos);

    expect(resumo.finalizados, 6);
    expect(resumo.cancelados, 2);
    expect(resumo.emAndamento, 1);
    expect(resumo.emFechamento, 1);
    expect(resumo.quantidade, 8);
  });

  test('horas seguem o dia operacional preservando o horário real do ponto',
      () {
    final resumo = ModeloIndicadores.fromMap(_relatorio(grupos: [
      _grupo(hora: 5, quantidade: 2, consumo: 6000),
      _grupo(hora: 23, quantidade: 3, consumo: 11000),
      _grupo(hora: 2, quantidade: 1, consumo: 3200),
      _grupo(hora: 5, status: 'Cancelada', quantidade: 9, consumo: 99000),
      _grupo(hora: null, quantidade: 1, consumo: 1000),
    ])).resumir(CanalIndicadores.todos);

    final horas = resumo.porHoraOperacional;
    expect(horas.map((p) => p.posicao), [
      5,
      6,
      7,
      8,
      9,
      10,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19,
      20,
      21,
      22,
      23,
      0,
      1,
      2,
      3,
      4,
    ]);
    expect(horas.first.quantidade, 2);
    expect(horas.first.consumoCentavos, 6000);
    expect(horas[21].consumoCentavos, 3200);
    expect(resumo.porHora.first.posicao, 0);
    expect(resumo.pico?.posicao, 23);
    expect(horas.fold<int>(0, (total, p) => total + p.quantidade), 6);
    // Registros sem horário participam dos totais, mas não de um horário fictício.
    expect(resumo.quantidade, 7);
    expect(resumo.consumoCentavos, 21200);
  });

  test('evolução diária completa lacunas e mantém filtro do canal', () {
    final modelo = ModeloIndicadores.fromMap(_relatorio(
      inicio: '2026-09-20',
      grupos: [
        _grupo(dia: '2026-09-20', consumo: 10000),
        _grupo(canal: 'Mesa', quantidade: 2, consumo: 25000),
        _grupo(consumo: 7000),
        _grupo(status: 'Cancelada', consumo: 10000),
      ],
    ));
    final resumo = modelo.resumir(CanalIndicadores.comanda);

    expect(resumo.diasNoPeriodo, 3);
    expect(resumo.porDia.map((p) => p.quantidade), [1, 0, 1]);
    expect(resumo.porDia.map((p) => p.consumoCentavos), [10000, 0, 7000]);
    expect(modelo.resumir(CanalIndicadores.mesa).ticketMedioCentavos, 12500);
  });

  test('comparação opcional herda metadados e mantém canais separados', () {
    final modelo = ModeloIndicadores.fromMap({
      ..._relatorio(grupos: [_grupo(consumo: 9000)]),
      'escopo': 'pessoal',
      'criterio_pessoal': 'Pedidos abertos por você.',
      'comparacao': {
        'inicio': '2026-09-21',
        'fim': '2026-09-21',
        'grupos': [
          _grupo(dia: '2026-09-21', consumo: 6000),
          _grupo(dia: '2026-09-21', canal: 'Mesa', consumo: 10000),
        ],
      },
    }, offline: true);
    final anterior = modelo.resumirComparacao(CanalIndicadores.comanda)!;

    expect(modelo.pessoal, isTrue);
    expect(modelo.criterioPessoal, 'Pedidos abertos por você.');
    expect(modelo.comparacao!.atualizadoEm, modelo.atualizadoEm);
    expect(modelo.comparacao!.offline, isTrue);
    expect(modelo.comparacao!.pessoal, isTrue);
    expect(anterior.consumoCentavos, 6000);
    expect(variacaoPercentualIndicadores(9000, anterior.consumoCentavos), 50);
  });

  test('variação não inventa crescimento sem uma base comparável', () {
    expect(variacaoPercentualIndicadores(15000, 0), isNull);
    expect(variacaoPercentualIndicadores(0, 0), isNull);
    expect(variacaoPercentualIndicadores(200, -10), isNull);
    expect(variacaoPercentualIndicadores(double.infinity, 10), isNull);
    expect(variacaoPercentualIndicadores(7500, 10000), -25);
    expect(variacaoPercentualIndicadores(0, 10000), -100);
    expect(variacaoPercentualIndicadores(10000, 10000), 0);
  });

  test('metas são opcionais, convertidas sem perda e escaladas por dias civis',
      () {
    final modelo = ModeloIndicadores.fromMap({
      ..._relatorio(inicio: '2026-09-20'),
      'suporte_metas': true,
      'metas': {
        'consumo_diario_centavos': 100000,
        'atendimentos_diarios': 20,
        'ticket_medio_centavos': 5000,
      },
    });
    final metas = modelo.metas!;

    expect(modelo.suporteMetas, isTrue);
    expect(metas.configuradas, isTrue);
    expect(metas.consumoDiarioCentavos * modelo.diasNoPeriodo, 300000);
    expect(metas.atendimentosDiarios * modelo.diasNoPeriodo, 60);
    // Ticket é uma média e sua meta não se multiplica pelo número de dias.
    expect(metas.ticketMedioCentavos, 5000);
    expect(MetasIndicadores.fromMap(metas.toMap()).toMap(), metas.toMap());
    expect(const MetasIndicadores().configuradas, isFalse);
    expect(() => MetasIndicadores.fromMap({'atendimentos_diarios': -1}),
        throwsFormatException);
  });

  test('produtos aceitam peso fracionado e respeitam o canal selecionado', () {
    final modelo = ModeloIndicadores.fromMap({
      ..._relatorio(),
      'produtos': [
        {
          'id': 200,
          'nome': 'Almoço por KG',
          'canal': 'Comanda',
          'quantidade': 0.2,
          'consumo_centavos': 900,
        },
        {
          'id': '151',
          'nome': 'Almoço Livre',
          'canal': 'Mesa',
          'quantidade': 2,
          'consumo_centavos': 9000,
        },
      ],
    });

    expect(modelo.produtosDoCanal(CanalIndicadores.todos).length, 2);
    final pesado = modelo.produtosDoCanal(CanalIndicadores.comanda).single;
    expect(pesado.id, '200');
    expect(pesado.quantidade, 0.2);
    expect(pesado.consumoCentavos, 900);
    expect(modelo.produtosDoCanal(CanalIndicadores.balcao), isEmpty);
  });
}
