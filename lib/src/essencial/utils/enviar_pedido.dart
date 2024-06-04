import 'package:web_socket_channel/web_socket_channel.dart';

class EnviarPedido {
  static void enviarPedido(String? idComanda, String? idMesa) async {
    final channel = WebSocketChannel.connect(
      Uri.parse('ws://192.168.2.107:9980/chat'),
    );

    await channel.ready.then((_) {
      channel.sink.add('Atualizou');
      channel.sink.close();
    }).onError((error, stackTrace) {
      // print('Erro ao conectar ao PHP');
    });
  }
}
