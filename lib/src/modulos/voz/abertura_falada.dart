import 'falha_pedido_voz.dart';

enum TipoAberturaVoz { mesa, comanda }

class AberturaFalada {
  final TipoAberturaVoz tipo;
  final String numero;
  final String mesaVinculada;
  final String observacao;
  final String clienteCadastrado;

  const AberturaFalada._(this.tipo, this.numero, this.mesaVinculada,
      this.observacao, this.clienteCadastrado);

  factory AberturaFalada.fromMap(Map dados, TipoAberturaVoz esperado) {
    String campo(String chave, int limite) {
      final valor = dados[chave];
      if (valor is! String || valor.length > limite) {
        throw const FalhaPedidoVoz(
            'A abertura ficou incompleta. Grave novamente.');
      }
      return valor.trim();
    }

    final esclarecimento = campo('esclarecimento', 500);
    if (esclarecimento.isNotEmpty) throw FalhaPedidoVoz(esclarecimento);
    if (dados['acao'] != 'abrir' || dados['tipo'] != esperado.name) {
      throw FalhaPedidoVoz(
          'Nesta tela, solicite a abertura de uma ${esperado.name}.');
    }
    final numero = campo('numero', 9);
    final mesa = campo('mesa_vinculada', 9);
    bool numeroValido(String valor) =>
        RegExp(r'^\d{1,9}$').hasMatch(valor) && int.parse(valor) > 0;
    if (!numeroValido(numero) || (mesa.isNotEmpty && !numeroValido(mesa))) {
      throw const FalhaPedidoVoz(
          'Informe um unico numero para abrir o atendimento.');
    }
    if (esperado == TipoAberturaVoz.mesa && mesa.isNotEmpty) {
      throw const FalhaPedidoVoz(
          'Uma mesa nao pode ser vinculada a outra mesa.');
    }
    final observacao = campo('observacao', 500);
    if (observacao.runes.length > 100) {
      throw const FalhaPedidoVoz(
          'Nome e observacao devem ter ate 100 caracteres. Grave uma versao mais curta.');
    }
    return AberturaFalada._(
        esperado, numero, mesa, observacao, campo('cliente_cadastrado', 200));
  }
}

T encontrarNumeroAtendimento<T>(Iterable<T> itens, String numero,
    TipoAberturaVoz tipo, String Function(T) nome) {
  final esperado = int.parse(numero);
  final padrao = RegExp('^(?:${tipo.name}\\s*:?\\s*)?(\\d+)\$');
  final encontrados = itens.where((item) {
    final texto = nome(item).trim().toLowerCase();
    final match = padrao.firstMatch(texto);
    return match != null && int.tryParse(match.group(1)!) == esperado;
  }).toList();
  if (encontrados.length != 1) {
    throw FalhaPedidoVoz(encontrados.isEmpty
        ? 'Nao encontrei ${tipo.name} $numero. Confira o numero.'
        : 'Ha mais de uma ${tipo.name} com esse numero. Use a selecao manual.');
  }
  return encontrados.single;
}
