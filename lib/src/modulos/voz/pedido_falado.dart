import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';

import 'falha_pedido_voz.dart';
import 'destino_pedido_voz.dart';
import '../cardapio/modelos/montagem_ingrediente_cardapio.dart';
import '../cardapio/uteis/montagem_cardapio.dart';
export 'falha_pedido_voz.dart';
export 'destino_pedido_voz.dart';

typedef ResultadoPedidoVoz = ({
  String texto,
  Modelowordprodutos item,
  DestinoPedidoVoz destino,
});

class PedidoFalado {
  final bool pizza;
  final String produto, tamanho, observacao;
  final int quantidade;
  final DestinoPedidoVoz destino;
  final List<String> sabores, bordas;
  final List<({String nome, int quantidade})> adicionais;
  final List<IngredienteFalado> ingredientes;
  final List<String> retiradas, acompanhamentos, cortesias;

  const PedidoFalado(
      {required this.pizza,
      required this.produto,
      required this.tamanho,
      required this.quantidade,
      required this.sabores,
      required this.bordas,
      required this.adicionais,
      required this.observacao,
      this.ingredientes = const [],
      this.retiradas = const [],
      this.acompanhamentos = const [],
      this.cortesias = const [],
      this.destino = DestinoPedidoVoz.carrinho});

  factory PedidoFalado.fromMap(Map dados, {bool lote = false}) {
    String texto(String campo, {int limite = 160}) {
      final valor = dados[campo];
      if (valor is! String || valor.length > (lote ? 500 : limite)) {
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
          lista.length > (lote ? 40 : maximo) ||
          lista.any((e) =>
              e is! String ||
              e.trim().isEmpty ||
              e.length > (lote ? 500 : 160))) {
        throw const FalhaPedidoVoz(
            'Não foi possível identificar as opções do pedido.');
      }
      return lista.cast<String>().map((e) => e.trim()).toList();
    }

    final quantidade = dados['quantidade'];
    if (quantidade is! int ||
        quantidade < 1 ||
        quantidade > (lote ? 100 : 20)) {
      throw FalhaPedidoVoz(
          'Informe uma quantidade de 1 a ${lote ? 100 : 20} unidades.');
    }
    final adicionais = dados['adicionais'];
    if (adicionais is! List || adicionais.length > (lote ? 40 : 20)) {
      throw const FalhaPedidoVoz('Adicionais inválidos. Repita o pedido.');
    }
    final lista = <({String nome, int quantidade})>[];
    for (final adicional in adicionais) {
      if (adicional is! Map ||
          adicional['nome'] is! String ||
          (adicional['nome'] as String).trim().isEmpty ||
          (adicional['nome'] as String).length > (lote ? 500 : 160) ||
          adicional['quantidade'] is! int ||
          adicional['quantidade'] < 1 ||
          adicional['quantidade'] > (lote ? 100 : 20)) {
        throw const FalhaPedidoVoz(
            'Informe o nome e a quantidade de cada adicional.');
      }
      lista.add((
        nome: (adicional['nome'] as String).trim(),
        quantidade: adicional['quantidade'] as int
      ));
    }
    final pedido = PedidoFalado(
        destino: DestinoPedidoVoz.interpretar(dados['destino']),
        pizza: tipo == 'pizza',
        produto: texto('produto'),
        tamanho: texto('tamanho'),
        quantidade: quantidade,
        sabores: nomes('sabores', 8),
        bordas: nomes('bordas', 8),
        adicionais: lista,
        ingredientes: IngredienteFalado.lerLista(dados['ingredientes']),
        retiradas: dados.containsKey('retiradas') ? nomes('retiradas', 20) : [],
        acompanhamentos: dados.containsKey('acompanhamentos')
            ? nomes('acompanhamentos', 20)
            : [],
        cortesias: dados.containsKey('cortesias') ? nomes('cortesias', 20) : [],
        observacao: texto('observacao', limite: 500));
    if (pedido.pizza
        ? pedido.tamanho.isEmpty || pedido.sabores.isEmpty
        : pedido.produto.isEmpty ||
            (!lote && pedido.sabores.isNotEmpty) ||
            pedido.bordas.isNotEmpty) {
      throw const FalhaPedidoVoz(
          'Faltam detalhes do produto. Para pizza, informe tamanho e sabores.');
    }
    return pedido;
  }

  Map<String, dynamic> toMap() => {
        'tipo': pizza ? 'pizza' : 'produto',
        'produto': produto,
        'tamanho': tamanho,
        'quantidade': quantidade,
        'sabores': sabores,
        'bordas': bordas,
        'adicionais': adicionais
            .map((e) => {'nome': e.nome, 'quantidade': e.quantidade})
            .toList(),
        'ingredientes': ingredientes.map((e) => e.toMap()).toList(),
        'retiradas': retiradas,
        'acompanhamentos': acompanhamentos,
        'cortesias': cortesias,
        'observacao': observacao,
      };
}

class IngredienteFalado {
  final String nome, destino;
  final AcaoIngredienteCardapio acao;
  final int quantidade;
  final bool separado;
  const IngredienteFalado(
      this.nome, this.acao, this.destino, this.quantidade, this.separado);

  static List<IngredienteFalado> lerLista(Object? dados) {
    if (dados == null) return [];
    if (dados is! List || dados.length > 60) {
      throw const FalhaPedidoVoz('Ingredientes inválidos. Repita a montagem.');
    }
    final nomes = <String>{};
    return dados.map((e) {
      if (e is! Map ||
          e['nome'] is! String ||
          (e['nome'] as String).trim().isEmpty ||
          (e['nome'] as String).length > 500 ||
          e['destino'] is! String ||
          (e['destino'] as String).length > 500 ||
          e['quantidade'] is! int ||
          e['quantidade'] < 1 ||
          e['quantidade'] > 100 ||
          e['separado'] is! bool) {
        throw const FalhaPedidoVoz(
            'Não consegui identificar os ingredientes completos.');
      }
      final acao = AcaoIngredienteCardapio.values
          .where((a) => a.name == e['acao'])
          .firstOrNull;
      if (acao == null ||
          !nomes.add(normalizarNomeVoz(e['nome'])) ||
          (acao == AcaoIngredienteCardapio.trocar &&
              (e['destino'] as String).trim().isEmpty) ||
          (acao != AcaoIngredienteCardapio.trocar &&
              (e['destino'] as String).trim().isNotEmpty) ||
          (acao == AcaoIngredienteCardapio.sem && e['separado'] == true)) {
        throw const FalhaPedidoVoz(
            'Há escolhas contraditórias nos ingredientes. Confira a montagem.');
      }
      return IngredienteFalado(
          (e['nome'] as String).trim(),
          acao,
          (e['destino'] as String).trim(),
          e['quantidade'] as int,
          e['separado'] as bool);
    }).toList();
  }

  Map<String, dynamic> toMap() => {
        'nome': nome,
        'acao': acao.name,
        'destino': destino,
        'quantidade': quantidade,
        'separado': separado
      };
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
        if (opcoes?.tipo == 1 && nomes.length > 1) {
          throw FalhaPedidoVoz(
              'Escolha apenas uma opção em ${opcoes!.titulo}.');
        }
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
      if (!pedido.pizza) {
        selecionar(
            11, pedido.sabores.map((n) => (nome: n, quantidade: 1)).toList());
      }
      selecionar(
          8, pedido.retiradas.map((n) => (nome: n, quantidade: 1)).toList());
      selecionar(5,
          pedido.acompanhamentos.map((n) => (nome: n, quantidade: 1)).toList());
      selecionar(
          1, pedido.cortesias.map((n) => (nome: n, quantidade: 1)).toList());
      final montagens = grupos
          .where((g) => g.tipo == 8 || tituloIngredientesCardapio(g.titulo))
          .toList();
      if ((detalhes.idCategoriaCardapio ?? '').isNotEmpty &&
          detalhes.idCategoriaCardapio != '0' &&
          montagens.isEmpty) {
        throw const FalhaPedidoVoz(
            'A montagem do cardápio está incompleta. Atualize a API e tente novamente.');
      }
      final ingredientesUsados = <String>{};
      for (final grupo in montagens) {
        final ingredientes = MontagemCardapio.iniciar(grupo.dados ?? []);
        if (ingredientes.isEmpty) {
          throw const FalhaPedidoVoz(
              'O cardápio do dia não possui ingredientes disponíveis.');
        }
        // Aplique todas as ações antes de validar trocas: uma escolha posterior
        // não pode remover o ingrediente usado como destino de outra escolha.
        for (final falado in pedido.ingredientes) {
          final encontrados = ingredientes
              .where((e) =>
                  normalizarNomeVoz(
                      e.montagemCardapio?.nomeOriginal ?? e.nome) ==
                  normalizarNomeVoz(falado.nome))
              .toList();
          if (encontrados.isEmpty) continue;
          if (encontrados.length != 1 ||
              !ingredientesUsados.add(normalizarNomeVoz(falado.nome))) {
            throw FalhaPedidoVoz(
                'O ingrediente ${falado.nome} é ambíguo. Confira pelo cardápio.');
          }
          final original = encontrados.single;
          if (!original.permiteMontagemCardapio(falado.acao)) {
            throw FalhaPedidoVoz(
                '${falado.acao.rotulo} não está permitido para ${falado.nome}.');
          }
          ModeloDadosOpcoesPacotes? destino;
          String? tipoDestino;
          if (falado.acao == AcaoIngredienteCardapio.trocar) {
            final possibilidades =
                <({ModeloDadosOpcoesPacotes item, String tipo})>[
              for (final item in ingredientes)
                (item: item, tipo: 'ingrediente'),
              for (final item in grupos
                  .where((g) => g.id == 7)
                  .expand((g) => g.dados ?? <ModeloDadosOpcoesPacotes>[]))
                (item: item, tipo: 'adicional'),
            ];
            final encontrado = encontrarOpcaoVoz(falado.destino, possibilidades,
                (p) => p.item.montagemCardapio?.nomeOriginal ?? p.item.nome);
            destino = encontrado.item;
            tipoDestino = encontrado.tipo;
          }
          ingredientes[ingredientes.indexOf(original)] =
              MontagemCardapio.aplicar(
                  original,
                  MontagemIngredienteCardapio(
                      nomeOriginal: original.montagemCardapio!.nomeOriginal,
                      acao: falado.acao,
                      separado: falado.separado,
                      valorEmbalagemSeparada:
                          _preco(configuracao.valorembalagemseparada)
                              .toStringAsFixed(2),
                      destinoId: destino?.id,
                      destinoNome: destino?.montagemCardapio?.nomeOriginal ??
                          destino?.nome,
                      destinoTipo: tipoDestino,
                      quantidadeTroca: falado.quantidade));
        }
        for (final item in ingredientes) {
          final montagem = item.montagemCardapio!;
          if (montagem.acao != AcaoIngredienteCardapio.trocar) continue;
          final erro = MontagemCardapio.validarTroca(ingredientes, item.id,
              montagem.destinoId!, montagem.destinoTipo!);
          if (erro != null) throw FalhaPedidoVoz(erro);
        }
        escolhas[grupo.id] = ingredientes;
      }
      if (ingredientesUsados.length != pedido.ingredientes.length) {
        final nome = pedido.ingredientes
            .firstWhere(
                (e) => !ingredientesUsados.contains(normalizarNomeVoz(e.nome)))
            .nome;
        throw FalhaPedidoVoz(
            'Não encontrei $nome nos ingredientes disponíveis hoje.');
      }
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
      final observacao = normalizarObservacaoProduto(pedido.observacao);
      if (observacao.isNotEmpty) {
        produto.opcoesPacotesListaFinal
            .add(montarGrupoObservacaoProduto(observacao));
      }
      return Modelowordprodutos.fromMap(detalhes.toMap())
        ..quantidade = pedido.quantidade.toDouble()
        ..valorVenda = produto.valorVenda.toStringAsFixed(2)
        ..observacao = observacao
        ..limiteSaboresBorda = cardapio.limiteSaborBordaSelecionado
        ..conferidoNoCarrinho = false
        ..opcoesPacotesListaFinal = produto.opcoesParaCarrinho();
    } finally {
      produto.dispose();
      cardapio.dispose();
    }
  }
}
