import 'package:flutter/material.dart';

import '../../essencial/api/conexao.dart';
import '../../essencial/provedores/usuario/usuario_provedor.dart';
import '../cardapio/provedores/provedor_cardapio.dart';
import '../cardapio/provedores/provedor_carrinho.dart';
import 'acao_pedido_voz.dart';
import 'gravador_voz.dart';
import 'pedido_falado.dart';
import 'servico_pedido_voz.dart';

enum RetornoCarrinhoVoz { iniciar }

Future<String?> abrirComandaVoz(
  BuildContext context, {
  required String atendimento,
  required ProvedorCarrinho carrinho,
  required ProvedorCardapio cardapio,
  required UsuarioProvedor usuario,
  Future<void>? pararSolicitado,
  VoidCallback? aoParar,
  VoidCallback? aoIniciarGravacao,
  VoidCallback? aoEncerrarGravacao,
}) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final esperado = carrinho.contexto;
  final identidade = usuario.usuario;
  ServicoPedidoVoz? servico;
  GravadorVoz? gravador;
  var gravando = false;

  void status(String mensagem, {bool erro = false, VoidCallback? acaoParar}) {
    if (!context.mounted) return;
    final mensageiro = ScaffoldMessenger.of(context);
    mensageiro.hideCurrentSnackBar();
    mensageiro.showSnackBar(SnackBar(
      duration: erro ? const Duration(seconds: 5) : const Duration(seconds: 30),
      backgroundColor: erro ? Theme.of(context).colorScheme.error : null,
      content: Row(children: [
        if (!erro) ...[
          const SizedBox.square(
              dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
        ],
        Expanded(child: Text(mensagem)),
      ]),
      showCloseIcon: erro && acaoParar == null,
      action: acaoParar == null
          ? null
          : SnackBarAction(label: 'Parar', onPressed: acaoParar),
    ));
  }

  try {
    if (esperado == null || !esperado.valido) {
      throw const FalhaPedidoVoz(
          'Aguarde a abertura do atendimento e tente novamente.');
    }
    final servidor =
        (await Apis().getConexao().timeout(const Duration(seconds: 5)))
            .servidor;
    if (!context.mounted) return null;
    if (!identical(esperado, carrinho.contexto) ||
        !identical(identidade, usuario.usuario) ||
        ModalRoute.of(context)?.isCurrent != true) {
      throw const FalhaPedidoVoz(
          'O atendimento mudou. Abra o pedido por voz novamente.');
    }

    servico = ServicoPedidoVoz(servidor: servidor, usuario: usuario);
    gravador = GravadorVoz();
    status('Preparando o microfone...');
    await gravador.iniciar();
    gravando = true;
    aoIniciarGravacao?.call();
    status('Ouvindo em $atendimento... Fale e toque em Parar.',
        acaoParar: aoParar);

    late String caminho;
    await Future.wait([
      () async {
        try {
          await gravador!.aguardarFimDaFala(pararSolicitado: pararSolicitado);
        } finally {
          gravando = false;
          aoEncerrarGravacao?.call();
        }
        caminho = await gravador!.concluir();
        status('Entendendo o comando...');
      }(),
      servico.verificar(),
    ]);

    final resultado = await servico.interpretarLote(
      caminho: caminho,
      categoriasDisponiveis: cardapio.categorias,
      configuracaoDisponivel: cardapio.configBigchef,
    );
    if (!context.mounted) return null;
    if (!identical(esperado, carrinho.contexto) ||
        !identical(identidade, usuario.usuario) ||
        ModalRoute.of(context)?.isCurrent != true ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      throw const FalhaPedidoVoz(
          'O atendimento mudou. Faça o pedido por voz novamente.');
    }

    if (resultado.acao == AcaoPedidoVoz.buscar) {
      final termo = resultado.termoBusca?.trim();
      if (termo == null || termo.isEmpty) {
        throw const FalhaPedidoVoz(
            'Não consegui identificar qual produto deve ser buscado.');
      }
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Mostrando resultados para “$termo”.'),
        duration: const Duration(seconds: 3),
      ));
      return termo;
    }

    status('Adicionando ao carrinho...');
    if (!await carrinho.adicionarLoteVoz(resultado.itens, esperado)) {
      throw const FalhaPedidoVoz(
          'Não foi possível adicionar o pedido. Confira o atendimento.');
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${resultado.itens.length} ${resultado.itens.length == 1 ? 'item adicionado' : 'itens adicionados'} ao carrinho.'),
        duration: const Duration(seconds: 3),
      ));
    }
  } catch (erro) {
    status(
        erro is FalhaPedidoVoz
            ? erro.mensagem
            : 'Não foi possível concluir o comando de voz. Confira a conexão.',
        erro: true);
  } finally {
    if (gravando) aoEncerrarGravacao?.call();
    await gravador?.dispose();
    servico?.dispose();
  }
  return null;
}
