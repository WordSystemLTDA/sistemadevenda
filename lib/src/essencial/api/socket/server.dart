import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/essencial/api/socket/modelos.dart';

class Server {
  Uint8ListCallback onData;
  DynamicCallback onError;
  Server({required this.onError, required this.onData});

  ServerSocket? server;
  bool running = false;
  List<Socket> sockets = [];

  start() async {
    runZoned(() async {
      server = await ServerSocket.bind('192.168.2.115', 9980);
      running = true;
      server!.listen(onRequest, onDone: () => server!.close());
      onData(Uint8List.fromList('Server listening on port 9980'.codeUnits));
    });
  }

  stop() async {
    await server!.close();
    server = null;
    running = false;
  }

  broadCast(String message) {
    onData(Uint8List.fromList('Broadcasting : $message'.codeUnits));
    for (Socket socket in sockets) {
      socket.write('$message\n');
    }
  }

  onRequest(Socket socket) {
    if (!sockets.contains(socket)) {
      sockets.add(socket);
    }

    socket.listen((Uint8List data) {
      onData(data);
    });
  }
}
