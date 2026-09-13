import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';

import 'abertura_falada.dart';
import 'pedido_falado.dart';
import 'servico_pedido_voz.dart';

class ServicoAberturaVoz {
  final ServicoComandas comandas;
  final ServicoMesas mesas;
  final Sincronizador sincronizador;
  final ServicoPedidoVoz voz;
  final Future<void> Function() validarSessao;
  bool _solicitada = false;

  ServicoAberturaVoz(
      {required this.comandas,
      required this.mesas,
      required this.sincronizador,
      required this.voz,
      required this.validarSessao});

  Future<String> abrir(AberturaFalada abertura) async {
    if (_solicitada) {
      throw const FalhaPedidoVoz(
          'Esta abertura ja foi solicitada. Confira a sincronizacao.');
    }
    _solicitada = true;
    await validarSessao();
    String idMesa = '0', idComanda = '0', idCliente = '0';
    if (abertura.tipo == TipoAberturaVoz.comanda) {
      final lista = await comandas.listar('');
      await validarSessao();
      final comanda = encontrarNumeroAtendimento(
          lista.expand((g) => g.comandas ?? []),
          abertura.numero,
          TipoAberturaVoz.comanda,
          (c) => c.nome);
      if (comanda.ativo != 'Sim' ||
          comanda.comandaOcupada ||
          comanda.fechamento == true) {
        throw const FalhaPedidoVoz(
            'Esta comanda nao esta livre. Nenhum atendimento foi alterado.');
      }
      idComanda = comanda.id;
    }
    if (abertura.tipo == TipoAberturaVoz.mesa ||
        abertura.mesaVinculada.isNotEmpty) {
      final lista = await mesas.listar('');
      await validarSessao();
      final mesa = encontrarNumeroAtendimento(
          lista.expand((g) => g.mesas ?? []),
          abertura.tipo == TipoAberturaVoz.mesa
              ? abertura.numero
              : abertura.mesaVinculada,
          TipoAberturaVoz.mesa,
          (m) => m.nome);
      if (mesa.ativo != 'Sim' || mesa.mesaOcupada || mesa.fechamento == true) {
        throw const FalhaPedidoVoz(
            'Esta mesa nao esta livre. Nenhum atendimento foi alterado.');
      }
      idMesa = mesa.id;
    }
    if (abertura.clienteCadastrado.isNotEmpty) {
      idCliente =
          await voz.localizarClienteCadastrado(abertura.clienteCadastrado);
      await validarSessao();
    }
    if (!await sincronizador.prepararAberturasOffline()) {
      throw const FalhaPedidoVoz(
          'Atualize a sincronizacao do servidor antes de abrir por voz.');
    }
    await validarSessao();
    // A fila valida a versao dos recursos e impede reutilizar outra abertura.
    return sincronizador.abrirAtendimento(
        tipo: abertura.tipo.name,
        idMesa: idMesa,
        idComanda: idComanda,
        idCliente: idCliente,
        obs: abertura.observacao);
  }
}
