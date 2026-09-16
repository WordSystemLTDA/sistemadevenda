import 'dart:convert';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';

class ImpressaoDelivery {
  static Future<void> imprimir(
      ServicoDelivery servico, Server server, PedidoDelivery pedido,
      {bool preparo = false}) async {
    final dados = await servico.dadosCardapio(pedido.id);
    final produtos = dados.produtos ?? <Modelowordprodutos>[];
    if (produtos.isEmpty) {
      throw StateError('O pedido não tem produtos para impressão.');
    }
    final mensagens = preparo
        ? Impressao.prepararComprovanteDePedido(
            produtos: produtos,
            tipoTela: TipoCardapio.delivery,
            tipodeentrega: pedido.tipoEntrega,
            nomeCliente: pedido.nome,
            nomeEmpresa: dados.nomeEmpresa ?? '',
            comanda: 'Delivery ${pedido.id}',
            numeroPedido: pedido.numero)
        : comprovantes(servico, pedido.comEndereco(dados), produtos);
    await server.enviarImpressoes(mensagens);
  }

  static List<String> comprovantes(ServicoDelivery servico,
      PedidoDelivery pedido, List<Modelowordprodutos> produtos) {
    final grupos = <String, List<Modelowordprodutos>>{};
    for (final p in produtos) {
      final computador = p.destinoDeImpressao?.nomedopc ?? '';
      grupos.putIfAbsent(computador, () => []).add(p);
    }
    final usuario = servico.usuario.usuario;
    return [
      for (final grupo in grupos.entries)
        jsonEncode({
          'idRequisicao':
              'delivery-${pedido.id}-${DateTime.now().microsecondsSinceEpoch}-${grupo.key}',
          'tipo': 'Delivery',
          'tipoImpressao': pedido.tipoEntrega == '1' ? '3' : '2',
          'nomedopc': grupo.key,
          'nomeConexao': usuario?.nome ?? '',
          'produtos': grupo.value.map((p) => p.toMap()).toList(),
          'nomelancamento': pedido.pagamentos,
          'somaValorHistorico': pedido.pago.toStringAsFixed(2),
          for (final campo in [
            'celularEmpresa',
            'cnpjEmpresa',
            'enderecoEmpresa',
            'nomeEmpresa',
            'celularCliente',
            'enderecoCliente',
            'numeroCliente',
            'bairroCliente',
            'complementoCliente',
            'cidadeCliente'
          ])
            campo: pedido.texto(campo),
          'total': pedido.total.toStringAsFixed(2),
          'permanencia': '',
          'valorentrega': pedido.texto('valordaentrega', '0'),
          'numeroPedido': pedido.numero,
          'tipodeentrega': pedido.tipoEntrega,
          'nomeCliente': pedido.nome,
          'valortroco': pedido.texto('valortroco', '0'),
          'observacaoDoPedido': pedido.observacao,
          'valordesconto': pedido.texto('valorDesconto', '0'),
          'valoracrescimo': pedido.texto('valorAcrescimo', '0'),
          'nomeUsuario': usuario?.nome ?? '',
          'idEmpresa': usuario?.empresa ?? '',
          'idUsuario': usuario?.id ?? '',
          'enviarDeVolta': true,
        })
    ];
  }
}
