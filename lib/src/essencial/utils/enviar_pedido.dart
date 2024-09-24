import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/socket/client.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:flutter_modular/flutter_modular.dart';

class EnviarPedido {
  static void enviarPedido(String nomeTitulo, String numeroPedido, String nomeCliente, String nomeEmpresa, List<ModeloProduto> produtosNovos) async {
    var cliente = Modular.get<Client>();

    if (cliente.connected == false) {
      await cliente.connect('192.168.2.115', 9980).then((value) {
        if (value) {
          log('conectou');
        } else {
          log('não conectou');
        }
      });
    }

    log('mandou mensagem');
    cliente.write(jsonEncode({
      'nomeTitulo': nomeTitulo,
      'numeroPedido': numeroPedido,
      'nomeCliente': nomeCliente,
      'nomeEmpresa': nomeEmpresa,
      'produtosNovos': produtosNovos.toList(),
    }));

    cliente.disconnect();

    // final channel = WebSocketChannel.connect(
    //   Uri.parse('ws://192.168.2.115:9980/'),
    // );

    // await channel.ready.then((_) {
    //   channel.sink.add('Atualizou');
    //   channel.sink.close();
    // }).onError((error, stackTrace) {
    //   print('Erro ao conectar ao PHP');
    // });
  }
}
