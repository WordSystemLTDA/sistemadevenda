import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';

class DadosImpressaoPreparo {
  static final RegExp _proporcaoNoInicio = RegExp(r'^\(\d+(?:/\d+)?\)\s+');
  static final RegExp _codigoComProporcaoNoInicio =
      RegExp(r'^\S+\s+-\s+\(\d+(?:/\d+)?\)\s+');
  static final RegExp _meioBordaNoInicio = RegExp(
    r'^(Meio|MEIA BORDA|MEIA PIZZA)\s+-\s+',
    caseSensitive: false,
  );

  static String _nome(String nome, String? codigo, String imprimirCodigo) {
    final codigoProduto = codigo?.trim() ?? '';
    if (imprimirCodigo != 'Sim' || codigoProduto.isEmpty) return nome;

    final prefixo = '$codigoProduto - ';
    return nome.startsWith(prefixo) ? nome : '$prefixo$nome';
  }

  static String _nomeSabor(
    String nome,
    String? codigo,
    String imprimirCodigo,
    String? proporcao,
  ) {
    final nomeLimpo = nome.trim();
    if (_codigoComProporcaoNoInicio.hasMatch(nomeLimpo)) return nomeLimpo;

    final codigoProduto = codigo?.trim() ?? '';
    final imprimirCodigoProduto =
        imprimirCodigo == 'Sim' && codigoProduto.isNotEmpty;
    final prefixoCodigo = '$codigoProduto - ';
    final nomeSemCodigo = imprimirCodigoProduto &&
            nomeLimpo.toLowerCase().startsWith(prefixoCodigo.toLowerCase())
        ? nomeLimpo.substring(prefixoCodigo.length).trimLeft()
        : nomeLimpo;

    final textoProporcao =
        (proporcao?.trim().isNotEmpty ?? false) ? proporcao!.trim() : '1';
    final nomeComProporcao = _proporcaoNoInicio.hasMatch(nomeSemCodigo)
        ? nomeSemCodigo
        : '($textoProporcao) $nomeSemCodigo';

    return imprimirCodigoProduto
        ? '$codigoProduto - $nomeComProporcao'
        : nomeComProporcao;
  }

  static Map<String, dynamic> produto(Modelowordprodutos produto) {
    final dados = produto.toMap();
    final opcoes =
        produto.opcoesPacotesListaFinal ?? produto.opcoesPacotes ?? [];
    final temSaboresPizza = opcoes
        .any((opcao) => opcao.id == 10 && (opcao.dados?.isNotEmpty ?? false));

    // Na pizza montada, o codigo pertence a cada sabor, nao ao cabecalho.
    if (!temSaboresPizza) {
      dados['nome'] = _nome(
        produto.nome,
        produto.codigo,
        produto.imprimirCodigoProdutoPreparo,
      );
    }
    dados['quantidadeController'] = null;
    final opcoesFinais = produto.opcoesPacotesListaFinal;
    final observacao = normalizarObservacaoProduto(produto.observacao);
    dados['observacao'] = observacao.isNotEmpty
        ? observacao
        : _observacaoNasOpcoes(opcoesFinais) ??
            _observacaoNasOpcoes(produto.opcoesPacotes) ??
            '';
    dados['opcoesPacotes'] =
        opcoesFinais == null ? _opcoesParaPreparo(produto.opcoesPacotes) : null;
    dados['opcoesPacotesListaFinal'] = _opcoesParaPreparo(opcoesFinais);
    return dados;
  }

  static List<Map<String, dynamic>>? _opcoesParaPreparo(
    List<ModeloOpcoesPacotes>? opcoes,
  ) {
    if (opcoes == null) return null;
    final resultado = <Map<String, dynamic>>[];

    for (final opcao in opcoes) {
      if (grupoObservacaoProduto(opcao)) continue;

      if (_grupoMontagemCardapio(opcao)) {
        final alteracoes = (opcao.dados ?? const <ModeloDadosOpcoesPacotes>[])
            .where((dado) => dado.alteracaoMontagemCardapio != null)
            .toList();
        if (alteracoes.isEmpty) continue;
        resultado.add(_opcao(opcao, dadosFiltrados: alteracoes));
        continue;
      }

      resultado.add(_opcao(opcao));
    }

    return resultado;
  }

  static bool _grupoMontagemCardapio(ModeloOpcoesPacotes grupo) =>
      grupo.tipo == 8 ||
      tituloIngredientesCardapio(grupo.titulo) ||
      (grupo.dados ?? const <ModeloDadosOpcoesPacotes>[]).any((dado) =>
          dado.montagemCardapio != null ||
          _idCardapioValido(dado.idCategoriaCardapio));

  static bool _idCardapioValido(Object? valor) {
    final texto = (valor ?? '').toString().trim().toLowerCase();
    return texto.isNotEmpty && texto != '0' && texto != 'null';
  }

  static String? _observacaoNasOpcoes(List<ModeloOpcoesPacotes>? opcoes) {
    for (final opcao in opcoes ?? const <ModeloOpcoesPacotes>[]) {
      if (!grupoObservacaoProduto(opcao)) continue;
      final dados = opcao.dados ?? const <ModeloDadosOpcoesPacotes>[];
      if (dados.isEmpty) continue;
      final texto = normalizarObservacaoProduto(dados.first.nome);
      if (texto.isNotEmpty) return texto;
    }
    return null;
  }

  static Map<String, dynamic> _opcao(
    ModeloOpcoesPacotes opcao, {
    List<ModeloDadosOpcoesPacotes>? dadosFiltrados,
  }) {
    final dados = opcao.toMap();
    final dadosOpcao = dadosFiltrados ?? opcao.dados;
    final montagemCardapio = _grupoMontagemCardapio(opcao);
    if (montagemCardapio) {
      dados['titulo'] = 'Cardápio';
    }
    dados['produtos'] = opcao.produtos?.map(produto).toList();
    dados['opcoesPacote'] = _opcoesParaPreparo(opcao.opcoesPacote);
    dados['dados'] = dadosOpcao?.map((item) {
      final mapa = item.toMap();
      final montagem = item.alteracaoMontagemCardapio;
      if (montagemCardapio && montagem != null) {
        mapa['montagemCardapio'] = montagem.toMap();
      }
      return mapa;
    }).toList();
    if (opcao.id == 10) {
      dados['dados'] = dadosOpcao?.map((sabor) {
        return {
          ...sabor.toMap(),
          'nome': _nomeSabor(
            sabor.nome,
            sabor.codigo,
            sabor.imprimirCodigoProdutoPreparo,
            sabor.quantimaximaselecao,
          ),
          'quantimaximaselecao': null,
        };
      }).toList();
    } else if (opcao.id == 6) {
      final bordas = _dadosSelecionadosQuandoMarcados(opcao);
      final meiaBorda = ValoresPizza.bordaSomenteMetade(bordas);
      dados['titulo'] = meiaBorda
          ? 'Bordas - MEIA PIZZA (${bordas.length})'
          : 'Bordas (${bordas.length})';
      dados['dados'] = bordas.map((borda) {
        return {
          ...borda.toMap(),
          'nome': _nomeBordaPreparo(borda, bordas.length),
          'quantimaximaselecao': null,
        };
      }).toList();
    } else if (opcao.id == 7) {
      dados['titulo'] = 'Adicionais';
    }
    return dados;
  }

  static List<ModeloDadosOpcoesPacotes> _dadosSelecionadosQuandoMarcados(
    ModeloOpcoesPacotes opcao,
  ) {
    final dados = opcao.dados ?? [];
    final temMarcacaoSelecao =
        dados.any((dado) => dado.estaSelecionado != null);
    if (!temMarcacaoSelecao) return dados;
    return dados.where((dado) => dado.estaSelecionado == true).toList();
  }

  static String _nomeBordaPreparo(
    ModeloDadosOpcoesPacotes borda,
    int totalBordas,
  ) {
    final nome = ValoresPizza.nomeBordaDetalhada(borda, totalBordas);
    if (!borda.somenteMetadeBorda) return nome;

    final nomeLimpo = nome.trimLeft();
    if (nomeLimpo.toUpperCase().startsWith('MEIA BORDA - ')) return nome;

    return 'MEIA BORDA - ${nomeLimpo.replaceFirst(_meioBordaNoInicio, '')}';
  }
}
