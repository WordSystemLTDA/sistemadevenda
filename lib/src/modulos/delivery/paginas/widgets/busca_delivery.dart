import 'dart:async';
import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> buscarDelivery(
  BuildContext context, {
  required String titulo,
  required Future<List<Map<String, dynamic>>> Function(String) buscar,
  required String Function(Map<String, dynamic>) nome,
  String Function(Map<String, dynamic>)? detalhe,
}) =>
    Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => _BuscaDelivery(
          titulo: titulo, buscar: buscar, nome: nome, detalhe: detalhe),
    ));

class _BuscaDelivery extends StatefulWidget {
  final String titulo;
  final Future<List<Map<String, dynamic>>> Function(String) buscar;
  final String Function(Map<String, dynamic>) nome;
  final String Function(Map<String, dynamic>)? detalhe;
  const _BuscaDelivery(
      {required this.titulo,
      required this.buscar,
      required this.nome,
      this.detalhe});
  @override
  State<_BuscaDelivery> createState() => _BuscaDeliveryState();
}

class _BuscaDeliveryState extends State<_BuscaDelivery> {
  final _texto = TextEditingController();
  List<Map<String, dynamic>> _dados = [];
  Timer? _debounce;
  int _versao = 0;
  bool _carregando = true, _erro = false;
  @override
  void initState() {
    super.initState();
    _listar();
  }

  Future<void> _listar() async {
    final versao = ++_versao;
    setState(() {
      _carregando = true;
      _erro = false;
    });
    try {
      final dados = await widget.buscar(_texto.text.trim());
      if (!mounted || versao != _versao) return;
      setState(() => _dados = dados);
    } catch (_) {
      if (mounted && versao == _versao) setState(() => _erro = true);
    } finally {
      if (mounted && versao == _versao) setState(() => _carregando = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: Text(widget.titulo),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _texto,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Pesquisar',
                    border: OutlineInputBorder()),
                onChanged: (_) {
                  ++_versao;
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 300), _listar);
                },
                onSubmitted: (_) {
                  _debounce?.cancel();
                  _listar();
                },
              )),
          if (_carregando) const LinearProgressIndicator(),
          if (_erro)
            ListTile(
                title: const Text('Não foi possível carregar.'),
                trailing: IconButton(
                    tooltip: 'Tentar novamente',
                    onPressed: _listar,
                    icon: const Icon(Icons.refresh))),
          Expanded(
              child: _dados.isEmpty && !_carregando && !_erro
                  ? const Center(child: Text('Nenhum resultado encontrado'))
                  : ListView.builder(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: _dados.length,
                      itemBuilder: (_, i) {
                        final detalhe = widget.detalhe?.call(_dados[i]) ?? '';
                        return ListTile(
                          title: Text(widget.nome(_dados[i])),
                          subtitle: detalhe.isEmpty ? null : Text(detalhe),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.pop(context, _dados[i]),
                        );
                      })),
        ]),
      );
}
