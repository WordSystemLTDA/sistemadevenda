import 'package:intl/intl.dart';

DateTime? _momentoRecorrente(
  Map<String, dynamic> json,
  String chave, {
  required int minutosAntes,
}) {
  final recebido = DateTime.tryParse('${json[chave] ?? ''}');
  if (recebido != null) return recebido;
  if (!['fixo', 'intervalo'].contains('${json['horarioTipo'] ?? 'livre'}')) {
    return null;
  }
  final data = DateTime.tryParse('${json['data'] ?? ''}');
  final partes = '${json['horario'] ?? ''}'.split(':');
  if (data == null || partes.length != 2) return null;
  final hora = int.tryParse(partes[0]);
  final minuto = int.tryParse(partes[1]);
  if (hora == null || minuto == null) return null;
  return DateTime(data.year, data.month, data.day, hora, minuto)
      .subtract(Duration(minutes: minutosAntes));
}

int _tempoEnvioRecorrente(Map<String, dynamic> json) {
  final valor = int.tryParse('${json['tempoParaEnvioDecorrente'] ?? 20}');
  return valor == null || valor < 0 ? 20 : valor;
}

Map<int, String> _enderecosPorDia(dynamic valor) {
  if (valor is! Map) return const {};
  return {
    for (final item in valor.entries)
      if ((int.tryParse('${item.key}') ?? 0) >= 1 &&
          (int.tryParse('${item.key}') ?? 0) <= 7 &&
          '${item.value}'.isNotEmpty)
        int.parse('${item.key}'): '${item.value}',
  };
}

class EnderecoRecorrente {
  final String id, endereco, numero, complemento, bairro, cidade, cep, padrao;

  const EnderecoRecorrente({
    required this.id,
    required this.endereco,
    required this.numero,
    this.complemento = '',
    this.bairro = '',
    this.cidade = '',
    this.cep = '',
    this.padrao = 'Não',
  });

  factory EnderecoRecorrente.fromMap(Map<String, dynamic> json) =>
      EnderecoRecorrente(
        id: '${json['id'] ?? ''}',
        endereco: '${json['endereco'] ?? ''}',
        numero: '${json['numero'] ?? ''}',
        complemento: '${json['complemento'] ?? ''}',
        bairro: '${json['bairro'] ?? ''}',
        cidade: '${json['cidade'] ?? ''}',
        cep: '${json['cep'] ?? ''}',
        padrao: '${json['padrao'] ?? 'Não'}',
      );

  String get titulo =>
      [endereco, numero].where((parte) => parte.trim().isNotEmpty).join(', ');
  String get detalhe => [bairro, cidade, complemento]
      .where((parte) => parte.trim().isNotEmpty)
      .join(' · ');
}

class ConfiguracaoRecorrencia {
  final List<int> dias;
  final String horarioTipo;
  final String horario;
  final String horarioFim;
  final String pagamentoModo;
  final int diaVencimento;
  final String enderecoModo;
  final Map<int, String> enderecosPorDia;

  const ConfiguracaoRecorrencia({
    this.dias = const [1, 2, 3, 4, 5],
    this.horarioTipo = '',
    this.horario = '12:00',
    this.horarioFim = '14:00',
    this.pagamentoModo = '',
    this.diaVencimento = 10,
    this.enderecoModo = 'padrao',
    this.enderecosPorDia = const {},
  });

  static const nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  ConfiguracaoRecorrencia copyWith(
          {List<int>? dias,
          String? horarioTipo,
          String? horario,
          String? horarioFim,
          String? pagamentoModo,
          int? diaVencimento,
          String? enderecoModo,
          Map<int, String>? enderecosPorDia}) =>
      ConfiguracaoRecorrencia(
        dias: dias ?? this.dias,
        horarioTipo: horarioTipo ?? this.horarioTipo,
        horario: horario ?? this.horario,
        horarioFim: horarioFim ?? this.horarioFim,
        pagamentoModo: pagamentoModo ?? this.pagamentoModo,
        diaVencimento: diaVencimento ?? this.diaVencimento,
        enderecoModo: enderecoModo ?? this.enderecoModo,
        enderecosPorDia: enderecosPorDia ?? this.enderecosPorDia,
      );

  String? get erro {
    if (dias.isEmpty || dias.any((d) => d < 1 || d > 7)) {
      return 'Selecione os dias da semana.';
    }
    if (!['padrao', 'por_dia'].contains(enderecoModo)) {
      return 'Selecione como usar os endereços.';
    }
    if (enderecoModo == 'por_dia' &&
        dias.any((dia) => (enderecosPorDia[dia] ?? '').isEmpty)) {
      return 'Escolha o endereço de todos os dias selecionados.';
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

  bool primeiroPedidoNoDiaSeguinte(DateTime agora) {
    if (!['fixo', 'intervalo'].contains(horarioTipo)) return false;
    final partes = horario.split(':');
    if (partes.length != 2) return false;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null ||
        minuto == null ||
        hora < 0 ||
        hora > 23 ||
        minuto < 0 ||
        minuto > 59) {
      return false;
    }
    final segundoAtual = agora.hour * 3600 + agora.minute * 60 + agora.second;
    final segundoProgramado = hora * 3600 + minuto * 60;
    return segundoAtual > segundoProgramado;
  }

  String textoPrimeiroPedido(DateTime agora) {
    return primeiroPedidoNoDiaSeguinte(agora)
        ? 'O horário de hoje já passou. O primeiro pedido será amanhã; os próximos seguem os dias escolhidos.'
        : 'O primeiro pedido é de hoje. Os próximos seguem os dias escolhidos.';
  }

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
        'enderecoModo': enderecoModo,
        'enderecosPorDia': {
          for (final item in enderecosPorDia.entries) '${item.key}': item.value
        },
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
        enderecoModo: '${json['enderecoModo'] ?? 'padrao'}',
        enderecosPorDia: _enderecosPorDia(json['enderecosPorDia']),
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
      idEnderecoBase,
      tipoEntrega,
      status,
      statusDelivery,
      numeroPedido,
      observacao;
  final DateTime data;
  final DateTime? dataHoraEntrega, dataHoraEnvio, dataHoraAlerta;
  final int tempoParaEnvioDecorrente;
  final ConfiguracaoRecorrencia configuracao;
  final bool ativo, pago;
  final double total;
  final List<ItemRecorrente> itens;
  final List<EnderecoRecorrente> enderecosDisponiveis;

  ModeloRecorrente.fromMap(Map<String, dynamic> json)
      : pagamento = PagamentoRecorrente.fromMap(json),
        endereco = '${json['endereco'] ?? ''}',
        id = '${json['id']}',
        cliente = '${json['cliente']}',
        idCliente = '${json['idCliente']}',
        idDelivery = '${json['idDelivery'] ?? ''}',
        idDeliveryBase = '${json['idDeliveryBase']}',
        idEnderecoBase = '${json['idEnderecoBase'] ?? ''}',
        tipoEntrega = '${json['tipoEntrega']}',
        status = '${json['status']}',
        statusDelivery = '${json['statusDelivery'] ?? json['status'] ?? ''}',
        numeroPedido = '${json['numeroPedido'] ?? ''}',
        observacao = '${json['observacao'] ?? ''}',
        data = DateTime.parse('${json['data']}'),
        tempoParaEnvioDecorrente = _tempoEnvioRecorrente(json),
        dataHoraEntrega = _momentoRecorrente(
          json,
          'dataHoraEntrega',
          minutosAntes: 0,
        ),
        dataHoraEnvio = _momentoRecorrente(
          json,
          'dataHoraEnvio',
          minutosAntes: _tempoEnvioRecorrente(json),
        ),
        dataHoraAlerta = _momentoRecorrente(
          json,
          'dataHoraAlerta',
          minutosAntes: _tempoEnvioRecorrente(json) + 10,
        ),
        configuracao = ConfiguracaoRecorrencia.fromMap(json),
        ativo = json['ativo'] == 'Sim',
        pago = json['pago'] == 'Sim',
        total = double.tryParse('${json['total']}') ?? 0,
        enderecosDisponiveis = json['enderecosDisponiveis'] is List
            ? (json['enderecosDisponiveis'] as List)
                .map((endereco) => EnderecoRecorrente.fromMap(
                    Map<String, dynamic>.from(endereco as Map)))
                .toList(growable: false)
            : const [],
        itens = (json['itens'] as List)
            .map((i) =>
                ItemRecorrente.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList();

  String get chave => '$id:${DateFormat('yyyy-MM-dd').format(data)}';
  String get entregaTexto => tipoEntrega == '2' ? 'Retirada' : 'Entrega';
  bool get possuiEnvioAutomatico => dataHoraEnvio != null;
  String get horarioEntregaTexto => configuracao.horarioTipo == 'intervalo'
      ? '${configuracao.horario}–${configuracao.horarioFim}'
      : _horarioOperacional(dataHoraEntrega);
  String get horarioEnvioTexto => _horarioOperacional(dataHoraEnvio);
  String get horarioAlertaTexto => _horarioOperacional(dataHoraAlerta);
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

  String _horarioOperacional(DateTime? momento) {
    if (momento == null) return '';
    final horario = DateFormat('HH:mm').format(momento);
    final dataDoCard = DateTime(data.year, data.month, data.day);
    final dataDoMomento = DateTime(momento.year, momento.month, momento.day);
    if (dataDoMomento.isBefore(dataDoCard)) return '$horario (dia anterior)';
    if (dataDoMomento.isAfter(dataDoCard)) return '$horario (dia seguinte)';
    return horario;
  }
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
