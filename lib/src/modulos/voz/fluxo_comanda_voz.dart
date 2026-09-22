import 'package:flutter/material.dart';
import '../../essencial/api/conexao.dart';
import '../../essencial/provedores/usuario/usuario_provedor.dart';
import '../cardapio/provedores/provedor_carrinho.dart';
import 'dialogo_comanda_voz.dart';
import 'gravador_voz.dart';
import 'lote_pedido_voz.dart';
import 'pedido_falado.dart';
import 'servico_pedido_voz.dart';

Future<void> abrirComandaVoz(
  BuildContext context, {
  required String atendimento,
  required ProvedorCarrinho carrinho,
  required UsuarioProvedor usuario,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final esperado = carrinho.contexto;
  final identidade = usuario.usuario;
  try {
    if (esperado == null || !esperado.valido) {
      throw const FalhaPedidoVoz(
          'Aguarde a abertura do atendimento e tente novamente.');
    }
    final servidor =
        (await Apis().getConexao().timeout(const Duration(seconds: 5)))
            .servidor;
    if (!context.mounted) return;
    if (!identical(esperado, carrinho.contexto) ||
        !identical(identidade, usuario.usuario) ||
        ModalRoute.of(context)?.isCurrent != true) {
      throw const FalhaPedidoVoz(
          'O atendimento mudou. Abra o pedido por voz novamente.');
    }
    final servico = ServicoPedidoVoz(servidor: servidor, usuario: usuario);
    final gravador = GravadorVoz();
    final resultado = await showDialog<LotePedidoVoz>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DialogoComandaVoz(
            atendimento: atendimento, servico: servico, gravador: gravador));
    if (!context.mounted || resultado == null) return;
    final servidorAtual =
        (await Apis().getConexao().timeout(const Duration(seconds: 5)))
            .servidor;
    if (!context.mounted) return;
    if (!identical(esperado, carrinho.contexto) ||
        !identical(identidade, usuario.usuario) ||
        servidorAtual != servidor ||
        ModalRoute.of(context)?.isCurrent != true) {
      throw const FalhaPedidoVoz(
          'O atendimento ou a conexão mudou. Abra o pedido por voz novamente.');
    }
    if (!await carrinho.adicionarLoteVoz(resultado.itens, esperado)) {
      throw const FalhaPedidoVoz(
          'Não foi possível adicionar o pedido. Confira o atendimento.');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${resultado.itens.length} ${resultado.itens.length == 1 ? 'item adicionado' : 'itens adicionados'} ao carrinho. Confira e finalize para enviar.'),
          showCloseIcon: true));
    }
  } catch (erro) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(erro is FalhaPedidoVoz
              ? erro.mensagem
              : 'Não foi possível abrir o pedido por voz. Confira a conexão.'),
          showCloseIcon: true));
    }
  }
}
