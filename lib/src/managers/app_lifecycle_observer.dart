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
  Set<ConnectivityResult>? _redeAnterior;
  int _geracaoRetomada = 0;
  bool _voltandoDoSegundoPlano = false;
  bool _renovarCanalPendente = false;

  @override
  void initState() {
    super.initState();
    server = Modular.get<Server>();
    sincronizador = Modular.get<Sincronizador>();
    sincronizador.aoAtualizarTelas = _atualizarTelas;
    sincronizador.iniciar();
    WidgetsBinding.instance.addObserver(this);
    // Wi-Fi sem internet ainda pode alcancar o servidor local pelo IP.
    _rede = Connectivity().onConnectivityChanged.listen((resultados) {
      final redeAtual = resultados.toSet();
      final anterior = _redeAnterior;
      _redeAnterior = redeAtual;
      final mudou = anterior != null &&
          (anterior.length != redeAtual.length ||
              !anterior.containsAll(redeAtual));
      unawaited(_retomar(renovarCanal: mudou));
    }, onError: (Object erro, StackTrace stack) {
      log('Falha ao observar a rede', error: erro, stackTrace: stack);
      _retomar();
    });
    _retomar();
  }

  void _atualizarTelas() {
    if (!mounted) return;
    for (final tipo in ['Mesa', 'Comanda', 'Balcão', 'Delivery', 'Cardapio']) {
      AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: tipo));
    }
  }

  Future<void> _retomar({bool renovarCanal = false}) async {
    final geracao = ++_geracaoRetomada;
    _renovarCanalPendente = _renovarCanalPendente || renovarCanal;
    sincronizador.solicitar();
    try {
      final conexao = await ConfigSharedPreferences().getConexao();
      if (!mounted || geracao != _geracaoRetomada) return;
      if (conexao != null &&
          conexao.servidor.isNotEmpty &&
          conexao.porta.isNotEmpty) {
        final renovar = _renovarCanalPendente;
        _renovarCanalPendente = false;
        // Server ja compartilha tentativas concorrentes. Uma mudanca de rede
        // precisa cancelar a tentativa antiga, sem esperar seu timeout.
        await server.retomarConexao(conexao.servidor, conexao.porta,
            renovarCanal: renovar);
      }
    } catch (erro, stack) {
      log('Falha ao retomar a conexao', error: erro, stackTrace: stack);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _voltandoDoSegundoPlano = true;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_retomar(renovarCanal: _voltandoDoSegundoPlano));
      _voltandoDoSegundoPlano = false;
    }
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
