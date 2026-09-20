import 'package:flutter/foundation.dart';
import '../modelos/modelo_recorrente.dart';
import '../servicos/servicos_recorrentes.dart';

class ProvedorRecorrentes extends ChangeNotifier {
  final ServicosRecorrentes servico;
  ProvedorRecorrentes(this.servico);
  List<ModeloRecorrente> itens = [];
  DateTime data = DateUtilsRecorrentes.hoje();
  String visao = 'semana';
  String pesquisa = '';
  String? erro;
  bool carregando = false;
  bool ocupado = false;
  bool _descartado = false;
  int _consulta = 0;
  List<ModeloRecorrente> get filtrados => itens
      .where((r) =>
          '${r.cliente} ${r.observacao} ${r.itens.map((i) => i.nome).join(' ')}'
              .toLowerCase()
              .contains(pesquisa.toLowerCase().trim()))
      .toList();

  void pesquisar(String valor) {
    pesquisa = valor;
    notifyListeners();
  }

  Future<void> listar({DateTime? dia, String? modo}) async {
    data = dia ?? data;
    visao = modo ?? visao;
    final consulta = ++_consulta;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      final lista = await servico.listar(
          data,
          data.add(Duration(
              days: visao == 'mes'
                  ? 29
                  : visao == 'semana'
                      ? 6
                      : 0)),
          cadastros: visao == 'cadastros');
      if (_descartado || consulta != _consulta) return;
      itens = lista;
    } catch (e) {
      if (_descartado || consulta != _consulta) return;
      erro = e is StateError
          ? e.message.toString()
          : 'Não foi possível carregar a agenda.';
      itens = [];
    } finally {
      if (!_descartado && consulta == _consulta) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  Future<T?> executar<T>(Future<T> Function() acao) async {
    if (ocupado) return null;
    ocupado = true;
    notifyListeners();
    try {
      return await acao();
    } finally {
      if (!_descartado) {
        ocupado = false;
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

abstract final class DateUtilsRecorrentes {
  static DateTime hoje() {
    final agora = DateTime.now();
    return DateTime(agora.year, agora.month, agora.day);
  }
}
