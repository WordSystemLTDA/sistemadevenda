import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

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
    if (socket == null) return;
    //Connect standard in to the socket
    socket!.write(message);
  }

  disconnect() {
    if (socket == null) return;
    // write('Desconectado');
    socket!.destroy();
    connected = false;
  }

  void onData(Uint8List d) async {
    var tipo = utf8.decode(d);
    print(tipo);

    if (tipo == 'Comanda') {
      final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
      await provedorComanda.listarComandas('');
    } else if (tipo == 'Mesa') {
      print('foi?');
      final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
      await provedorMesas.listarMesas('');
    }
  }

  void onError(dynamic d) {}
}
