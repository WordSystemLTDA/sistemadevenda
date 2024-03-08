import 'dart:convert';

import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConfiguracaoPage extends StatefulWidget {
  const ConfiguracaoPage({super.key});

  @override
  State<ConfiguracaoPage> createState() => _ConfiguracaoPageState();
}

class _ConfiguracaoPageState extends State<ConfiguracaoPage> {
  final tipoConexaoController = TextEditingController();
  final servidorController = TextEditingController();

  final SharedPrefsConfig _config = SharedPrefsConfig();

  bool isLoading = false;

  void buscarConexao() async {
    final conexao = await _config.getConexao();

    if (conexao == null) return;

    tipoConexaoController.text = conexao['tipoConexao'];
    servidorController.text = conexao['servidor'];
  }

  void verificar() async {
    if (tipoConexaoController.text.isEmpty || servidorController.text.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Campos precisam ser preenchidos'),
        showCloseIcon: true,
      ));
      return;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': tipoConexaoController.text,
          'servidor': servidorController.text,
        }));

    setState(() => isLoading = !isLoading);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();

    tipoConexaoController.text = 'localhost';
    buscarConexao();
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
                width: MediaQuery.of(context).size.width - 20,
                onSelected: (value) => setState(() => tipoConexaoController.text = value ?? ''),
                label: const Text('Conexão'),
                initialSelection: 'localhost',
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'localhost', label: 'Local'),
                  DropdownMenuEntry(value: 'online', label: 'Online'),
                ],
                inputDecorationTheme: const InputDecorationTheme(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              if (tipoConexaoController.text == 'localhost') ...[
                TextField(
                  controller: servidorController,
                  onSubmitted: (a) => verificar(),
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    labelText: 'Endereço de IP',
                    hintStyle: TextStyle(fontWeight: FontWeight.w300),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.inversePrimary),
                    side: const MaterialStatePropertyAll(BorderSide.none),
                    shape: const MaterialStatePropertyAll(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(5)),
                      ),
                    ),
                    textStyle: const MaterialStatePropertyAll(TextStyle(fontSize: 18)),
                  ),
                  onPressed: verificar,
                  child: isLoading ? const CircularProgressIndicator() : const Text('Verificar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
