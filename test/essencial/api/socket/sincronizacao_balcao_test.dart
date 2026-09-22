import 'dart:async';

import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';

class _Servico extends Fake implements ServicoBalcao {
  final pesquisas = <String>[];
  final respostas = <Completer<List<ModeloVendasBalcao>>>[];

  @override
  Future<List<ModeloVendasBalcao>> listar(int pagina, int limite,
      String pesquisa, String inicio, String fim, String hora) {
    pesquisas.add(pesquisa);
    final resposta = Completer<List<ModeloVendasBalcao>>();
    respostas.add(resposta);
    return resposta.future;
  }
}

class _Venda extends Fake implements ModeloVendasBalcao {}

class _Modulo extends Module {
  _Modulo(this.provedor);
  final ProvedorBalcao provedor;
  @override
  void binds(Injector i) => i.addInstance<ProvedorBalcao>(provedor);
}

void main() {
  test('evento Balcao sem acento tambem atualiza o atendimento', () async {
    final servico = _Servico();
    final provedor = ProvedorBalcao(servico);
    Modular.init(_Modulo(provedor));
    addTearDown(Modular.destroy);
    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: 'balcao'));
    expect(servico.pesquisas, ['']);
    servico.respostas.single.complete([]);
    await Future<void>.delayed(Duration.zero);
  });
  test('evento durante pesquisa mantem filtro novo e ignora resposta anterior',
      () async {
    final servico = _Servico();
    final provedor = ProvedorBalcao(servico);
    addTearDown(provedor.dispose);
    final respostasVisiveis = <List<ModeloVendasBalcao>>[];
    provedor.addListener(() => respostasVisiveis.add([...provedor.dados]));
    final primeira = provedor.listar(pesquisa: 'arroz');
    final pesquisa = provedor.listar(pesquisa: 'feijao');
    final evento = provedor.listar();
    expect(servico.pesquisas, ['arroz']);
    final antiga = _Venda();
    servico.respostas.first.complete([antiga]);
    await Future<void>.delayed(Duration.zero);
    expect(servico.pesquisas, ['arroz', 'feijao']);
    expect(respostasVisiveis.any((itens) => itens.contains(antiga)), isFalse);
    final atual = _Venda();
    servico.respostas.last.complete([atual]);
    await Future.wait([primeira, pesquisa, evento]);
    expect(provedor.dados, [atual]);
  });

  test('falha nao apaga os pedidos e a proxima tentativa recupera', () async {
    final servico = _Servico();
    final provedor = ProvedorBalcao(servico);
    addTearDown(provedor.dispose);
    final venda = _Venda();
    provedor.dados = [venda];
    final falha = provedor.listar();
    servico.respostas.last.completeError(StateError('offline'));
    await falha;
    expect(provedor.dados, [venda]);
    final recuperacao = provedor.listar();
    servico.respostas.last.complete([]);
    await recuperacao;
    expect(provedor.dados, isEmpty);
  });
}
