import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_servico.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PaginaConfiguracao extends StatefulWidget {
  const PaginaConfiguracao({super.key});

  @override
  State<PaginaConfiguracao> createState() => _PaginaConfiguracaoState();
}

class _PaginaConfiguracaoState extends State<PaginaConfiguracao> {
  final tipoConexaoController = TextEditingController();
  final servidorController = TextEditingController();
  final portaController = TextEditingController();

  final ConfigSharedPreferences _config = ConfigSharedPreferences();

  bool isLoading = false;

  void buscarConexao() async {
    final conexao = await _config.getConexao();

    if (conexao == null) return;

    if (mounted) {
      setState(() {
        tipoConexaoController.text =
            conexao.tipoConexao == 'online' ? 'online' : 'localhost';
        servidorController.text = conexao.servidor;
        portaController.text = conexao.porta;
      });
    }
  }

  Future<void> verificar() async {
    if (isLoading) return;
    final tipoConexao = tipoConexaoController.text;
    final online = tipoConexao == 'online';
    final servidor = servidorController.text.trim();
    final porta = portaController.text.trim();
    if (tipoConexao.isEmpty ||
        (!online && (servidor.isEmpty || porta.isEmpty))) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Campos precisam ser preenchidos'),
        showCloseIcon: true,
      ));
      return;
    }

    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': tipoConexao,
          'servidor': servidor,
          'porta': porta,
        }),
      );

      final server = Modular.get<Server>();
      await server.disconnect();
      if (!mounted) return;
      if (online) {
        // O socket online recebe apenas avisos; sua indisponibilidade nao
        // impede salvar a conexao nem consultar a API HTTPS do cardapio.
        if (servidor.isNotEmpty && porta.isNotEmpty) {
          unawaited(server.connect(servidor, porta));
        }
      } else {
        await conectarAoServidor(servidor, porta);
      }

      if (!mounted) return;
      final usuario = await UsuarioServico.pegarUsuario(context);
      if (!mounted) return;
      context.read<UsuarioProvedor>().setUsuario(usuario);
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Não foi possível salvar a conexão. Tente novamente.'),
          showCloseIcon: true,
        ));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> conectarAoServidor(String ip, String porta) async {
    var server = Modular.get<Server>();

    await server.connect(ip, porta).then((sucesso) {
      if (sucesso == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Não foi possível conectar ao servidor $ip:$porta, mude a conexão e a porta e tente novamente'),
            backgroundColor: Colors.red,
            showCloseIcon: true,
            duration: const Duration(hours: 1),
          ));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Sucesso ao conectar ao servidor $ip:$porta'),
            backgroundColor: Colors.green,
            showCloseIcon: true,
          ));
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    buscarConexao();
  }

  @override
  void dispose() {
    tipoConexaoController.dispose();
    servidorController.dispose();
    portaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Conexão'),
        centerTitle: true,
      ),
      body: InkWell(
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: ListView(
            children: [
              DropdownMenu(
                key: ValueKey(tipoConexaoController.text),
                enabled: !isLoading,
                width: MediaQuery.of(context).size.width - 20,
                onSelected: (value) =>
                    setState(() => tipoConexaoController.text = value ?? ''),
                label: const Text('Conexão'),
                initialSelection: tipoConexaoController.text,
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'localhost', label: 'Local'),
                  DropdownMenuEntry(value: 'online', label: 'Online'),
                ],
                inputDecorationTheme: const InputDecorationTheme(
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (tipoConexaoController.text == 'online') ...[
                const Text(
                    'A conexão Online usa a API pela internet. IP e porta são opcionais para receber atualizações de um computador na rede local.'),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: servidorController,
                      onSubmitted: (a) => verificar(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(12),
                        labelText: tipoConexaoController.text == 'online'
                            ? 'IP local (opcional)'
                            : 'IP do Servidor Local',
                        hintStyle: const TextStyle(fontWeight: FontWeight.w300),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 150,
                    child: TextField(
                      controller: portaController,
                      onSubmitted: (a) => verificar(),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(12),
                        labelText: tipoConexaoController.text == 'online'
                            ? 'Porta (opcional)'
                            : 'Porta',
                        hintText: '9980',
                        hintStyle: const TextStyle(fontWeight: FontWeight.w300),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                        Theme.of(context).colorScheme.inversePrimary),
                    side: const WidgetStatePropertyAll(BorderSide.none),
                    shape: const WidgetStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    textStyle:
                        const WidgetStatePropertyAll(TextStyle(fontSize: 18)),
                  ),
                  onPressed: isLoading ? null : verificar,
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
