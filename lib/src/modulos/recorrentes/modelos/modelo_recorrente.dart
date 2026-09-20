import 'package:intl/intl.dart';

class ConfiguracaoRecorrencia {
  final List<int> dias;
  final String horarioTipo;
  final String horario;
  final String horarioFim;

  const ConfiguracaoRecorrencia({
    this.dias = const [1, 2, 3, 4, 5],
    this.horarioTipo = 'livre',
    this.horario = '12:00',
    this.horarioFim = '14:00',
  });

  static const nomesDias = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  ConfiguracaoRecorrencia copyWith(
          {List<int>? dias,
          String? horarioTipo,
          String? horario,
          String? horarioFim}) =>
      ConfiguracaoRecorrencia(
        dias: dias ?? this.dias,
        horarioTipo: horarioTipo ?? this.horarioTipo,
        horario: horario ?? this.horario,
        horarioFim: horarioFim ?? this.horarioFim,
      );

  String? get erro {
    if (dias.isEmpty || dias.any((d) => d < 1 || d > 7)) {
      return 'Selecione os dias da semana.';
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
    return null;
  }

  String get diasTexto => dias.length == 7
      ? 'Todos os dias'
      : ([...dias]..sort()).map((d) => nomesDias[d - 1]).join(' · ');
  String get horarioTexto => horarioTipo == 'livre'
      ? 'Qualquer horário'
      : horarioTipo == 'intervalo'
          ? '$horario–$horarioFim'
          : 'Às $horario';

  Map<String, dynamic> toMap() => {
        'dias': [...dias]..sort(),
        'horarioTipo': horarioTipo,
        'horario': horario,
        'horarioFim': horarioFim
      };

  factory ConfiguracaoRecorrencia.fromMap(Map<String, dynamic> json) =>
      ConfiguracaoRecorrencia(
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
  const ItemRecorrente(this.nome, this.quantidade);
  String get texto =>
      '${NumberFormat('0.###', 'pt_BR').format(quantidade)} × $nome';
}

class ModeloRecorrente {
  final String endereco;
  final String id,
      cliente,
      idCliente,
      idDelivery,
      idDeliveryBase,
      tipoEntrega,
      status,
      numeroPedido,
      observacao;
  final DateTime data;
  final ConfiguracaoRecorrencia configuracao;
  final bool ativo, pago;
  final double total;
  final List<ItemRecorrente> itens;

  ModeloRecorrente.fromMap(Map<String, dynamic> json)
      : endereco = '${json['endereco'] ?? ''}',
        id = '${json['id']}',
        cliente = '${json['cliente']}',
        idCliente = '${json['idCliente']}',
        idDelivery = '${json['idDelivery'] ?? ''}',
        idDeliveryBase = '${json['idDeliveryBase']}',
        tipoEntrega = '${json['tipoEntrega']}',
        status = '${json['status']}',
        numeroPedido = '${json['numeroPedido'] ?? ''}',
        observacao = '${json['observacao'] ?? ''}',
        data = DateTime.parse('${json['data']}'),
        configuracao = ConfiguracaoRecorrencia.fromMap(json),
        ativo = json['ativo'] == 'Sim',
        pago = json['pago'] == 'Sim',
        total = double.tryParse('${json['total']}') ?? 0,
        itens = (json['itens'] as List)
            .map((i) =>
                ItemRecorrente('${i['nome']}', num.parse('${i['quantidade']}')))
            .toList();

  String get chave => '$id:${DateFormat('yyyy-MM-dd').format(data)}';
  String get entregaTexto => tipoEntrega == '2' ? 'Retirada' : 'Entrega';
  bool get temPedido => idDelivery.isNotEmpty && idDelivery != '0';
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
      ].contains(status);
  bool disponivelEm(DateTime hoje) =>
      !data.isAfter(DateTime(hoje.year, hoje.month, hoje.day));
}
