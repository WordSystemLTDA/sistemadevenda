import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:shared_preferences/shared_preferences.dart';

bool clientePossuiCelularDelivery(String celular) {
  final valor = celular.trim();
  if (valor.isEmpty || valor.toLowerCase().contains('sem celular')) {
    return false;
  }
  return valor.replaceAll(RegExp(r'\D'), '').length >= 8;
}

Future<void> enviarMensagensAutomaticasDelivery({
  required ServicoDelivery servico,
  required String idDelivery,
  required String celularCliente,
  required String tipoEntrega,
  required bool possuiEndereco,
  required Set<MensagemClienteDelivery> mensagensHabilitadas,
  void Function(
    MensagemClienteDelivery mensagem,
    Object erro,
    StackTrace pilha,
  )? aoFalhar,
}) async {
  if (!clientePossuiCelularDelivery(celularCliente) || idDelivery.isEmpty) {
    return;
  }
  final mensagens = <MensagemClienteDelivery>[
    if (mensagensHabilitadas.contains(
          MensagemClienteDelivery.confirmarEndereco,
        ) &&
        tipoEntrega == '1' &&
        possuiEndereco)
      MensagemClienteDelivery.confirmarEndereco,
    if (mensagensHabilitadas.contains(
      MensagemClienteDelivery.formaPagamento,
    ))
      MensagemClienteDelivery.formaPagamento,
    if (mensagensHabilitadas.contains(
      MensagemClienteDelivery.oferecerBebida,
    ))
      MensagemClienteDelivery.oferecerBebida,
    if (mensagensHabilitadas.contains(MensagemClienteDelivery.algoMais))
      MensagemClienteDelivery.algoMais,
  ];
  for (final mensagem in mensagens) {
    try {
      await servico.notificarCliente(mensagem, idDelivery: idDelivery);
    } catch (erro, pilha) {
      aoFalhar?.call(mensagem, erro, pilha);
    }
  }
}

class PreferenciaMensagensDelivery {
  static const chave = 'delivery_mensagens_whatsapp_automaticas_v2';

  Future<Set<MensagemClienteDelivery>> carregar() async {
    final codigos =
        (await SharedPreferences.getInstance()).getStringList(chave) ?? [];
    return MensagemClienteDelivery.values
        .where((mensagem) => codigos.contains(mensagem.codigo))
        .where((mensagem) => mensagem != MensagemClienteDelivery.perguntarTroco)
        .toSet();
  }

  Future<void> salvar(Set<MensagemClienteDelivery> mensagens) async {
    final preferencias = await SharedPreferences.getInstance();
    final codigos = mensagens.map((mensagem) => mensagem.codigo).toList()
      ..sort();
    if (!await preferencias.setStringList(chave, codigos)) {
      throw StateError('Não foi possível salvar a preferência no aparelho.');
    }
  }
}
