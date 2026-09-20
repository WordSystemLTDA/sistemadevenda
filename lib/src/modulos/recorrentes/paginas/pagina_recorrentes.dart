import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import '../provedores/provedor_recorrentes.dart';
import '../servicos/servicos_recorrentes.dart';
import 'widgets/agenda_recorrentes.dart';

class PaginaRecorrentes extends StatefulWidget {
  const PaginaRecorrentes({super.key});
  @override
  State<PaginaRecorrentes> createState() => _PaginaRecorrentesState();
}

class _PaginaRecorrentesState extends State<PaginaRecorrentes> {
  late final provedor = ProvedorRecorrentes(ServicosRecorrentes(
      Modular.get<DioCliente>(), Modular.get<UsuarioProvedor>()));
  ServicoDelivery get delivery => Modular.get<ServicoDelivery>();
  @override
  void dispose() {
    provedor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AgendaRecorrentes(
        provedor: provedor,
        exibirAppBar: true,
        novo: () => Navigator.push<void>(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    PaginaNovoDelivery(servico: delivery, recorrente: true))),
        confirmarPedido: (id, item) async {
          final pago = await receberDelivery(context, delivery, id,
              confirmarRecorrente: true);
          if (pago != true) return;
          final pedido = await delivery.pedido(id);
          if (pedido.restante <= 0.009 && !pedido.encerrado) {
            await delivery.concluir(pedido);
          }
          delivery.notificarPedidoAtualizado(await delivery.pedido(id));
        },
        abrirPedido: (id, item) async {
          final atual = await delivery.pedido(id);
          if (!context.mounted) return;
          await Navigator.push<void>(
              context,
              MaterialPageRoute(
                  builder: (_) => item.encerrado || atual.encerrado
                      ? PaginaDetalhesDelivery(servico: delivery, id: id)
                      : PaginaCardapio(
                          tipo: TipoCardapio.delivery,
                          id: id,
                          idCliente: atual.cliente,
                          tipodeentrega: atual.tipoEntrega,
                          nomeAtendimento: 'Recorrente · ${item.cliente}')));
        },
      );
}
