import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class DadosImpressaoPreparo {
  static String _nome(String nome, String? codigo, String imprimirCodigo) {
    final codigoProduto = codigo?.trim() ?? '';
    if (imprimirCodigo != 'Sim' || codigoProduto.isEmpty) return nome;

    final prefixo = '$codigoProduto - ';
    return nome.startsWith(prefixo) ? nome : '$prefixo$nome';
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
    dados['opcoesPacotes'] = produto.opcoesPacotes?.map(_opcao).toList();
    dados['opcoesPacotesListaFinal'] =
        produto.opcoesPacotesListaFinal?.map(_opcao).toList();
    return dados;
  }

  static Map<String, dynamic> _opcao(ModeloOpcoesPacotes opcao) {
    final dados = opcao.toMap();
    dados['produtos'] = opcao.produtos?.map(produto).toList();
    dados['opcoesPacote'] = opcao.opcoesPacote?.map(_opcao).toList();
    if (opcao.id == 10) {
      dados['dados'] = opcao.dados?.map((sabor) {
        return {
          ...sabor.toMap(),
          'nome': _nome(
            sabor.nome,
            sabor.codigo,
            sabor.imprimirCodigoProdutoPreparo,
          ),
        };
      }).toList();
    }
    return dados;
  }
}
