import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'canal_atualizacao_online.dart';

typedef ServidorAtualizacaoOnline = ({String ip, int porta, String nome});

/// A descoberta encontra apenas PCs que anunciam a mesma empresa/API online.
/// O IP escolhido e somente do socket; a configuracao da API nunca e alterada.
class DescobertaAtualizacaoOnline {
  static ServidorAtualizacaoOnline? selecionar(
    Iterable<Map<String, dynamic>> respostas, {
    required String escopo,
    String ipPreferencial = '',
  }) {
    final encontrados = <String, ServidorAtualizacaoOnline>{};
    for (final resposta in respostas) {
      final capacidades = resposta['capabilities'];
      if (capacidades is! Map ||
          capacidades[CanalAtualizacaoOnline.chaveEscopo] != escopo ||
          capacidades['somente_atualizacao'] != true) {
        continue;
      }
      final ip = (resposta['ipAddress'] ?? '').toString();
      final porta =
          int.tryParse((resposta['webSocketPort'] ?? '').toString()) ?? 0;
      if (InternetAddress.tryParse(ip)?.type != InternetAddressType.IPv4 ||
          porta <= 0 ||
          porta > 65535) {
        continue;
      }
      encontrados['$ip:$porta'] = (
        ip: ip,
        porta: porta,
        nome: (resposta['name'] ?? '').toString(),
      );
    }
    final preferidos =
        encontrados.values.where((s) => s.ip == ipPreferencial).toList();
    if (preferidos.length == 1) return preferidos.single;
    return encontrados.length == 1 ? encontrados.values.single : null;
  }

  Future<ServidorAtualizacaoOnline?> descobrir({
    required String escopo,
    String ipPreferencial = '',
    int portaDescoberta = 9982,
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.broadcastEnabled = true;
    final respostas = <Map<String, dynamic>>[];
    Timer? retentativa;
    final assinatura = socket.listen((evento) {
      if (evento != RawSocketEvent.read) return;
      final datagrama = socket.receive();
      if (datagrama == null) return;
      try {
        final resposta = jsonDecode(utf8.decode(datagrama.data));
        if (resposta is Map &&
            resposta['type'] ==
                'discover_sistemarestaurante_server_response_v1' &&
            resposta['payload'] is Map) {
          respostas.add(Map<String, dynamic>.from(resposta['payload'] as Map));
        }
      } catch (_) {
        // Datagramas de outros servicos nao pertencem a descoberta.
      }
    });
    try {
      final destinos = <String>{};
      if (InternetAddress.tryParse(ipPreferencial)?.type ==
          InternetAddressType.IPv4) {
        destinos.add(ipPreferencial);
      }
      destinos.add('255.255.255.255');
      for (final interface in await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false)) {
        for (final endereco in interface.addresses) {
          final partes = endereco.address.split('.');
          if (partes.length == 4) {
            destinos.add('${partes.take(3).join('.')}.255');
          }
        }
      }
      final requisicao = utf8.encode(jsonEncode({
        'type': 'discover_sistemarestaurante_server_v1',
        'requesterMetadata': {CanalAtualizacaoOnline.chaveEscopo: escopo},
      }));
      void enviarConsulta() {
        for (final destino in destinos) {
          try {
            socket.send(requisicao, InternetAddress(destino), portaDescoberta);
          } on SocketException {
            // Uma interface sem rota nao impede as consultas nas outras redes.
          }
        }
      }

      enviarConsulta();
      // UDP nao confirma entrega; repetir cobre a perda do primeiro datagrama.
      retentativa = Timer.periodic(
          const Duration(milliseconds: 200), (_) => enviarConsulta());
      await Future<void>.delayed(timeout);
      return selecionar(respostas,
          escopo: escopo, ipPreferencial: ipPreferencial);
    } finally {
      retentativa?.cancel();
      await assinatura.cancel();
      socket.close();
    }
  }
}
