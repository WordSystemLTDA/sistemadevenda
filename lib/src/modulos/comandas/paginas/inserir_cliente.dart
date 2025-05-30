import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

class InserirCliente extends StatefulWidget {
  const InserirCliente({super.key});

  @override
  State<InserirCliente> createState() => _InserirClienteState();
}

class _InserirClienteState extends State<InserirCliente> {
  final nomeController = TextEditingController();
  final celularController = TextEditingController();
  final emailController = TextEditingController();
  final obsController = TextEditingController();

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Cliente'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          if (nomeController.text.isEmpty) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Campo de Nome é Obrigatório'),
              showCloseIcon: true,
            ));
            return;
          }

          await _state
              .inserirCliente(
            nomeController.text,
            celularController.text,
            emailController.text,
            obsController.text,
          )
              .then((responsta) {
            if (context.mounted && responsta.sucesso) {
              Navigator.pop(context, {
                'idcliente': responsta.idcliente,
                'nomecliente': responsta.nomecliente,
              });
            }

            if (context.mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(responsta.mensagem),
                backgroundColor: responsta.sucesso ? Colors.green : Colors.red,
                showCloseIcon: true,
              ));
            }
          });
        },
        label: const Row(
          children: [
            Text('Salvar'),
            SizedBox(width: 10),
            Icon(Icons.check),
          ],
        ),
      ),
      body: InkWell(
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 15),
          child: ListView(
            children: [
              const Text('Nome', style: TextStyle(fontSize: 18)),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: '',
                ),
              ),
              const SizedBox(height: 10),
              const Text('Celular', style: TextStyle(fontSize: 18)),
              TextField(
                controller: celularController,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TelefoneInputFormatter(),
                ],
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: '',
                ),
              ),
              const SizedBox(height: 10),
              const Text('E-mail', style: TextStyle(fontSize: 18)),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: '',
                ),
              ),
              const SizedBox(height: 10),
              const Text('Observação', style: TextStyle(fontSize: 18)),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: '',
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
