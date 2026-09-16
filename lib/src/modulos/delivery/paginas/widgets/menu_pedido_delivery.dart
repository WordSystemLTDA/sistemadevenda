import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:flutter/material.dart';

enum AcaoPedidoDelivery {
  editar,
  produtos,
  pedido,
  clonarCompleto,
  clonarParcial,
  clonarSemCliente,
  mensagem1,
  mensagem2,
  mensagem3,
  pix,
  endereco,
  retirada,
  confirmar,
  receber,
  pagamento,
  entrega,
  conta,
  preparo,
  venda,
  nfce,
  nfe,
  nota,
  xml,
  enviarNota,
  cancelar,
}

Future<AcaoPedidoDelivery?> mostrarMenuPedidoDelivery(
    BuildContext context, PedidoDelivery pedido, EtapaDelivery etapa) {
  final fiscal = (int.tryParse(pedido.texto('idVenda')) ?? 0) > 0;
  final nota = ['Autorizada', 'Autorizada (CCE)', 'Cancelada']
          .contains(pedido.texto('statusSefaz')) &&
      pedido.texto('tipodemodulo') != '1';
  final grupos = <(String, List<(AcaoPedidoDelivery, String, IconData)>)>[
    (
      'Pedido',
      [
        if (pedido.podeAvancar(etapa))
          (
            AcaoPedidoDelivery.editar,
            'Editar Pedido',
            Icons.edit_note_outlined
          ),
        if (pedido.quantidade > 0)
          (
            AcaoPedidoDelivery.produtos,
            'Ver Produtos',
            Icons.inventory_2_outlined
          ),
        (AcaoPedidoDelivery.pedido, 'Ver Pedido', Icons.receipt_long_outlined),
      ]
    ),
    (
      'Clone',
      [
        (
          AcaoPedidoDelivery.clonarCompleto,
          'Clonar Completo',
          Icons.copy_all_outlined
        ),
        (
          AcaoPedidoDelivery.clonarParcial,
          'Clonar Parcial',
          Icons.call_split_outlined
        ),
        (
          AcaoPedidoDelivery.clonarSemCliente,
          'Clonar Sem Cliente',
          Icons.person_add_alt_outlined
        ),
      ]
    ),
    (
      'WhatsApp',
      [
        for (final (acao, chave, padrao, icone) in [
          (
            AcaoPedidoDelivery.mensagem1,
            'mensagemDelivery1',
            'Mensagem 1',
            Icons.chat_outlined
          ),
          (
            AcaoPedidoDelivery.mensagem2,
            'mensagemDelivery2',
            'Mensagem 2',
            Icons.mark_chat_read_outlined
          ),
          (
            AcaoPedidoDelivery.mensagem3,
            'mensagemDelivery3',
            'Mensagem 3',
            Icons.sms_outlined
          ),
        ])
          (
            acao,
            pedido.texto(chave).isEmpty ? padrao : pedido.texto(chave),
            icone
          ),
        (AcaoPedidoDelivery.pix, 'Enviar Chave Pix', Icons.pix_outlined),
        (
          AcaoPedidoDelivery.endereco,
          'Confirmar Endereço',
          Icons.location_on_outlined
        ),
        (
          AcaoPedidoDelivery.retirada,
          'Pronto para Retirada',
          Icons.shopping_bag_outlined
        ),
        (
          AcaoPedidoDelivery.confirmar,
          'Confirmar Pedido',
          Icons.task_alt_outlined
        ),
      ]
    ),
    (
      'Financeiro',
      [
        if (pedido.quantidade > 0 && !pedido.encerrado)
          (AcaoPedidoDelivery.receber, 'Concluir', Icons.task_alt_outlined),
        if (pedido.quantidade > 0)
          (
            AcaoPedidoDelivery.pagamento,
            pedido.pago > 0
                ? 'Alterar Forma de Pagamento'
                : 'Mudar Forma de Pagamento',
            Icons.payments_outlined
          ),
        if (pedido.podeAvancar(etapa))
          (
            AcaoPedidoDelivery.entrega,
            'Mudar Tipo de Entrega',
            Icons.delivery_dining_outlined
          ),
      ]
    ),
    (
      'Relatórios',
      [
        (AcaoPedidoDelivery.conta, 'Conta', Icons.print_outlined),
        (
          AcaoPedidoDelivery.preparo,
          'Imprimir Preparo',
          Icons.restaurant_outlined
        ),
      ]
    ),
    if (fiscal)
      (
        'Fiscal',
        [
          (AcaoPedidoDelivery.venda, 'Ver Venda', Icons.info_outline),
          if (!nota) ...[
            (
              AcaoPedidoDelivery.nfce,
              'Emitir NFCe',
              Icons.receipt_long_outlined
            ),
            (AcaoPedidoDelivery.nfe, 'Emitir NFe', Icons.description_outlined),
          ] else ...[
            (AcaoPedidoDelivery.nota, 'Ver Nota', Icons.visibility_outlined),
            (AcaoPedidoDelivery.xml, 'Baixar XML', Icons.download_outlined),
            (
              AcaoPedidoDelivery.enviarNota,
              'Enviar Para Cliente',
              Icons.send_outlined
            ),
          ],
        ]
      ),
    if (!pedido.cancelado)
      (
        'Cancelamento',
        [
          (
            AcaoPedidoDelivery.cancelar,
            'Cancelar Venda',
            Icons.cancel_outlined
          ),
        ]
      ),
  ];
  return showModalBottomSheet<AcaoPedidoDelivery>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      maxChildSize: .95,
      minChildSize: .4,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Pedido #${pedido.numero}',
                  style: Theme.of(context).textTheme.titleLarge),
              subtitle: Text(pedido.nome),
              trailing: IconButton(
                  tooltip: 'Fechar opções',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))),
          for (final grupo in grupos) ...[
            if (grupo.$2.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                  child: Text(grupo.$1,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600))),
            for (final item in grupo.$2)
              ListTile(
                  enabled: ![AcaoPedidoDelivery.nfce, AcaoPedidoDelivery.nfe]
                      .contains(item.$1),
                  leading: Icon(item.$3),
                  title: Text(item.$2),
                  subtitle: [AcaoPedidoDelivery.nfce, AcaoPedidoDelivery.nfe]
                          .contains(item.$1)
                      ? const Text('Integração fiscal pendente')
                      : null,
                  textColor: item.$1 == AcaoPedidoDelivery.cancelar
                      ? Theme.of(context).colorScheme.error
                      : null,
                  iconColor: item.$1 == AcaoPedidoDelivery.cancelar
                      ? Theme.of(context).colorScheme.error
                      : null,
                  onTap: () => Navigator.pop(context, item.$1)),
          ],
        ],
      ),
    ),
  );
}
