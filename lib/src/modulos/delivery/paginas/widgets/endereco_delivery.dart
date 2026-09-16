import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';

class EnderecoDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  final String cliente;
  const EnderecoDelivery(
      {super.key, required this.servico, required this.cliente});
  @override
  State<EnderecoDelivery> createState() => _EnderecoDeliveryState();
}

class _EnderecoDeliveryState extends State<EnderecoDelivery> {
  final _form = GlobalKey<FormState>();
  final _campos = {
    for (final k in [
      'cep',
      'endereco',
      'numero',
      'bairro',
      'complemento',
      'cidade',
      'uf'
    ])
      k: TextEditingController()
  };
  bool _salvando = false, _padrao = false;
  String? _erro;
  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.servico.salvar('clientes/inserir_endereco.php', {
        for (final e in _campos.entries) e.key: e.value.text.trim(),
        'uf': _campos['uf']!.text.trim().toUpperCase(),
        'id': '',
        'idCliente': widget.cliente,
        'padrao': _padrao ? 'Sim' : 'Não',
        'podeInserirNovaCidade': false,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = e is StateError
              ? e.message.toString()
              : 'Não foi possível salvar o endereço.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_salvando,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('Novo endereço'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary),
        bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
                onPressed: _salvando ? null : _salvar,
                icon: const Icon(Icons.check),
                label: Text(_salvando ? 'Salvando...' : 'Salvar endereço'))),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Form(
                    key: _form,
                    child: ListView(
                        padding: const EdgeInsets.all(16),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        children: [
                          for (final campo in const [
                            ('cep', 'CEP', false),
                            ('endereco', 'Rua / avenida', true),
                            ('numero', 'Número', true),
                            ('complemento', 'Complemento', false),
                            ('bairro', 'Bairro', true),
                            ('cidade', 'Cidade', true),
                            ('uf', 'UF', true)
                          ])
                            Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: TextFormField(
                                  controller: _campos[campo.$1],
                                  enabled: !_salvando,
                                  textCapitalization: campo.$1 == 'uf'
                                      ? TextCapitalization.characters
                                      : TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  maxLength: campo.$1 == 'uf' ? 2 : null,
                                  onTapOutside: (_) => FocusManager
                                      .instance.primaryFocus
                                      ?.unfocus(),
                                  validator: (v) =>
                                      campo.$3 && (v?.trim().isEmpty ?? true)
                                          ? 'Campo obrigatório'
                                          : null,
                                  decoration: InputDecoration(
                                      labelText: campo.$2,
                                      border: const OutlineInputBorder()),
                                )),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Endereço padrão'),
                              value: _padrao,
                              onChanged: _salvando
                                  ? null
                                  : (v) => setState(() => _padrao = v)),
                          if (_erro != null)
                            Text(_erro!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        ])))),
      ));
}
