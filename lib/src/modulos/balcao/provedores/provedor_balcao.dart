import 'package:app/src/modulos/balcao/modelos/modelo_enderecos_clientes.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProvedorBalcao extends ChangeNotifier {
  final ServicoBalcao _servico;
  ProvedorBalcao(this._servico);

  List<ModeloVendasBalcao> dados = [];
  bool listando = false;
  bool temMaisParaCarregar = true;
  String observacaoDoPedido = '';

  DateTimeRange _dataSelecionada = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  DateTimeRange get dataSelecionada => _dataSelecionada;
  set dataSelecionada(DateTimeRange value) {
    _dataSelecionada = value;
    notifyListeners();
  }

  TimeOfDay _horaSelecionado = const TimeOfDay(hour: 5, minute: 0);
  TimeOfDay get horaSelecionado => _horaSelecionado;
  set horaSelecionado(TimeOfDay value) {
    _horaSelecionado = value;
    notifyListeners();
  }

  int linhasPorPagina = 30;
  int paginaSelecionada = 1;
  int maximoItensSelecionado = 30;

  Future<void> listar({int? pagina, int? linhasPorPagina, String pesquisa = '', bool resetar = false, bool mostrarCarregamento = false}) async {
    if (listando) return;

    if (resetar) {
      dados.clear();
      paginaSelecionada = 1;
      temMaisParaCarregar = true;
      notifyListeners();
    }

    if (mostrarCarregamento) {
      listando = true;
    }
    notifyListeners();

    var dataInicio = DateFormat('yyyy-MM-dd').format(dataSelecionada.start);
    var dataFim = DateFormat('yyyy-MM-dd').format(dataSelecionada.end);
    var hora =
        "${horaSelecionado.hour < 10 ? '0${horaSelecionado.hour}' : horaSelecionado.hour}:${horaSelecionado.minute < 10 ? '0${horaSelecionado.minute}' : horaSelecionado.minute}:00";

    var novosItens = await _servico.listar(pagina ?? paginaSelecionada, linhasPorPagina ?? maximoItensSelecionado, pesquisa, dataInicio, dataFim, hora);

    if (paginaSelecionada == 1) {
      dados.clear();
    }

    if (novosItens.length < 30) {
      temMaisParaCarregar = false;
      notifyListeners();
    }

    dados = novosItens;

    if (mostrarCarregamento) {
      listando = false;
    }
    notifyListeners();
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _servico.listarClientes(pesquisa);
  }

  Future<List<Modelowordenderecosclientes>> listarEnderecosClientes(String pesquisa, String idCliente) async {
    return await _servico.listarEnderecosClientes(pesquisa, idCliente);
  }

  Future<({bool sucesso, String idvenda})> inserir(String idCliente, String obs) async {
    final res = await _servico.inserir(idCliente, obs);
    if (res.sucesso) {
      listar();
    }
    return res;
  }
}
