import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/foundation.dart';

class ServicoEdicaoPedido {
  final ServicoDelivery servico;
  ServicoEdicaoPedido(this.servico);

  Future<void> salvarProduto(TipoCardapio tipo, String id,
      Modelowordprodutos original, Modelowordprodutos editado) async {
    await servico.salvar('pedidos/editar.php', {
      'tipo': tipo.nome,
      'id': id,
      'acao': 'produto',
      'produto': normalizarProdutoParaEnvio(editado.toMap()),
      'original': normalizarProdutoParaEnvio(original.toMap()),
    });
    if (tipo == TipoCardapio.delivery) {
      try {
        await servico.atualizarDetalheLocal(id, original, editado);
      } catch (erro, pilha) {
        debugPrint(
            '[Delivery] Edicao salva, falha ao atualizar detalhes locais do pedido $id: $erro\n$pilha');
      }
    }
  }

  Future<void> salvarDados(TipoCardapio tipo, PedidoDelivery original,
      Map<String, dynamic> dados) async {
    await servico.salvar('pedidos/editar.php', {
      ...dados,
      'tipo': tipo.nome,
      'id': original.id,
      'acao': 'pedido',
      'clienteOriginal': original.cliente,
      'tipoEntregaOriginal': original.tipoEntrega,
      'enderecoOriginal': original.texto('idendereco', '0'),
      'observacaoOriginal': original.observacao,
      'taxaOriginal': original.taxaEntrega.toStringAsFixed(2),
    });
  }

  static PedidoDelivery pedidoBalcao(
      String id, RetornoListarPorIdBalcao dados) {
    final info = dados.informacoes;
    return PedidoDelivery.fromMap({
      'id': id,
      'numeroPedido': info.numerodopedido,
      'idCliente': info.cliente,
      'nomeCliente': info.nomeCliente,
      'celularCliente': info.celularcliente,
      'tipodeentrega': info.tipodeentrega,
      'idendereco': info.idEndereco,
      'observacaoDoPedido': info.observacaoDoPedido ?? '',
      'valorVenda': info.subtotal,
      'somaValorHistorico': info.valorRecebido,
      'valorDesconto': info.valordodesconto,
      'valorAcrescimo': info.acrescimo,
      'nomeEmpresa': info.nomeempresa,
      'celularEmpresa': info.celularempresa,
      'cnpjEmpresa': info.docempresa,
      'enderecoEmpresa': info.enderecoempresa,
      'enderecoCliente': info.enderecoenderecocliente,
      'numeroCliente': info.numeroenderecocliente,
      'bairroCliente': info.nomebairro,
      'cidadeCliente': info.nomecidade,
      'complementoCliente': info.complementoenderecocliente,
      'produtos': dados.produtos.map((p) => p.toMap()).toList(),
    });
  }

  Future<void> reimprimirBalcao(Server server, PedidoDelivery pedido,
      {bool preparo = true,
      bool comprovante = true,
      ModeloConfigBigchef? configuracao}) async {
    final unificarPreparoNoComprovante = preparo &&
        comprovante &&
        configuracao?.imprimePreparoNoComprovanteConsumacao == true;
    final mensagens = [
      if (preparo && !unificarPreparoNoComprovante)
        ...Impressao.prepararComprovanteDePedido(
            produtos: pedido.produtos,
            tipoTela: TipoCardapio.balcao,
            tipodeentrega: pedido.tipoEntrega,
            nomeCliente: pedido.nome,
            nomeEmpresa: pedido.texto('nomeEmpresa'),
            comanda: 'Balcão ${pedido.id}',
            numeroPedido: pedido.numero),
      if (comprovante)
        ...ImpressaoDelivery.comprovantes(servico, pedido, pedido.produtos,
            tipo: TipoCardapio.balcao),
    ];
    await server.enviarImpressoes(mensagens);
  }
}
