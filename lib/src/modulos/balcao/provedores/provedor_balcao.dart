import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
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
  String? erro;
  int _consulta = 0;
  String _pesquisaAtual = '';
  String get pesquisaAtual => _pesquisaAtual;
  String observacaoDoPedido = '';

  DateTimeRange _dataSelecionada =
      DateTimeRange(start: DateTime.now(), end: DateTime.now());
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

  final _atualizacao = AtualizacaoAgrupada();

  Future<void> listar(
      {int? pagina,
      int? linhasPorPagina,
      String? pesquisa,
      bool resetar = false,
      bool mostrarCarregamento = false}) async {
    final consulta = ++_consulta;
    if (pesquisa != null) _pesquisaAtual = pesquisa.trim();

    if (resetar) {
      paginaSelecionada = 1;
      temMaisParaCarregar = true;
    }

    await _atualizacao.executar(() async {
      if (mostrarCarregamento && dados.isEmpty) {
        listando = true;
        notifyListeners();
      }
      erro = null;

      var dataInicio = DateFormat('yyyy-MM-dd').format(dataSelecionada.start);
      var dataFim = DateFormat('yyyy-MM-dd').format(dataSelecionada.end);
      var hora =
          "${horaSelecionado.hour < 10 ? '0${horaSelecionado.hour}' : horaSelecionado.hour}:${horaSelecionado.minute < 10 ? '0${horaSelecionado.minute}' : horaSelecionado.minute}:00";

      try {
        final limite = linhasPorPagina ?? maximoItensSelecionado;
        final novosItens = await _servico.listar(pagina ?? paginaSelecionada,
            limite, _pesquisaAtual, dataInicio, dataFim, hora);
        if (consulta != _consulta) return;
        dados = novosItens;
        temMaisParaCarregar = novosItens.length >= limite;
      } catch (_) {
        if (consulta != _consulta) return;
        erro = 'Não foi possível atualizar as vendas.';
      } finally {
        if (consulta == _consulta) {
          listando = false;
          notifyListeners();
        }
      }
    });
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _servico.listarClientes(pesquisa);
  }

  Future<List<Modelowordenderecosclientes>> listarEnderecosClientes(
      String pesquisa, String idCliente) async {
    return await _servico.listarEnderecosClientes(pesquisa, idCliente);
  }

  Future<({bool sucesso, String idvenda})> inserir(
      String idCliente, String obs) async {
    final res = await _servico.inserir(idCliente, obs);
    if (res.sucesso) {
      listar();
    }
    return res;
  }

  @override
  void dispose() {
    ++_consulta;
    _atualizacao.dispose();
    super.dispose();
  }
}
