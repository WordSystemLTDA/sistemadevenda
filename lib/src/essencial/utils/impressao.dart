import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class Impressao {
  static void enviarImpressao(String? idComanda, String? idMesa) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://localhost:9980/chat'),
    );

    await channel.ready.then((_) {
      channel.stream.listen((message) {
        var data = {
          'idComanda': idComanda,
          'idMesa': idMesa,
        };

        channel.sink.add(jsonEncode(data));
        channel.sink.close();
      });
    });
  }
}
