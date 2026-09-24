import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';
import 'alterar_pedido_delivery.dart';
import 'menu_pedido_delivery.dart';
import 'pagamento_delivery.dart';
import 'texto_acao_delivery.dart';

Future<bool> confirmarAcaoDelivery(BuildContext context, String titulo,
        String texto, String botao) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(botao)),
        ],
      ),
    ) ==
    true;

Future<String?> executarAcaoDelivery(
    BuildContext context,
    ServicoDelivery servico,
    PedidoDelivery pedido,
    AcaoPedidoDelivery acao) async {
  switch (acao) {
    case AcaoPedidoDelivery.editar:
    case AcaoPedidoDelivery.produtos:
    case AcaoPedidoDelivery.pedido:
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaDetalhesDelivery(
                  servico: servico,
                  id: pedido.id,
                  editar: acao == AcaoPedidoDelivery.editar)));
    case AcaoPedidoDelivery.clonarCompleto:
      if (!await confirmarAcaoDelivery(
          context,
          'Clonar pedido',
          'Criar um novo pedido com o cliente, endereço e produtos do pedido #${pedido.numero}? Os pagamentos não serão copiados.',
          'Clonar')) {
        return null;
      }
      await servico.acao(acao.name, pedido, {'idDelivery': pedido.id});
      return null;
    case AcaoPedidoDelivery.clonarParcial:
    case AcaoPedidoDelivery.clonarSemCliente:
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaNovoDelivery(
                  servico: servico,
                  clonar: pedido,
                  semCliente: acao == AcaoPedidoDelivery.clonarSemCliente)));
    case AcaoPedidoDelivery.mensagem1:
    case AcaoPedidoDelivery.mensagem2:
    case AcaoPedidoDelivery.mensagem3:
    case AcaoPedidoDelivery.pix:
    case AcaoPedidoDelivery.endereco:
    case AcaoPedidoDelivery.retirada:
    case AcaoPedidoDelivery.confirmar:
      if (!await confirmarAcaoDelivery(
          context,
          'Enviar WhatsApp',
          'Enviar a mensagem para ${pedido.nome}, referente ao pedido #${pedido.numero}?',
          'Enviar')) {
        return null;
      }
      if (acao == AcaoPedidoDelivery.confirmar) {
        await servico.notificarConfirmacaoPedido(pedido);
      } else {
        await servico.acao(acao.name, pedido);
      }
      return null;
    case AcaoPedidoDelivery.receber:
      final recebeu = pedido.restante <= .009 ||
          await receberDelivery(context, servico, pedido.id) == true;
      if (recebeu) {
        final atualizado = await servico.pedido(pedido.id);
        if (atualizado.restante <= .009 && !atualizado.encerrado) {
          await servico.concluir(atualizado);
        }
      }
    case AcaoPedidoDelivery.pagamento:
      if (pedido.pago <= .009) {
        await receberDelivery(context, servico, pedido.id);
      } else {
        await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlterarPedidoDelivery(
                servico: servico,
                pedido: pedido,
                alteracao: AlteracaoDelivery.pagamento));
      }
    case AcaoPedidoDelivery.entrega:
    case AcaoPedidoDelivery.cancelar:
      final mudou = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlterarPedidoDelivery(
              servico: servico,
              pedido: pedido,
              alteracao: acao == AcaoPedidoDelivery.entrega
                  ? AlteracaoDelivery.entrega
                  : AlteracaoDelivery.cancelar));
      if (mudou == true) {
        return null;
      }
    case AcaoPedidoDelivery.conta:
    case AcaoPedidoDelivery.preparo:
      await ImpressaoDelivery.imprimir(servico, Modular.get<Server>(), pedido,
          preparo: acao == AcaoPedidoDelivery.preparo);
      return null;
    case AcaoPedidoDelivery.venda:
      final res = await servico.acao('venda', pedido);
      if (!context.mounted) return null;
      final dados = Map<String, dynamic>.from(res['dados']['venda'] as Map);
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                scrollable: true,
                title: Text('Venda #${dados['id'] ?? ''}'),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final (campo, nome) in [
                        ('status', 'Situação'),
                        ('valor', 'Total'),
                        ('desconto', 'Desconto'),
                        ('acrescimo', 'Acréscimo'),
                        ('data_lanc', 'Data')
                      ])
                        if (dados[campo] != null)
                          Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Text('$nome: ${dados[campo]}'))
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Fechar'))
                ],
              ));
    case AcaoPedidoDelivery.nota:
    case AcaoPedidoDelivery.xml:
      final url = await servico.documentoFiscal(pedido,
          xml: acao == AcaoPedidoDelivery.xml);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw StateError('Não foi possível abrir o documento.');
      }
    case AcaoPedidoDelivery.enviarNota:
      final telefone = await showDialog<String>(
          context: context,
          builder: (_) => TextoAcaoDelivery(
              titulo: 'Enviar nota fiscal',
              rotulo: 'WhatsApp com DDD',
              inicial: pedido.texto('celularCliente')));
      if (telefone == null || telefone.isEmpty) return null;
      await servico.acao('enviarNota', pedido, {
        'id_empresa': servico.usuario.usuario?.empresa,
        'id_venda': pedido.texto('idVenda'),
        'celular': telefone.replaceAll(RegExp(r'\D'), ''),
      });
      return null;
    case AcaoPedidoDelivery.nfce:
    case AcaoPedidoDelivery.nfe:
      return null;
  }
  return null;
}
