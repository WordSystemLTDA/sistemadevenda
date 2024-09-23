import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

class Client extends ChangeNotifier {
  String hostname = '';
  int port = 0;
  bool connected = false;
  Socket? socket;

  Future<bool> connect(String hostnameNovo, int portaNova) async {
    try {
      socket = await Socket.connect(hostnameNovo, portaNova);
      socket!.encoding = utf8;
      socket!.listen(
        onData,
        onError: onError,
        onDone: disconnect,
        cancelOnError: false,
      );

      connected = true;
      hostnameNovo = hostname;
      port = portaNova;

      notifyListeners();
      return true;
    } on Exception catch (exception) {
      onData(Uint8List.fromList("Error : $exception".codeUnits));
      return false;
    }
  }

  write(String message) {
    //Connect standard in to the socket
    socket!.write(message);
  }

  disconnect() {
    // write('Desconectado');
    socket!.destroy();
    connected = false;
  }

  void onData(Uint8List d) {}

  void onError(dynamic d) {}
}
