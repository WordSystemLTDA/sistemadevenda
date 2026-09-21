import 'package:intl/intl.dart';

class ConfiguracaoRecorrencia {
  final List<int> dias;
  final String horarioTipo;
  final String horario;
  final String horarioFim;
  final String pagamentoModo;
  final int diaVencimento;

  const ConfiguracaoRecorrencia({
    this.dias = const [1, 2, 3, 4, 5],
    this.horarioTipo = '',
    this.horario = '12:00',
    this.horarioFim = '14:00',
    this.pagamentoModo = '',
    this.diaVencimento = 10,
  });

  static const nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  ConfiguracaoRecorrencia copyWith(
          {List<int>? dias,
          String? horarioTipo,
          String? horario,
          String? horarioFim,
          String? pagamentoModo,
          int? diaVencimento}) =>
      ConfiguracaoRecorrencia(
        dias: dias ?? this.dias,
        horarioTipo: horarioTipo ?? this.horarioTipo,
        horario: horario ?? this.horario,
        horarioFim: horarioFim ?? this.horarioFim,
        pagamentoModo: pagamentoModo ?? this.pagamentoModo,
        diaVencimento: diaVencimento ?? this.diaVencimento,
      );

  String? get erro {
    if (dias.isEmpty || dias.any((d) => d < 1 || d > 7)) {
      return 'Selecione os dias da semana.';
    }
    if (!['livre', 'fixo', 'intervalo'].contains(horarioTipo)) {
      return 'Selecione uma opção de horário.';
    }
    final horaValida = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
    if (horarioTipo != 'livre' && !horaValida.hasMatch(horario)) {
      return 'Informe o horário.';
    }
    if (horarioTipo == 'intervalo' &&
        (!horaValida.hasMatch(horarioFim) ||
            horarioFim.compareTo(horario) <= 0)) {
      return 'O horário final deve ser depois do inicial.';
    }
    if (!['diario', 'mensal'].contains(pagamentoModo)) {
      return 'Selecione como o cliente paga.';
    }
    if (pagamentoModo == 'mensal' &&
        (diaVencimento < 1 || diaVencimento > 31)) {
      return 'Escolha um dia de 1 a 31 para o acerto.';
    }
    return null;
  }

  String get diasTexto => dias.length == 7
      ? 'Todos os dias'
      : ([...dias]..sort()).map((d) => nomesDias[d - 1]).join(' · ');
  String get horarioTexto => horarioTipo.isEmpty
      ? 'Horário não selecionado'
      : horarioTipo == 'livre'
          ? 'Qualquer horário'
          : horarioTipo == 'intervalo'
              ? '$horario–$horarioFim'
              : 'Às $horario';

  bool get pagamentoMensal => pagamentoModo == 'mensal';
  String get pagamentoTexto => pagamentoModo.isEmpty
      ? 'Pagamento não selecionado'
      : pagamentoMensal
          ? 'Em conta · dia $diaVencimento do mês seguinte'
          : 'Pagamento a cada pedido';

  DateTime vencimentoEm(DateTime dataPedido) {
    if (!pagamentoMensal) {
      return DateTime(dataPedido.year, dataPedido.month, dataPedido.day);
    }
    final ultimoDia = DateTime(dataPedido.year, dataPedido.month + 2, 0).day;
    return DateTime(dataPedido.year, dataPedido.month + 1,
        diaVencimento.clamp(1, ultimoDia));
  }

  Map<String, dynamic> toMap() => {
        'dias': [...dias]..sort(),
        'horarioTipo': horarioTipo,
        'horario': horario,
        'horarioFim': horarioFim,
        'pagamentoModo': pagamentoModo,
        'diaVencimento': diaVencimento,
      };

  factory ConfiguracaoRecorrencia.fromMap(Map<String, dynamic> json) =>
      ConfiguracaoRecorrencia(
        pagamentoModo: '${json['pagamentoModo'] ?? 'diario'}',
        diaVencimento: int.tryParse('${json['diaVencimento']}') ?? 10,
        dias: (json['dias'] as List).map((d) => int.parse('$d')).toList(),
        horarioTipo: '${json['horarioTipo'] ?? 'livre'}',
        horario: (json['horario']?.toString().isNotEmpty ?? false)
            ? '${json['horario']}'
            : '12:00',
        horarioFim: (json['horarioFim']?.toString().isNotEmpty ?? false)
            ? '${json['horarioFim']}'
            : '14:00',
      );
}

class ItemRecorrente {
  final String nome;
  final num quantidade;
  final List<String> detalhes;
  const ItemRecorrente(this.nome, this.quantidade, {this.detalhes = const []});
  String get texto =>
      '${NumberFormat('0.###', 'pt_BR').format(quantidade)} × $nome';

  factory ItemRecorrente.fromMap(Map<String, dynamic> json) => ItemRecorrente(
        '${json['nome'] ?? ''}',
        num.tryParse('${json['quantidade']}') ?? 0,
        detalhes: json['detalhes'] is List
            ? (json['detalhes'] as List)
                .map((detalhe) => '$detalhe'.trim())
                .where((detalhe) => detalhe.isNotEmpty)
                .toList(growable: false)
            : const [],
      );
}

class ModeloRecorrente {
  final PagamentoRecorrente pagamento;
  final String endereco;
  final String id,
      cliente,
      idCliente,
      idDelivery,
      idDeliveryBase,
      tipoEntrega,
      status,
      statusDelivery,
      numeroPedido,
      observacao;
  final DateTime data;
  final ConfiguracaoRecorrencia configuracao;
  final bool ativo, pago;
  final double total;
  final List<ItemRecorrente> itens;

  ModeloRecorrente.fromMap(Map<String, dynamic> json)
      : pagamento = PagamentoRecorrente.fromMap(json),
        endereco = '${json['endereco'] ?? ''}',
        id = '${json['id']}',
        cliente = '${json['cliente']}',
        idCliente = '${json['idCliente']}',
        idDelivery = '${json['idDelivery'] ?? ''}',
        idDeliveryBase = '${json['idDeliveryBase']}',
        tipoEntrega = '${json['tipoEntrega']}',
        status = '${json['status']}',
        statusDelivery = '${json['statusDelivery'] ?? json['status'] ?? ''}',
        numeroPedido = '${json['numeroPedido'] ?? ''}',
        observacao = '${json['observacao'] ?? ''}',
        data = DateTime.parse('${json['data']}'),
        configuracao = ConfiguracaoRecorrencia.fromMap(json),
        ativo = json['ativo'] == 'Sim',
        pago = json['pago'] == 'Sim',
        total = double.tryParse('${json['total']}') ?? 0,
        itens = (json['itens'] as List)
            .map((i) =>
                ItemRecorrente.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList();

  String get chave => '$id:${DateFormat('yyyy-MM-dd').format(data)}';
  String get entregaTexto => tipoEntrega == '2' ? 'Retirada' : 'Entrega';
  bool get temPedido => idDelivery.isNotEmpty && idDelivery != '0';
  bool get processoCancelado =>
      ['cancelado', 'cancelada', 'processo cancelado']
          .contains(status.toLowerCase()) ||
      ['cancelado', 'cancelada'].contains(statusDelivery.toLowerCase());
  bool get processoFeito => temPedido && !processoCancelado;
  String get statusProcesso => processoCancelado
      ? 'Processo Cancelado'
      : processoFeito
          ? 'Processo Feito'
          : status;
  bool get encerrado =>
      pago ||
      [
        'Finalizado',
        'Finalizada',
        'Cancelado',
        'Cancelada',
        'Entregue',
        'Concluído',
        'Concluido'
      ].contains(statusDelivery);
  bool disponivelEm(DateTime hoje) =>
      !data.isAfter(DateTime(hoje.year, hoje.month, hoje.day));
}

class PagamentoRecorrente {
  final bool recorrente, definida;
  final String modo, nome;
  final int forma, diaVencimento;
  final DateTime? vencimento;

  PagamentoRecorrente.fromMap(Map<String, dynamic> json)
      : recorrente = json['recorrente'] != false,
        modo = '${json['pagamentoModo'] ?? 'diario'}',
        diaVencimento = int.tryParse('${json['diaVencimento']}') ?? 10,
        definida = (json['pagamentoPadrao'] as Map?)?['definida'] == true,
        forma = int.tryParse(
                '${(json['pagamentoPadrao'] as Map?)?['formaPagamento']}') ??
            0,
        nome = '${(json['pagamentoPadrao'] as Map?)?['nome'] ?? ''}',
        vencimento = DateTime.tryParse(
            '${(json['pagamentoPadrao'] as Map?)?['vencimento'] ?? ''}');

  bool get mensal => modo == 'mensal';
  String get resumo => mensal
      ? 'Em conta · dia $diaVencimento do próximo mês'
      : definida
          ? '$nome · a cada pedido'
          : 'Pagamento definido no primeiro pedido';
}
