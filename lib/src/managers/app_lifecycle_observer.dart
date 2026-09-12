import 'dart:async';
import 'dart:developer';

import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppLifecycleObserver extends StatefulWidget {
  final Widget child;
  const AppLifecycleObserver({super.key, required this.child});

  @override
  State<AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<AppLifecycleObserver>
    with WidgetsBindingObserver {
  late final Server server;
  late final Sincronizador sincronizador;
  StreamSubscription<List<ConnectivityResult>>? _rede;
  Future<void>? _conectando;

  @override
  void initState() {
    super.initState();
    server = Modular.get<Server>();
    sincronizador = Modular.get<Sincronizador>();
    sincronizador.aoAtualizarTelas = _atualizarTelas;
    sincronizador.iniciar();
    WidgetsBinding.instance.addObserver(this);
    // Wi-Fi sem internet ainda pode alcancar o servidor local pelo IP.
    _rede = Connectivity().onConnectivityChanged.listen((_) => _retomar(),
        onError: (Object erro, StackTrace stack) {
      log('Falha ao observar a rede', error: erro, stackTrace: stack);
      _retomar();
    });
    _retomar();
  }

  void _atualizarTelas() {
    if (!mounted) return;
    for (final tipo in ['Mesa', 'Comanda', 'Balcão', 'Cardapio']) {
      AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: tipo));
    }
  }

  Future<void> _retomar() => _conectando ??= () async {
        sincronizador.solicitar();
        try {
          final conexao = await ConfigSharedPreferences().getConexao();
          if (!mounted) return;
          if (conexao != null &&
              conexao.servidor.isNotEmpty &&
              conexao.porta.isNotEmpty) {
            await server.connect(conexao.servidor, conexao.porta);
          }
        } catch (erro, stack) {
          log('Falha ao retomar a conexao', error: erro, stackTrace: stack);
        }
      }()
          .whenComplete(() => _conectando = null);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _retomar();
    // Nao encerra o socket ao apagar a tela. O SO pode suspender a execucao;
    // as filas duraveis retomam automaticamente quando o app volta a executar.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rede?.cancel();
    sincronizador.aoAtualizarTelas = null;
    sincronizador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
