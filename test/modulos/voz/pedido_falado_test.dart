import 'dart:convert';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/voz/pedido_falado.dart';
import 'package:app/src/modulos/voz/servico_pedido_voz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cardapio/montagem_pizza_test.dart' as fixture;
import '../cardapio/carrinhos_por_atendimento_test.dart' show ApiCarrinhoTeste;

Map<String, dynamic> comandoPizza() => {
      'tipo': 'pizza',
      'produto': '',
      'quantidade': 1,
      'tamanho': 'G',
      'sabores': ['Muçarela', 'Calabresa'],
      'bordas': ['Chocolate'],
      'adicionais': [
        {'nome': 'Milho', 'quantidade': 1}
      ],
      'observacao': 'Bem assada',
      'esclarecimento': '',
    };

Modelowordprodutos pizzaDetalhada() => fixture.sabor('1', 'Queijos', '50')
  ..nome = 'Pizza de Queijos'
  ..opcoesPacotes = [
    ModeloOpcoesPacotes(id: 6, titulo: 'Bordas', obrigatorio: false, dados: [
      ModeloDadosOpcoesPacotes(id: 'choc', nome: 'Chocolate', valor: '12'),
      ModeloDadosOpcoesPacotes(id: 'cat', nome: 'Catupiry', valor: '16'),
    ]),
    ModeloOpcoesPacotes(
        id: 7,
        titulo: 'Adicionais',
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
              id: 'milho', nome: 'Milho', valor: '3', quantimaximaselecao: '5'),
        ]),
  ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UsuarioProvedor usuario;
  late MontadorPedidoVoz montador;
  late List<Modelowordprodutos> catalogo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          id: '1',
          empresa: '32',
          configuracoes: fixture.ConfiguracoesTeste('media')));
    catalogo = [
      fixture.sabor('1', 'Queijos', '50')..nome = 'Mussarela',
      fixture.sabor('2', 'Calabresa', '70')..nome = 'Calabresa'
    ];
    montador = MontadorPedidoVoz(
        usuario: usuario,
        servicoCategorias: fixture.CategoriasTeste(),
        configuracao: fixture.configBigchef(),
        categorias: fixture.CategoriasTeste().categorias,
        catalogo: catalogo);
  });
  tearDown(() => usuario.dispose());

  test(
      'pizza G de dois sabores com borda chocolate e milho conserva preço e composição',
      () {
    final detalhes = pizzaDetalhada();
    final antes = jsonEncode(detalhes.toMap());
    final item =
        montador.montar(PedidoFalado.fromMap(comandoPizza()), detalhes);
    expect(item.valorVenda, '75.00'); // Media 60 + borda 12 + milho 3.
    expect(item.quantidade, 1);
    expect(item.observacao, 'Bem assada');
    expect(item.conferidoNoCarrinho, false);
    final opcoes = item.opcoesPacotesListaFinal!;
    expect(opcoes.first.dados!.single.id, 'G');
    expect(opcoes[1].dados!.map((d) => d.id), ['1', '2']);
    expect(opcoes[1].dados!.map((d) => d.valor), ['25.00', '35.00']);
    expect(opcoes.where((o) => o.id == 6).single.dados!.single.id, 'choc');
    expect(opcoes.where((o) => o.id == 7).single.dados!.single.quantidade, 1);
    expect(jsonEncode(detalhes.toMap()), antes);
    expect(catalogo.first.opcoesPacotesListaFinal, isNull);
  });

  test('quantidade e adicionais sem cobrar a pizza duas vezes', () {
    final dados = comandoPizza()
      ..['quantidade'] = 2
      ..['adicionais'] = [
        {'nome': 'Milho', 'quantidade': 3}
      ];
    final item = montador.montar(PedidoFalado.fromMap(dados), pizzaDetalhada());
    expect(item.valorVenda, '81.00');
    expect(double.parse(item.valorVenda) * item.quantidade!, 162);
  });

  test('regra do maior valor e rateio das bordas iguais ao pedido manual', () {
    usuario.setUsuario(UsuarioModelo(
        id: '1',
        empresa: '32',
        configuracoes: fixture.ConfiguracoesTeste('maior')));
    final item = montador.montar(
        PedidoFalado.fromMap(
            comandoPizza()..['bordas'] = ['Chocolate', 'Catupiry']),
        pizzaDetalhada());
    expect(item.valorVenda, '89.00');
    final bordas =
        item.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 6).dados!;
    expect(bordas.fold(0.0, (s, b) => s + double.parse(b.valor!)), 16);
  });

  for (final alteracao in <String, Map<String, dynamic>>{
    'sem tamanho': {'tamanho': ''},
    'sem sabor': {'sabores': []},
    'quantidade negativa': {'quantidade': -1},
    'quantidade fracionada': {'quantidade': 1.5},
    'quantidade muito alta': {'quantidade': 21},
    'esclarecimento': {'esclarecimento': 'Qual tamanho?'},
    'tipo desconhecido': {'tipo': 'transferencia'},
    'adicional sem nome': {
      'adicionais': [
        {'nome': '', 'quantidade': 1}
      ]
    },
    'quantidade adicional zero': {
      'adicionais': [
        {'nome': 'Milho', 'quantidade': 0}
      ]
    },
  }.entries) {
    test('nao aceita resposta ${alteracao.key}', () {
      expect(
          () => PedidoFalado.fromMap({...comandoPizza(), ...alteracao.value}),
          throwsA(isA<FalhaPedidoVoz>()));
    });
  }

  for (final alteracao in <String, Map<String, dynamic>>{
    'sabor inexistente': {
      'sabores': ['Pepperoni']
    },
    'nome parcial': {
      'sabores': ['Mussa']
    },
    'sabor repetido': {
      'sabores': ['Mussarela', 'Mussarela']
    },
    'tamanho inexistente': {'tamanho': 'GG'},
    'limite de sabores': {'tamanho': 'P'},
    'borda inexistente': {
      'bordas': ['Doce de leite']
    },
    'adicional inexistente': {
      'adicionais': [
        {'nome': 'Bacon', 'quantidade': 1}
      ]
    },
    'limite de adicional': {
      'adicionais': [
        {'nome': 'Milho', 'quantidade': 6}
      ]
    },
    'adicional repetido': {
      'adicionais': [
        {'nome': 'Milho', 'quantidade': 1},
        {'nome': 'Milho', 'quantidade': 1}
      ]
    },
  }.entries) {
    test('bloqueia ${alteracao.key} sem montagem parcial', () {
      expect(
          () => montador.montar(
              PedidoFalado.fromMap({...comandoPizza(), ...alteracao.value}),
              pizzaDetalhada()),
          throwsA(isA<FalhaPedidoVoz>()));
    });
  }
  test('nao escolhe automaticamente entre produtos homonimos', () {
    catalogo.add(fixture.sabor('3', 'Doces', '40')..nome = 'Mussarela');
    expect(
        () => montador.produtosDoPedido(PedidoFalado.fromMap(comandoPizza())),
        throwsA(isA<FalhaPedidoVoz>()));
  });
  test('produto indisponivel bloqueado', () {
    catalogo.first.ativo = 'Não';
    expect(
        () => montador.montar(
            PedidoFalado.fromMap(comandoPizza()), pizzaDetalhada()),
        throwsA(isA<FalhaPedidoVoz>()));
  });
  test('opcao obrigatoria desconhecida nao e ignorada', () {
    final detalhes = pizzaDetalhada();
    detalhes.opcoesPacotes!.add(ModeloOpcoesPacotes(
        id: 5,
        titulo: 'Acompanhamento',
        obrigatorio: true,
        dados: [ModeloDadosOpcoesPacotes(id: 'x', nome: 'Molho', valor: '1')]));
    expect(
        () => montador.montar(PedidoFalado.fromMap(comandoPizza()), detalhes),
        throwsA(isA<FalhaPedidoVoz>()));
  });
  test('preco invalido nao vira zero', () {
    catalogo.first.tamanhosPizza =
        fixture.sabor('1', 'Queijos', 'NaN').tamanhosPizza;
    expect(
        () => montador.montar(
            PedidoFalado.fromMap(comandoPizza()), pizzaDetalhada()),
        throwsA(isA<FalhaPedidoVoz>()));
  });
  test('produto simples sem configuracao adicional', () {
    final agua = fixture.sabor('agua', 'Bebidas', '0')
      ..nome = 'Água'
      ..tamanhosPizza = []
      ..valorVenda = '5';
    catalogo.add(agua);
    final pedido = PedidoFalado.fromMap(comandoPizza()
      ..['tipo'] = 'produto'
      ..['produto'] = 'agua'
      ..['tamanho'] = ''
      ..['sabores'] = []
      ..['bordas'] = []
      ..['adicionais'] = []);
    expect(montador.montar(pedido, agua).valorVenda, '5.00');
  });
  test('voz usa HTTPS no mesmo servidor sem alterar caminho api1', () {
    expect(
        ServicoPedidoVoz.enderecoSeguro('http://192.168.2.113/sistema/api1/'),
        'https://192.168.2.113/sistema/api1/');
    expect(ServicoPedidoVoz.enderecoSeguro('https://restaurante:8443/api/'),
        'https://restaurante:8443/api/');
    expect(
        () => ServicoPedidoVoz.enderecoSeguro(
            'http://usuario:senha@restaurante/'),
        throwsA(isA<FalhaPedidoVoz>()));
  });

  group('gravação no atendimento', () {
    late ProvedorCarrinho carrinho;
    late ApiCarrinhoTeste api;
    setUp(() async {
      api = ApiCarrinhoTeste();
      carrinho = ProvedorCarrinho(ServicosItensComanda(api, usuario));
      await carrinho.selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '104', idRecurso: '4');
    });
    tearDown(() {
      carrinho.dispose();
      api.cliente.close();
    });
    test('grava uma vez e nunca inclui rascunhos anteriores', () async {
      final contexto = carrinho.contexto!;
      final item = montador.montar(
          PedidoFalado.fromMap(comandoPizza()), pizzaDetalhada());
      expect(await carrinho.prepararEnvioVoz(item, contexto), true);
      expect(
          jsonEncode((await carrinho.obterItensParaFinalizar(contexto))
              .map((e) => e.toMap())
              .toList()),
          jsonEncode([item.toMap()]));
      await expectLater(
          carrinho.prepararEnvioVoz(item, contexto), throwsStateError);
      expect(carrinho.itensCarrinho.listaComandosPedidos, hasLength(1));
      expect(api.chamadas, isEmpty);
    });
    test('comanda reutilizada nao recebe o pedido antigo', () async {
      final contexto = carrinho.contexto!;
      await carrinho.selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '204', idRecurso: '4');
      expect(
          await carrinho.prepararEnvioVoz(pizzaDetalhada(), contexto), false);
      expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    });
  });
}
