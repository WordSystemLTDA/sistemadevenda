import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

Modelowordprodutos produto({
  String id = '100',
  String nome = 'Porcao inteira',
  String codigo = '003',
  String imprimirCodigo = 'Sim',
  String? computador,
}) =>
    Modelowordprodutos(
      id: id,
      nome: nome,
      codigo: codigo,
      imprimirCodigoProdutoPreparo: imprimirCodigo,
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '50',
      categoria: '34',
      nomeCategoria: 'Porcoes',
      habilTipo: '',
      ingredientes: [],
      quantidade: 1,
      destinoDeImpressao: computador == null
          ? null
          : ModeloDestinoImpressao(
              nome: computador,
              nomeDaImpressora: 'Impressora',
              tamanhoDoPapel: '48',
              nomedopc: computador,
            ),
    );

ModeloOpcoesPacotes saboresPizza() => ModeloOpcoesPacotes(
      id: 10,
      titulo: 'Sabores Pizza (2)',
      obrigatorio: false,
      dados: [
        ModeloDadosOpcoesPacotes(
          id: '101',
          nome: 'Calabresa',
          codigo: '7',
          imprimirCodigoProdutoPreparo: 'Sim',
          quantimaximaselecao: '1/2',
          valor: '25',
        ),
        ModeloDadosOpcoesPacotes(
          id: '102',
          nome: 'Chocolate',
          codigo: '28',
          quantimaximaselecao: '1/2',
          valor: '30',
        ),
      ],
    );

class ServidorTeste extends Fake implements Server {
  final mensagens = <Map<String, dynamic>>[];

  @override
  Future<void> enviarImpressoes(List<String> mensagens) async {
    for (final mensagem in mensagens) {
      write(mensagem);
    }
  }

  @override
  bool write(String message) {
    mensagens.add(jsonDecode(message) as Map<String, dynamic>);
    return true;
  }
}

class ModuloImpressaoTeste extends Module {
  ModuloImpressaoTeste(this.servidor);

  final ServidorTeste servidor;

  @override
  void binds(Injector i) {
    i.addInstance<Server>(servidor);
    i.addInstance<UsuarioProvedor>(UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '31', nome: 'Vendedor')));
  }
}

void main() {
  test('imprime codigo somente para categoria habilitada', () {
    expect(DadosImpressaoPreparo.produto(produto())['nome'],
        '003 - Porcao inteira');
    expect(
        DadosImpressaoPreparo.produto(produto(imprimirCodigo: 'Não'))['nome'],
        'Porcao inteira');
    expect(DadosImpressaoPreparo.produto(produto(codigo: '  '))['nome'],
        'Porcao inteira');
  });

  test('JSON antigo sem configuracao mantem impressao sem codigo', () {
    final dados = produto().toMap()..remove('imprimirCodigoProdutoPreparo');
    final antigo = Modelowordprodutos.fromMap(dados);
    expect(antigo.imprimirCodigoProdutoPreparo, 'Não');
    expect(DadosImpressaoPreparo.produto(antigo)['nome'], antigo.nome);

    final sabor =
        ModeloDadosOpcoesPacotes.fromMap({'id': '1', 'nome': 'Queijo'});
    expect(sabor.imprimirCodigoProdutoPreparo, 'Não');
  });

  test('preserva configuracao e codigo dos sabores ao serializar o carrinho',
      () {
    final pizza = produto(nome: 'Pizza')
      ..opcoesPacotesListaFinal = [saboresPizza()];
    final recuperado = Modelowordprodutos.fromJson(pizza.toJson());
    expect(recuperado.imprimirCodigoProdutoPreparo, 'Sim');
    final sabores = recuperado.opcoesPacotesListaFinal!.single.dados!;
    expect(sabores.first.codigo, '7');
    expect(sabores.first.imprimirCodigoProdutoPreparo, 'Sim');
    expect(sabores.last.imprimirCodigoProdutoPreparo, 'Não');
  });

  for (final usarListaFinal in [true, false]) {
    test(
        'pizza respeita cada categoria dos sabores, lista final=$usarListaFinal',
        () {
      final pizza = produto(nome: 'Pizza');
      if (usarListaFinal) {
        pizza.opcoesPacotesListaFinal = [saboresPizza()];
      } else {
        pizza.opcoesPacotes = [saboresPizza()];
      }
      final dados = DadosImpressaoPreparo.produto(pizza);
      expect(dados['nome'], 'Pizza');
      final opcoes =
          dados[usarListaFinal ? 'opcoesPacotesListaFinal' : 'opcoesPacotes']
              as List;
      final sabores = opcoes.single['dados'] as List;
      expect(sabores.first['nome'], '7 - Calabresa');
      expect(sabores.last['nome'], 'Chocolate');
      expect(sabores.first['quantimaximaselecao'], '1/2');
      expect(sabores.first['valor'], '25');
    });
  }

  test('combos formatam produtos internos sem alterar complementos', () {
    final combo = produto(nome: 'Combo', imprimirCodigo: 'Não')
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
          id: 2,
          titulo: 'Combos',
          obrigatorio: false,
          dados: [],
          produtos: [produto()],
        ),
        ModeloOpcoesPacotes(
          id: 9,
          titulo: 'Tamanho Pizza',
          obrigatorio: false,
          dados: [ModeloDadosOpcoesPacotes(id: '7', nome: 'G')],
        ),
      ];
    final dados = DadosImpressaoPreparo.produto(combo);
    final opcoes = dados['opcoesPacotesListaFinal'] as List;
    expect(opcoes.first['produtos'].single['nome'], '003 - Porcao inteira');
    expect(opcoes.last['dados'].single['nome'], 'G');
  });

  test('formatacao nao altera produto original nem duplica codigo', () {
    final pizza = produto(nome: 'Pizza')
      ..opcoesPacotesListaFinal = [saboresPizza()];
    final original = pizza.toJson();
    final primeira = DadosImpressaoPreparo.produto(pizza);
    final segunda =
        DadosImpressaoPreparo.produto(Modelowordprodutos.fromMap(primeira));
    expect(segunda, primeira);
    expect(pizza.toJson(), original);
    expect(
      DadosImpressaoPreparo.produto(
          produto(nome: '003 - Porcao inteira'))['nome'],
      '003 - Porcao inteira',
    );
  });

  group('envio ao computador de impressao', () {
    late ServidorTeste servidor;

    setUp(() {
      servidor = ServidorTeste();
      Modular.init(ModuloImpressaoTeste(servidor));
    });

    tearDown(Modular.destroy);

    test('preserva produtos sem computador em pedido com varios destinos',
        () async {
      final pizza = produto(nome: 'Pizza de Queijos', computador: 'Cozinha')
        ..observacao = 'Sem cebola'
        ..opcoesPacotesListaFinal = [saboresPizza()];
      final itens = [
        pizza,
        produto(id: 'bebida', computador: 'Bar'),
        produto(id: 'sem-destino')
      ];
      final mensagens = Impressao.prepararComprovanteDePedido(produtos: itens);
      pizza.opcoesPacotesListaFinal!.clear();
      itens.clear();
      await servidor.enviarImpressoes(mensagens);
      expect(servidor.mensagens, hasLength(3));
      final enviados =
          servidor.mensagens.expand((e) => e['produtos'] as List).toList();
      expect(enviados.map((e) => e['id']), ['100', 'bebida', 'sem-destino']);
      expect(enviados.first['observacao'], 'Sem cebola');
      expect(
          enviados.first['opcoesPacotesListaFinal'][0]['dados'], hasLength(2));
      expect(servidor.mensagens.map((e) => e['idRequisicao']).toSet(),
          hasLength(3));
    });

    for (final agruparPorDestino in [true, false]) {
      test('pedido misto aplica regra no envio, agrupado=$agruparPorDestino',
          () async {
        final itens = [
          produto(computador: agruparPorDestino ? 'Cozinha' : null),
          produto(
            id: '200',
            nome: 'Coca Cola 2L',
            codigo: '1010',
            imprimirCodigo: 'Não',
            computador: agruparPorDestino ? 'Bar' : null,
          ),
        ];
        final controlador = TextEditingController(text: '1');
        addTearDown(controlador.dispose);
        itens.first.quantidadeController = controlador;

        await Impressao.comprovanteDePedido(produtos: itens);
        expect(servidor.mensagens, hasLength(agruparPorDestino ? 2 : 1));
        final enviados = servidor.mensagens
            .expand((mensagem) => mensagem['produtos'] as List)
            .toList();
        expect(enviados.map((item) => item['nome']),
            ['003 - Porcao inteira', 'Coca Cola 2L']);
        expect(enviados.first['codigo'], '003');
        expect(enviados.first['quantidadeController'], isNull);
        expect(itens.first.quantidadeController, same(controlador));
        expect(itens.first.nome, 'Porcao inteira');
        expect(servidor.mensagens.first['tipoImpressao'], '1');
        expect(servidor.mensagens.first['idEmpresa'], '31');

        itens.first.quantidadeController = null;
        servidor.mensagens.clear();
        Impressao.comprovanteDeConsumo(produtos: itens);
        final consumo = servidor.mensagens
            .expand((mensagem) => mensagem['produtos'] as List);
        expect(consumo.map((item) => item['nome']),
            ['Porcao inteira', 'Coca Cola 2L']);
        expect(servidor.mensagens.first['tipoImpressao'], '2');
      });
    }
  });
}
