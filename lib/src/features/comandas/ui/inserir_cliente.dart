import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final ComandasState _state = ComandasState();

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
              .then((sucesso) {
            if (mounted && sucesso) {
              Navigator.pop(context);
            }

            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: sucesso ? const Text('Cliente Cadastrado') : const Text('Ocorreu um erro'),
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
                  hintText: 'Digite o Nome do Cliente',
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
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: 'Digite o Celular do Cliente',
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
                  hintText: 'Digite o E-mail do Cliente',
                ),
              ),
              const SizedBox(height: 10),
              const Text('Observação', style: TextStyle(fontSize: 18)),
              TextField(
                controller: obsController,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
                  isDense: true,
                  hintText: 'Obs',
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
