/// Copias de preparo na rede; nunca autoriza gravacoes ou recebimentos na API.
class ProtocoloPedidosRede {
  static const versao = 1;
  static const anuncio = 'CanalPedidosRede';
  static const pedido = 'PedidoRedeSemInternet';
  static const confirmacao = 'ConfirmarPedidoRede';
  static const resposta = 'RespostaPedidoRede';
  static const prepararDelivery = 'PrepararDeliveryRede';
  static const consultar = 'ConsultarPedidoRede';
  static String chaveRota(String alvo, String id) =>
      'rota-pedido-rede:$alvo:$id';

  static bool executorValido(Object? valor) =>
      RegExp(r'^preparo-[a-f0-9]{32}$').hasMatch('${valor ?? ''}');

  static bool operacaoValida(Object? valor) =>
      RegExp(r'^[a-f0-9]{48}$').hasMatch('${valor ?? ''}');

  static Map<String, dynamic>? mensagem(
      Map<String, dynamic> dados, String escopo,
      {required bool aceitarResposta}) {
    if (dados['protocoloPedidoRede'] != versao ||
        dados['idEmpresa']?.toString() != escopo.split('|').last) {
      return null;
    }
    final tipo = dados['tipo'];
    if (tipo == anuncio) {
      return aceitarResposta && executorValido(dados['executorImpressaoRede'])
          ? dados
          : null;
    }
    if (!operacaoValida(dados['idOperacaoRede'])) return null;
    if (tipo == resposta) return aceitarResposta ? dados : null;
    if (tipo == pedido ||
        tipo == confirmacao ||
        tipo == prepararDelivery ||
        tipo == consultar) {
      return dados;
    }
    return null;
  }
}
