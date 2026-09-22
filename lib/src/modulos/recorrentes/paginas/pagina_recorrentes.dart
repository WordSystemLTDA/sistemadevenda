import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import '../provedores/provedor_recorrentes.dart';
import '../servicos/servicos_recorrentes.dart';
import 'widgets/agenda_recorrentes.dart';

class PaginaRecorrentes extends StatefulWidget {
  const PaginaRecorrentes({super.key});
  @override
  State<PaginaRecorrentes> createState() => _PaginaRecorrentesState();
}

class _PaginaRecorrentesState extends State<PaginaRecorrentes> {
  late final provedor = ProvedorRecorrentes(Modular.get<ServicosRecorrentes>());
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
        editarItens: (item) async {
          if (item.idDeliveryBase.isEmpty || item.idDeliveryBase == '0') {
            throw StateError('O modelo desta recorrência não está disponível.');
          }
          await Navigator.push<void>(
              context,
              MaterialPageRoute(
                  builder: (_) => PaginaDetalhesDelivery(
                      servico: delivery,
                      id: item.idDeliveryBase,
                      modeloRecorrente: true)));
        },
        abrirPedido: (id, item) async {
          await Navigator.push<void>(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      PaginaDetalhesDelivery(servico: delivery, id: id)));
        },
        imprimirPedido: (id, item) async {
          final pedido = await delivery.pedido(id);
          await ImpressaoDelivery.imprimir(
              delivery, Modular.get<Server>(), pedido);
        },
      );
}
