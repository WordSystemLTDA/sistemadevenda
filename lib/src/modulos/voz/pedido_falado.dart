import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';

import 'falha_pedido_voz.dart';
export 'falha_pedido_voz.dart';

class PedidoFalado {
  final bool pizza;
  final String produto, tamanho, observacao;
  final int quantidade;
  final List<String> sabores, bordas;
  final List<({String nome, int quantidade})> adicionais;

  const PedidoFalado(
      {required this.pizza,
      required this.produto,
      required this.tamanho,
      required this.quantidade,
      required this.sabores,
      required this.bordas,
      required this.adicionais,
      required this.observacao});

  factory PedidoFalado.fromMap(Map dados) {
    String texto(String campo, {int limite = 160}) {
      final valor = dados[campo];
      if (valor is! String || valor.length > limite) {
        throw const FalhaPedidoVoz(
            'A resposta da voz veio incompleta. Repita o pedido.');
      }
      return valor.trim();
    }

    final esclarecimento = texto('esclarecimento', limite: 500);
    if (esclarecimento.isNotEmpty) throw FalhaPedidoVoz(esclarecimento);
    final tipo = texto('tipo');
    if (!['pizza', 'produto'].contains(tipo)) {
      throw const FalhaPedidoVoz(
          'Fale um produto por vez, com todas as suas opções.');
    }
    List<String> nomes(String campo, int maximo) {
      final lista = dados[campo];
      if (lista is! List ||
          lista.length > maximo ||
          lista
              .any((e) => e is! String || e.trim().isEmpty || e.length > 160)) {
        throw const FalhaPedidoVoz(
            'Não foi possível identificar as opções do pedido.');
      }
      return lista.cast<String>().map((e) => e.trim()).toList();
    }

    final quantidade = dados['quantidade'];
    if (quantidade is! int || quantidade < 1 || quantidade > 20) {
      throw const FalhaPedidoVoz('Informe uma quantidade de 1 a 20 unidades.');
    }
    final adicionais = dados['adicionais'];
    if (adicionais is! List || adicionais.length > 20) {
      throw const FalhaPedidoVoz('Adicionais inválidos. Repita o pedido.');
    }
    final lista = <({String nome, int quantidade})>[];
    for (final adicional in adicionais) {
      if (adicional is! Map ||
          adicional['nome'] is! String ||
          (adicional['nome'] as String).trim().isEmpty ||
          (adicional['nome'] as String).length > 160 ||
          adicional['quantidade'] is! int ||
          adicional['quantidade'] < 1 ||
          adicional['quantidade'] > 20) {
        throw const FalhaPedidoVoz(
            'Informe o nome e a quantidade de cada adicional.');
      }
      lista.add((
        nome: (adicional['nome'] as String).trim(),
        quantidade: adicional['quantidade'] as int
      ));
    }
    final pedido = PedidoFalado(
        pizza: tipo == 'pizza',
        produto: texto('produto'),
        tamanho: texto('tamanho'),
        quantidade: quantidade,
        sabores: nomes('sabores', 8),
        bordas: nomes('bordas', 8),
        adicionais: lista,
        observacao: texto('observacao', limite: 500));
    if (pedido.pizza
        ? pedido.tamanho.isEmpty || pedido.sabores.isEmpty
        : pedido.produto.isEmpty ||
            pedido.sabores.isNotEmpty ||
            pedido.bordas.isNotEmpty) {
      throw const FalhaPedidoVoz(
          'Faltam detalhes do produto. Para pizza, informe tamanho e sabores.');
    }
    return pedido;
  }
}

String normalizarNomeVoz(String texto) {
  return normalizarBusca(texto).replaceAll(
      RegExp(r'\b(mucarela|mussarela|mozarela|mozzarella)\b'), 'mussarela');
}

T encontrarOpcaoVoz<T>(
    String nome, Iterable<T> opcoes, String Function(T) rotulo) {
  final encontrados = opcoes
      .where((e) => normalizarNomeVoz(rotulo(e)) == normalizarNomeVoz(nome))
      .toList();
  if (encontrados.length != 1) {
    throw FalhaPedidoVoz(encontrados.isEmpty
        ? 'Não encontrei "$nome" disponível. Use o nome completo do cardápio.'
        : 'Existe mais de uma opção "$nome". Selecione esse produto pelo cardápio.');
  }
  return encontrados.single;
}

/// A IA fornece nomes, nunca IDs, preços ou o destino do atendimento.
class MontadorPedidoVoz {
  final UsuarioProvedor usuario;
  final ServicosCategoria servicoCategorias;
  final ModeloConfigBigchef configuracao;
  final List<ModeloCategoria> categorias;
  final List<Modelowordprodutos> catalogo;
  MontadorPedidoVoz(
      {required this.usuario,
      required this.servicoCategorias,
      required this.configuracao,
      required this.categorias,
      required this.catalogo});

  List<Modelowordprodutos> produtosDoPedido(PedidoFalado pedido) {
    final disponiveis = catalogo.where((p) =>
        p.ativo == 'Sim' &&
        (p.tamanhosPizza?.isNotEmpty ?? false) == pedido.pizza);
    final nomes = pedido.pizza ? pedido.sabores : [pedido.produto];
    final produtos = nomes
        .map((nome) => encontrarOpcaoVoz(nome, disponiveis, (p) => p.nome))
        .toList();
    if (produtos.map((p) => p.id).toSet().length != produtos.length) {
      throw const FalhaPedidoVoz(
          'Há sabores repetidos. Informe cada sabor uma vez.');
    }
    return produtos;
  }

  String idTamanho(PedidoFalado pedido) {
    if (!pedido.pizza) return '0';
    final tamanhos = {
      for (final c in categorias)
        for (final t in c.tamanhosPizza ?? []) t.id: t
    };
    return encontrarOpcaoVoz(
        pedido.tamanho, tamanhos.values, (t) => t.nomedotamanho).id;
  }

  double _preco(String? valor) {
    final preco = double.tryParse(valor ?? '');
    if (preco == null || !preco.isFinite || preco < 0) {
      throw const FalhaPedidoVoz(
          'Preço indisponível. Confira o cadastro do produto.');
    }
    return preco;
  }

  Modelowordprodutos montar(PedidoFalado pedido, Modelowordprodutos detalhes) {
    final selecionados = produtosDoPedido(pedido);
    if (detalhes.id != selecionados.first.id || detalhes.ativo != 'Sim') {
      throw const FalhaPedidoVoz(
          'O produto mudou. Consulte o cardápio novamente.');
    }
    final cardapio = ProvedorCardapio(servicoCategorias, usuario)
      ..configBigchef = configuracao;
    final produto = ProvedorProduto(cardapio, usuario)
      ..quantidade = pedido.quantidade;
    try {
      if (pedido.pizza) {
        if (![
          'media',
          'maior'
        ].contains(usuario.usuario?.configuracoes?.modelovalortamanhopizza)) {
          throw const FalhaPedidoVoz(
              'Configure a regra de preço da pizza antes do envio por voz.');
        }
        final tamanho = categorias
            .expand((c) => c.tamanhosPizza ?? [])
            .firstWhere((t) => t.id == idTamanho(pedido));
        if (selecionados.length > (int.tryParse(tamanho.saboreslimite) ?? 0)) {
          throw const FalhaPedidoVoz(
              'Esse tamanho não permite tantos sabores.');
        }
        cardapio.tamanhosPizza = tamanho;
        for (final sabor in selecionados) {
          final valorTamanho = cardapio.tamanhoPizzaDoProduto(sabor);
          if (valorTamanho == null) {
            throw FalhaPedidoVoz(
                '${sabor.nome} não está disponível nesse tamanho.');
          }
          _preco(valorTamanho.valor);
        }
        cardapio.saboresPizzaSelecionados = selecionados;
        produto.valorVendaOriginal = cardapio.calcularPrecoPizza();
      } else {
        produto.valorVendaOriginal = _preco(detalhes.valorVenda);
      }
      final grupos = (detalhes.opcoesPacotes ?? [])
          .where((o) => o.id != 9 && o.id != 10 && o.tipo != 7)
          .toList();
      if (grupos.any((o) =>
          (o.produtos?.isNotEmpty ?? false) ||
          (o.opcoesPacote?.isNotEmpty ?? false))) {
        throw const FalhaPedidoVoz(
            'Esse produto tem uma montagem especial. Monte pelo cardápio.');
      }
      final escolhas = <int, List<ModeloDadosOpcoesPacotes>>{};
      void selecionar(int grupo, List<({String nome, int quantidade})> nomes) {
        if (nomes.isEmpty) return;
        final opcoes = grupos.where((o) => o.id == grupo).firstOrNull;
        final dados = <ModeloDadosOpcoesPacotes>[];
        for (final nome in nomes) {
          final original = encontrarOpcaoVoz(nome.nome,
              opcoes?.dados ?? <ModeloDadosOpcoesPacotes>[], (d) => d.nome);
          if (dados.any((d) => d.id == original.id)) {
            throw const FalhaPedidoVoz(
                'Opção repetida. Informe a quantidade em uma única escolha.');
          }
          _preco(original.valor);
          final limite = int.tryParse(original.quantimaximaselecao ?? '');
          if (grupo == 7 &&
              limite != null &&
              limite > 0 &&
              nome.quantidade > limite) {
            throw FalhaPedidoVoz(
                'A quantidade de ${nome.nome} ultrapassa o limite permitido.');
          }
          dados.add(ModeloDadosOpcoesPacotes.fromMap(original.toMap())
            ..quantidade = grupo == 7 ? nome.quantidade : null
            ..estaSelecionado = true);
        }
        escolhas[grupo] = dados;
      }

      selecionar(
          6, pedido.bordas.map((n) => (nome: n, quantidade: 1)).toList());
      selecionar(7, pedido.adicionais);
      if (!pedido.pizza && pedido.tamanho.isNotEmpty) {
        selecionar(4, [(nome: pedido.tamanho, quantidade: 1)]);
      }
      final limiteBordas = int.tryParse(configuracao.saborlimitedeborda) ?? 0;
      if (limiteBordas > 0 && pedido.bordas.length > limiteBordas) {
        throw const FalhaPedidoVoz(
            'A pizza não permite essa quantidade de sabores de borda.');
      }
      cardapio.limiteSaborBordaSelecionado =
          pedido.bordas.isEmpty ? 1 : pedido.bordas.length;
      for (final grupo in grupos) {
        if ((grupo.obrigatorio || grupo.id == 4 || grupo.id == 11) &&
            (grupo.dados?.isNotEmpty ?? false) &&
            (escolhas[grupo.id]?.isEmpty ?? true)) {
          throw FalhaPedidoVoz(
              'Falta escolher: ${grupo.titulo}. Complete a montagem pelo cardápio.');
        }
      }
      produto.opcoesPacotesListaFinal = [
        for (final grupo in grupos)
          ModeloOpcoesPacotes.fromMap(grupo.toMap())
            ..dados = escolhas[grupo.id] ?? []
      ];
      produto.calcularValorVenda(false, '0');
      _preco(produto.valorVenda.toString());
      // Tamanho e sabores só entram após o cálculo: não somar a pizza duas vezes.
      if (pedido.pizza) {
        produto.opcoesPacotesListaFinal.insertAll(0, [
          ModeloOpcoesPacotes(
              id: 9,
              titulo: 'Tamanho Pizza',
              obrigatorio: false,
              dados: [
                ModeloDadosOpcoesPacotes(
                    id: cardapio.tamanhosPizza!.id,
                    nome: cardapio.tamanhosPizza!.nomedotamanho,
                    valor: cardapio.calcularPrecoPizza().toStringAsFixed(2))
              ]),
          ModeloOpcoesPacotes(
              id: 10,
              titulo: 'Sabores Pizza (${selecionados.length})',
              obrigatorio: false,
              dados: cardapio.saboresParaCarrinho()),
        ]);
      }
      if (pedido.observacao.isNotEmpty) {
        produto.opcoesPacotesListaFinal.add(ModeloOpcoesPacotes(
            id: 11,
            titulo: 'Observação',
            tipo: 7,
            obrigatorio: false,
            dados: [
              ModeloDadosOpcoesPacotes(id: '0', nome: pedido.observacao)
            ]));
      }
      return Modelowordprodutos.fromMap(detalhes.toMap())
        ..quantidade = pedido.quantidade.toDouble()
        ..valorVenda = produto.valorVenda.toStringAsFixed(2)
        ..observacao = pedido.observacao
        ..limiteSaboresBorda = cardapio.limiteSaborBordaSelecionado
        ..conferidoNoCarrinho = false
        ..opcoesPacotesListaFinal = produto.opcoesParaCarrinho();
    } finally {
      produto.dispose();
      cardapio.dispose();
    }
  }
}
