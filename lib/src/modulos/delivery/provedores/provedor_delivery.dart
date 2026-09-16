import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';

class ProvedorDelivery extends ChangeNotifier {
  final ServicoDelivery servico;
  ProvedorDelivery(this.servico);

  List<EtapaDelivery> etapas = [];
  ConfigDelivery? config;
  bool carregando = false;
  String? erro;
  String pesquisa = '',
      tipo = '0',
      horaInicio = '05:00:00',
      horaFim = '05:00:00';
  DateTimeRange periodo =
      DateTimeRange(start: DateTime.now(), end: DateTime.now());
  int _consulta = 0;
  bool _descartado = false;

  Future<void> listar() async {
    final consulta = ++_consulta;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final respostas = await Future.wait([
        servico.listar(
            inicio: periodo.start,
            fim: periodo.end,
            horaInicio: horaInicio,
            horaFim: horaFim,
            pesquisa: pesquisa,
            tipo: tipo),
        servico.configuracao(),
      ]);
      if (_descartado || consulta != _consulta) return;
      etapas = respostas[0] as List<EtapaDelivery>;
      config = respostas[1] as ConfigDelivery;
    } catch (_) {
      if (_descartado || consulta != _consulta) return;
      erro =
          'Não foi possível atualizar o Delivery. Verifique a conexão e tente novamente.';
    } finally {
      if (!_descartado && consulta == _consulta) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
