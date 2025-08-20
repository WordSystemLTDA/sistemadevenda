// SEU ARQUIVO: server.dart (MODIFICADO)
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Server extends ChangeNotifier {
  WebSocketChannel? channel;

  bool connected = false;
  String nomedopc = '';
  String hostname = '';
  int port = 0;
  bool aparecendoModalReconectar = false;

  // <-- MUDANÇA: Nova flag para controlar o comportamento da reconexão.
  bool _isDisconnectionIntentional = false;

  // <-- MUDANÇA: Método renomeado de 'start' para 'connect'.
  Future<bool> connect(String ip, String porta) async {
    // Se já estamos conectados ao mesmo servidor, não fazemos nada.
    if (connected && hostname == ip && port.toString() == porta) {
      log('Já está conectado ao servidor $ip:$porta');
      return true;
    }

    // <-- MUDANÇA: Marcamos que qualquer desconexão a partir de agora NÃO é intencional.
    _isDisconnectionIntentional = false;

    hostname = ip;
    port = int.parse(porta);

    try {
      final wsUrl = Uri.parse('ws://$ip:$porta');
      channel = WebSocketChannel.connect(wsUrl);

      log('Conectando ao servidor...');
      await channel!.ready;

      connected = true;
      notifyListeners();
      log('Conectado com sucesso ao servidor!');

      // Envia os dados do dispositivo após conectar.
      _sendDeviceInfo();

      channel!.stream.listen(
        (message) {
          onData(message);
        },
        onError: (error) {
          log('WebSocket Erro: $error');
          connected = false;
          notifyListeners();
          _handleReconnection(); // <-- MUDANÇA: Chama o novo handler de reconexão
        },
        onDone: () {
          log('WebSocket Conexão Finalizada (onDone).');
          connected = false;
          notifyListeners();
          _handleReconnection(); // <-- MUDANÇA: Chama o novo handler de reconexão
        },
      );

      return true;
    } catch (e) {
      log('Exceção ao conectar: $e');
      connected = false;
      notifyListeners();
      return false;
    }
  }

  // <-- MUDANÇA: O método disconnect agora é mais simples.
  Future<void> disconnect() async {
    if (channel == null || !connected) return;

    // <-- MUDANÇA: Marcamos que ESTA desconexão é intencional.
    _isDisconnectionIntentional = true;

    log('Desconectando intencionalmente...');
    await channel!.sink.close();
    channel = null;
    connected = false;
    notifyListeners();
  }

  // <-- MUDANÇA: Novo método privado para lidar com a lógica de reconexão.
  void _handleReconnection() async {
    // A MUDANÇA MAIS IMPORTANTE: se a desconexão foi intencional (app em background),
    // simplesmente paramos e não tentamos reconectar.
    if (_isDisconnectionIntentional) {
      log('Reconexão ignorada pois a desconexão foi intencional.');
      return;
    }

    log('Tentando reconectar em 5 segundos...');
    await Future.delayed(const Duration(seconds: 5));

    // Garante que não vamos tentar reconectar se o usuário já pediu para desconectar nesse meio tempo.
    if (_isDisconnectionIntentional) {
      log('Reconexão abortada pois a desconexão se tornou intencional.');
      return;
    }

    final config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (conexao != null) {
      log('Iniciando tentativa de reconexão para ${conexao.servidor}:${conexao.porta}');
      bool sucesso = await connect(conexao.servidor, conexao.porta);
      if (!sucesso && navigatorKey?.currentContext != null && navigatorKey!.currentContext!.mounted) {
        ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(SnackBar(
          content: Text('Falha ao reconectar. Verifique o servidor e a rede.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 5),
        ));
      }
    }
  }

  // <-- MUDANÇA: Extraí a lógica de envio de informações do dispositivo para um método separado.
  void _sendDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String nomedopcLocal = 'Dispositivo Desconhecido';
    String? ip = await ConfigSistema.retornarIPMaquina();

    if (Platform.isAndroid) {
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      nomedopcLocal = androidInfo.model;
    } else if (Platform.isIOS) {
      IosDeviceInfo iosInfo = await deviceInfo.iosInfo;
      nomedopcLocal = iosInfo.name; // Atenção: 'model' pode ser 'iPhone', 'iPad'. use 'name' para o nome dado pelo usuário.
    }

    final message = jsonEncode({
      'tipo': 'Rede',
      'nomedopc': nomedopcLocal,
      'tipodeempresa': '2',
      'nomedosistema': 'Big Chef Garçom',
      "sistemaoperacional": Platform.operatingSystem,
      'ip': ip,
    });

    write(message);
  }

  // O resto da sua classe permanece igual
  bool write(String message) {
    if (channel != null && connected) {
      channel!.sink.add(message);
      return true;
    }
    return false;
  }

  // onData, onError (antigo), imprimir etc... tudo igual
  void onData(dynamic data) async {
    // ... seu código original aqui, sem alterações ...
    try {
      var dados = ModeloRetornoSocket.fromJson(data);

      if (dados.tipo == 'PC') {
        nomedopc = dados.nomedopc ?? '';
        notifyListeners();
        return;
      }
      // ... resto da sua lógica ...
    } catch (e) {
      log('erro em onData', error: e);
    }
    notifyListeners();
  }
}
