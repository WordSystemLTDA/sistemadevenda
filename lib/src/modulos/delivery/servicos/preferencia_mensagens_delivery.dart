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
    if (tipoEntrega == '1' && possuiEndereco)
      MensagemClienteDelivery.confirmarEndereco,
    MensagemClienteDelivery.formaPagamento,
    MensagemClienteDelivery.oferecerBebida,
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
  static const chave = 'delivery_mensagens_whatsapp_automaticas_v1';

  Future<bool> carregar() async =>
      (await SharedPreferences.getInstance()).getBool(chave) ?? false;

  Future<void> salvar(bool habilitadas) async {
    final preferencias = await SharedPreferences.getInstance();
    if (!await preferencias.setBool(chave, habilitadas)) {
      throw StateError('Não foi possível salvar a preferência no aparelho.');
    }
  }
}
