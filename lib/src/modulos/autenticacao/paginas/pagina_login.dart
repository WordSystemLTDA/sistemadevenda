import 'dart:async';
import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_servico.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/widgets/dialogo_atualizacao_disponivel.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_pre_cadastro.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/inicio/paginas/pagina_inicio.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  final ServicoAutenticacao _service = Modular.get<ServicoAutenticacao>();

  var verificando = true;
  var isLoading = false;
  CancelToken? _loginEmAndamento;
  CancelToken? _atualizacaoEmAndamento;

  bool get _atualizando => _atualizacaoEmAndamento != null;

  bool _atualizacaoAtual(CancelToken tentativa) =>
      mounted &&
      identical(_atualizacaoEmAndamento, tentativa) &&
      !tentativa.isCancelled;

  bool _tentativaAtual(CancelToken tentativa) =>
      mounted &&
      identical(_loginEmAndamento, tentativa) &&
      !tentativa.isCancelled;

  Future<bool> _aguardarLogin(Future<bool> resposta, CancelToken tentativa) =>
      Future.any([resposta, tentativa.whenCancel.then((_) => false)])
          .timeout(const Duration(seconds: 15));

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem), showCloseIcon: true));
  }

  void entrar() async {
    if (isLoading || verificando || _atualizando) return;
    if (usuarioController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Usuário e Senha são obrigatórios'),
        showCloseIcon: true,
      ));
      return;
    }
    final tentativa = CancelToken();
    _loginEmAndamento = tentativa;
    setState(() => isLoading = true);
    try {
      final res = await _aguardarLogin(
          _service.entrar(usuarioController.text, senhaController.text,
              cancelToken: tentativa),
          tentativa);
      if (!mounted || !_tentativaAtual(tentativa)) return;
      if (res) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PaginaInicio(),
        ));
      } else {
        _mostrarErro(
            'Não foi possível entrar. Confira a conexão, o usuário e a senha.');
      }
    } catch (_) {
      if (_tentativaAtual(tentativa)) {
        _mostrarErro(
            'Não foi possível entrar. Verifique a conexão com o servidor.');
      }
    } finally {
      tentativa.cancel();
      if (mounted && identical(_loginEmAndamento, tentativa)) {
        _loginEmAndamento = null;
        setState(() => isLoading = false);
      }
    }
  }

  void verificarLogin() async {
    final tentativa = CancelToken();
    _loginEmAndamento = tentativa;
    try {
      unawaited(_conectarServidorLocal());
      final sucesso =
          await _aguardarLogin(_restaurarLogin(tentativa), tentativa);
      if (sucesso && mounted && _tentativaAtual(tentativa)) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const PaginaInicio(),
        ));
      }
    } catch (_) {
      if (_tentativaAtual(tentativa)) {
        _mostrarErro(
            'Não foi possível retomar o acesso. Verifique a conexão nas configurações.');
      }
    } finally {
      tentativa.cancel();
      if (mounted && identical(_loginEmAndamento, tentativa)) {
        _loginEmAndamento = null;
        setState(() => verificando = false);
      }
    }
  }

  Future<bool> _restaurarLogin(CancelToken tentativa) async {
    final usuario = await UsuarioServico.pegarUsuario(context);
    if (usuario == null || !_tentativaAtual(tentativa)) return false;
    return _service.entrar(usuario.email, usuario.senha,
        permitirSessaoSalva: true, cancelToken: tentativa);
  }

  void _abrirConfiguracoes() {
    _loginEmAndamento?.cancel();
    _loginEmAndamento = null;
    _atualizacaoEmAndamento?.cancel();
    setState(() {
      verificando = false;
      isLoading = false;
      _atualizacaoEmAndamento = null;
    });
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const PaginaConfiguracao()));
  }

  Future<void> _abrirAtualizacao() async {
    if (_atualizando) return;
    FocusManager.instance.primaryFocus?.unfocus();
    // Atualizar antes do login também deve interromper a entrada automática.
    _loginEmAndamento?.cancel();
    _loginEmAndamento = null;
    final tentativa = CancelToken();
    setState(() {
      verificando = false;
      isLoading = false;
      _atualizacaoEmAndamento = tentativa;
    });
    try {
      final config = await Future.any([
        Modular.get<ServicoConfig>()
            .consultarAtualizacao(cancelToken: tentativa),
        tentativa.whenCancel.then((_) => null),
      ]).timeout(const Duration(seconds: 15));
      if (!_atualizacaoAtual(tentativa) || config == null) return;
      final link = Platform.isIOS
          ? config.linkAtualizacaoIos
          : config.linkAtualizacaoAndroid;
      if (link.trim().isEmpty) {
        _mostrarErro(
            'O link de atualização ainda não está disponível. Entre em contato com o suporte.');
        return;
      }
      final abriu = await abrirLinkExternoAtualizacao(link);
      if (_atualizacaoAtual(tentativa) && !abriu) {
        _mostrarErro(
            'Não foi possível abrir a atualização. Tente novamente ou entre em contato com o suporte.');
      }
    } catch (_) {
      if (_atualizacaoAtual(tentativa)) {
        _mostrarErro(
            'Não foi possível buscar a atualização. Confira sua conexão com a internet e tente novamente.');
      }
    } finally {
      tentativa.cancel();
      if (mounted && identical(_atualizacaoEmAndamento, tentativa)) {
        setState(() => _atualizacaoEmAndamento = null);
      }
    }
  }

  Widget _botaoAtualizacao() => SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _atualizando ? null : _abrirAtualizacao,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: _atualizando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.system_update_alt_rounded),
          label: Text(_atualizando
              ? 'Buscando atualização...'
              : 'Atualizar aplicativo'),
        ),
      );

  Future<void> _conectarServidorLocal() async {
    try {
      final conexao = await ConfigSharedPreferences().getConexao();
      if (conexao == null ||
          conexao.servidor.isEmpty ||
          conexao.porta.isEmpty) {
        return;
      }
      await Modular.get<Server>().connect(conexao.servidor, conexao.porta);
    } catch (_) {
      // A reconexao segue pelas retentativas do socket e pela tela inicial.
    }
  }

  @override
  void initState() {
    super.initState();
    verificarLogin();
  }

  @override
  void dispose() {
    _loginEmAndamento?.cancel();
    _atualizacaoEmAndamento?.cancel();
    usuarioController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _botaoAtualizacao(),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: verificando == true
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Center(child: CircularProgressIndicator()),
                  const SizedBox(height: 10),
                  const Text('Conectando ao Servidor Local...'),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _abrirConfiguracoes,
                    icon: const Icon(Icons.settings_outlined),
                    label: const Text('Configurações de conexão'),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 100),
                      Image.asset(
                        'assets/logo_funco_transparente.png',
                        width: 200,
                        height: 150,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 200,
                            height: 150,
                            child: Center(child: Icon(Icons.error)),
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: usuarioController,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(13),
                          labelText: "Usuário ou E-mail",
                          hintStyle: TextStyle(fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: senhaController,
                        obscureText: true,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(13),
                          labelText: "Senha",
                          hintStyle: TextStyle(fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: ButtonStyle(
                            // backgroundColor: MaterialStatePropertyAll(Colors.green),
                            backgroundColor: WidgetStateProperty.all(
                                Theme.of(context).colorScheme.inversePrimary),
                            side: const WidgetStatePropertyAll(BorderSide.none),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5)),
                              ),
                            ),
                            // foregroundColor: const MaterialStatePropertyAll(Colors.white),
                            textStyle: const WidgetStatePropertyAll(
                                TextStyle(fontSize: 18)),
                          ),
                          onPressed: isLoading || _atualizando ? null : entrar,
                          child: isLoading
                              ? const CircularProgressIndicator()
                              : const Text('Entrar'),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextButton(
                        onPressed: _abrirConfiguracoes,
                        child: const Text('Configurações'),
                      ),
                      TextButton(
                        onPressed: _atualizando
                            ? null
                            : () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const PaginaPreCadastro()));
                              },
                        child: const Text("Não está cadastrado? Cadastre-se"),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
