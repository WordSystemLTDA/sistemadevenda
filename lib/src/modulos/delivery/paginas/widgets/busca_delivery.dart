import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<Map<String, dynamic>?> buscarDelivery(
  BuildContext context, {
  required String titulo,
  required Future<List<Map<String, dynamic>>> Function(String) buscar,
  required String Function(Map<String, dynamic>) nome,
  String Function(Map<String, dynamic>)? detalhe,
  Future<Map<String, dynamic>?> Function(BuildContext)? novo,
  String rotuloNovo = 'Novo Cliente',
  bool buscarCelular = false,
}) =>
    Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => _BuscaDelivery(
          titulo: titulo,
          buscar: buscar,
          nome: nome,
          detalhe: detalhe,
          novo: novo,
          rotuloNovo: rotuloNovo,
          buscarCelular: buscarCelular),
    ));

class _BuscaDelivery extends StatefulWidget {
  final String titulo;
  final Future<List<Map<String, dynamic>>> Function(String) buscar;
  final String Function(Map<String, dynamic>) nome;
  final String Function(Map<String, dynamic>)? detalhe;
  final Future<Map<String, dynamic>?> Function(BuildContext)? novo;
  final String rotuloNovo;
  final bool buscarCelular;
  const _BuscaDelivery(
      {required this.titulo,
      required this.buscar,
      required this.nome,
      this.detalhe,
      this.novo,
      required this.rotuloNovo,
      required this.buscarCelular});
  @override
  State<_BuscaDelivery> createState() => _BuscaDeliveryState();
}

class _BuscaDeliveryState extends State<_BuscaDelivery> {
  final _texto = TextEditingController();
  final _celular = TextEditingController();
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
      final dados = await widget.buscar(_termoBusca);
      if (!mounted || versao != _versao) return;
      setState(() => _dados = dados);
    } catch (_) {
      if (mounted && versao == _versao) setState(() => _erro = true);
    } finally {
      if (mounted && versao == _versao) setState(() => _carregando = false);
    }
  }

  String get _termoBusca {
    final celular = _celular.text.trim();
    if (celular.isNotEmpty) return celular;
    return _texto.text.trim();
  }

  void _agendarBusca() {
    ++_versao;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _listar);
  }

  void _alterarTexto(String _) {
    if (_celular.text.isNotEmpty) _celular.clear();
    _agendarBusca();
  }

  void _alterarCelular(String _) {
    if (_texto.text.isNotEmpty) _texto.clear();
    _agendarBusca();
  }

  Future<void> _novo() async {
    final novo = widget.novo;
    if (novo == null) return;
    final resultado = await novo(context);
    if (!mounted || resultado == null) return;
    Navigator.pop(context, resultado);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _texto.dispose();
    _celular.dispose();
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _texto,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Razão social, nome ou celular',
                        border: OutlineInputBorder()),
                    onChanged: _alterarTexto,
                    onSubmitted: (_) {
                      _debounce?.cancel();
                      _listar();
                    },
                  ),
                  if (widget.buscarCelular) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _celular,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.search,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                      ],
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.phone_iphone_outlined),
                          hintText: 'Últimos 4 dígitos do celular',
                          border: OutlineInputBorder()),
                      onChanged: _alterarCelular,
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        _listar();
                      },
                    ),
                  ],
                  if (widget.novo != null) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton.tonalIcon(
                        onPressed: _novo,
                        icon: const Icon(Icons.person_add_alt_1_outlined),
                        label: Text(widget.rotuloNovo),
                      ),
                    ),
                  ],
                ],
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
