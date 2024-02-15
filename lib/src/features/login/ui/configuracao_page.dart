import 'dart:convert';

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

  bool isLoading = false;

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
    Navigator.pop(context);
    // print();
    // print();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conexão'),
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
                controller: tipoConexaoController,
                width: MediaQuery.of(context).size.width - 20,
                label: const Text('Conexão'),
                dropdownMenuEntries: const [
                  DropdownMenuEntry(value: 'localhost', label: 'localhost'),
                  DropdownMenuEntry(value: 'online', label: 'online'),
                ],
                inputDecorationTheme: const InputDecorationTheme(
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: servidorController,
                obscureText: true,
                onSubmitted: (a) => verificar(),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  labelText: "Servidor",
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
