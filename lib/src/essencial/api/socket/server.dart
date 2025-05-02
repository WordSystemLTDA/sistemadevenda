import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class Server extends ChangeNotifier {
  WebSocketChannel? channel;

  bool connected = false;
  String nomedopc = '';
  String hostname = '';
  int port = 0;
  bool aparecendoModalReconectar = false;

  // BuildContext? contextMesa;
  // BuildContext? contextMesa1;

  // BuildContext? contextComanda;
  // BuildContext? contextComanda1;

  Future<bool> start(String ip, String porta) async {
    if (connected && hostname == ip) {
      return true;
    }

    if (channel != null && hostname != ip) {
      debugPrint('await disconnect();');
      await disconnect();
    }

    bool sucesso = false;
    hostname = ip;
    port = int.parse(porta);
    notifyListeners();

    sucesso = await runZoned(() async {
      try {
        final wsUrl = Uri.parse('ws://$ip:$porta');

        channel = WebSocketChannel.connect(wsUrl);

        await channel!.ready;
        connected = true;
        notifyListeners();

        // !IMPORTANTE! Caso o client se conecte isso mudara o ip do servidor também
        if (connected) {
          DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
          var nomedopcLocal = '';
          var ip = await ConfigSistema.retornarIPMaquina();

          if (Platform.isAndroid) {
            AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
            nomedopcLocal = androidInfo.model;
          } else if (Platform.isIOS) {
            IosDeviceInfo iosDeviceInfo = await deviceInfo.iosInfo;
            nomedopcLocal = iosDeviceInfo.modelName;
          }

          channel!.sink.add(jsonEncode({
            'tipo': 'Rede',
            'nomedopc': nomedopcLocal,
            'tipodeempresa': '2',
            'nomedosistema': 'Big Chef Garçom',
            "sistemaoperacional": Platform.operatingSystem,
            'ip': ip,
          }));
        }

        channel!.stream.listen(
          (message) {
            onData(message);
          },
          onError: (error) {
            log('Error: $error');
          },
          onDone: () {
            debugPrint('abrirModalReconectar();');
            abrirModalReconectar();

            channel = null;
            connected = false;
            hostname = '';
            port = 0;
            notifyListeners();
          },
        );

        return true;
      } catch (e) {
        connected = false;
        log('Error', error: e);
        notifyListeners();
        return false;
      }
    });

    return sucesso;
  }

  disconnect([int? closeCode, String? closeReason]) async {
    try {
      if (channel == null) return;

      // channel!.sink.close(4999, 'Conexão foi fechada manualmente.');
      channel!.sink.close(closeCode, closeReason);
      channel = null;
      connected = false;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void abrirModalReconectar() async {
    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    // ConfigSistema.retornarIPMaquina().then((ip) {
    start(conexao!.servidor, conexao.porta).then((sucesso) {
      if (sucesso == false) {
        if (navigatorKey?.currentContext != null && navigatorKey!.currentContext!.mounted) {
          ScaffoldMessenger.of(navigatorKey!.currentContext!).showSnackBar(SnackBar(
            content: Text('Não foi possível conectar ao servidor em ${conexao.servidor}:${conexao.porta}, tente conectar manualmente.'),
            backgroundColor: Colors.red,
            showCloseIcon: true,
            duration: const Duration(hours: 1),
          ));
        }
      }
      // });
    });
  }

  write(String message) {
    try {
      channel!.sink.add(message);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  void onError(dynamic d) {
    log(d);
  }

  void onData(dynamic data) async {
    try {
      var dados = ModeloRetornoSocket.fromJson(data);

      if (dados.tipo == 'PC') {
        nomedopc = dados.nomedopc ?? '';
        notifyListeners();
        return;
      }

      AtualizacaoDeTela().call(dados);

      // pedido
      if (dados.tipoImpressao == '1') {
        Impressao.comprovanteDePedido(
          produtos: dados.produtos ?? [],
          comanda: dados.comanda ?? '',
          numeroPedido: dados.numeroPedido ?? '',
          nomeCliente: (dados.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' && (dados.observacaoDoPedido ?? '').isNotEmpty
              ? (dados.observacaoDoPedido ?? '')
              : (dados.nomeCliente ?? 'Sem Cliente'),
          nomeEmpresa: dados.nomeEmpresa ?? '',
          tipodeentrega: dados.tipodeentrega ?? '',
          tipoTela: dados.tipo == 'Mesa'
              ? TipoCardapio.mesa
              : dados.tipo == 'Comanda'
                  ? TipoCardapio.comanda
                  : TipoCardapio.balcao,
          imprimirSomenteLocal: true,
          enviarDeVolta: dados.enviarDeVolta ?? false,
        );

        // conta
      } else if (dados.tipoImpressao == '2') {
        Impressao.comprovanteDeConsumo(
          produtos: dados.produtos ?? [],
          celularEmpresa: dados.celularEmpresa ?? '',
          nomelancamento: dados.nomelancamento ?? [],
          somaValorHistorico: dados.somaValorHistorico ?? '0',
          cnpjEmpresa: dados.cnpjEmpresa ?? '',
          enderecoEmpresa: dados.enderecoEmpresa ?? '',
          nomeEmpresa: dados.nomeEmpresa ?? '',
          total: dados.total ?? '0',
          numeroPedido: dados.numeroPedido ?? '0',
          local: dados.local ?? '',
          permanencia: dados.permanencia!,
          tipodeentrega: dados.tipodeentrega!,
          imprimirSomenteLocal: true,
          nomeCliente: (dados.nomeCliente == '' ? null : dados.nomeCliente) ?? 'Sem Cliente',
          enviarDeVolta: dados.enviarDeVolta ?? false,
        );
      } else if (dados.tipoImpressao == '3') {
        Impressao.comprovanteDoEntregador(
          produtos: dados.produtos ?? [],
          celularEmpresa: dados.celularEmpresa ?? '',
          nomelancamento: dados.nomelancamento ?? [],
          somaValorHistorico: dados.somaValorHistorico ?? '0',
          cnpjEmpresa: dados.cnpjEmpresa ?? '',
          enderecoEmpresa: dados.enderecoEmpresa ?? '',
          nomeEmpresa: dados.nomeEmpresa ?? '',
          total: dados.total ?? '0',
          numeroPedido: dados.numeroPedido ?? '0',
          permanencia: dados.permanencia ?? '',
          celularCliente: dados.celularCliente ?? '',
          enderecoCliente: dados.enderecoCliente ?? '',
          nomeCliente: dados.nomeCliente ?? '',
          valortroco: dados.valortroco ?? '',
          valorentrega: dados.valorentrega ?? '',
          bairroCliente: dados.bairroCliente ?? '',
          cidadeCliente: dados.cidadeCliente ?? '',
          complementoCliente: dados.complementoCliente ?? '',
          numeroCliente: dados.numeroCliente ?? '',
          tipodeentrega: dados.tipodeentrega ?? '',
          imprimirSomenteLocal: true,
          enviarDeVolta: dados.enviarDeVolta ?? false,
        );
      }
    } catch (e) {
      log('erro', error: e);
    }

    notifyListeners();
  }
}
