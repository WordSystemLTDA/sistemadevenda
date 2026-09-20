import 'package:app/src/modulos/delivery/modelos/configuracao_endereco_cliente.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';

class EnderecoDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  final String cliente;
  final Map<String, dynamic>? endereco;
  const EnderecoDelivery(
      {super.key, required this.servico, required this.cliente, this.endereco});
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
  bool _salvando = false, _padrao = false, _carregandoPadrao = true;
  bool _bloquearCidade = false, _enderecoObrigatorio = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _preencherEnderecoExistente();
    _carregarPadraoEndereco();
  }

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _editando =>
      (widget.endereco?['id']?.toString().trim().isNotEmpty ?? false);

  void _preencherEnderecoExistente() {
    final endereco = widget.endereco;
    if (endereco == null) return;
    _preencherSeVazio('cep', _valor(endereco, ['cep']));
    _preencherSeVazio('endereco', _valor(endereco, ['endereco']));
    _preencherSeVazio('numero', _valor(endereco, ['numero']));
    _preencherSeVazio('bairro', _valor(endereco, ['bairro']));
    _preencherSeVazio('complemento', _valor(endereco, ['complemento']));
    _preencherSeVazio('cidade', _valor(endereco, ['cidade']));
    _preencherSeVazio('uf', _valor(endereco, ['estado', 'uf']));
    _padrao = _ehPadrao(endereco['padrao']);
  }

  Future<void> _carregarPadraoEndereco() async {
    ConfiguracaoEnderecoCliente? configuracao;
    bool? temEnderecoPadrao;
    try {
      final resposta =
          await widget.servico.consultar('config_clientes/listar_cliente.php');
      configuracao = ConfiguracaoEnderecoCliente.fromResposta(resposta);
    } catch (_) {
      // Se a configuracao padrao nao vier, o usuario segue preenchendo manualmente.
    }

    try {
      temEnderecoPadrao = await _clienteTemEnderecoPadrao();
    } catch (_) {
      // Se a consulta falhar, mantem a escolha manual do usuario.
    } finally {
      if (mounted) {
        setState(() {
          if (configuracao != null) {
            _preencherSeVazio('cep', configuracao.cep);
            _preencherSeVazio('cidade', configuracao.cidade);
            _preencherSeVazio('uf', configuracao.uf);
            _bloquearCidade = configuracao.bloquearCidade;
            _enderecoObrigatorio = configuracao.enderecoObrigatorio;
          }
          if (temEnderecoPadrao == false) _padrao = true;
          _carregandoPadrao = false;
        });
      }
    }
  }

  Future<bool> _clienteTemEnderecoPadrao() async {
    final resposta = await widget.servico
        .consultar('enderecos_clientes/listar_por_cliente.php', {
      'cliente': widget.cliente,
      'pesquisa': '',
    });
    final enderecos = resposta is List ? resposta : const [];
    return enderecos.any((endereco) {
      if (endereco is! Map) return false;
      return _ehPadrao(endereco['padrao']);
    });
  }

  bool _ehPadrao(Object? valor) {
    return _valorAtivo(valor);
  }

  bool _valorAtivo(Object? valor) {
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    return texto == 'sim' || texto == 's' || texto == '1' || texto == 'true';
  }

  String _valor(Map<String, dynamic> dados, List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  void _preencherSeVazio(String campo, String valor) {
    final controller = _campos[campo];
    if (controller == null ||
        valor.isEmpty ||
        controller.text.trim().isNotEmpty) {
      return;
    }
    controller.text = campo == 'uf' ? valor.toUpperCase() : valor;
  }

  Future<void> _salvar() async {
    if (_salvando || _carregandoPadrao || !_form.currentState!.validate()) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.servico.salvar('clientes/inserir_endereco.php', {
        for (final e in _campos.entries) e.key: e.value.text.trim(),
        'uf': _campos['uf']!.text.trim().toUpperCase(),
        'id': widget.endereco?['id']?.toString() ?? '',
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
            title: Text(_editando ? 'Editar endereço' : 'Novo endereço'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary),
        bottomNavigationBar: SafeArea(
            top: false,
            minimum: const EdgeInsets.all(16),
            child: FilledButton.icon(
                onPressed: _salvando || _carregandoPadrao ? null : _salvar,
                icon: _carregandoPadrao || _salvando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: Text(_carregandoPadrao
                    ? 'Carregando dados...'
                    : _salvando
                        ? 'Salvando...'
                        : _editando
                            ? 'Salvar alterações'
                            : 'Salvar endereço'))),
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
                                  enabled: !_salvando && !_carregandoPadrao,
                                  readOnly: _bloquearCidade &&
                                      (campo.$1 == 'cidade' ||
                                          campo.$1 == 'uf'),
                                  textCapitalization: campo.$1 == 'uf'
                                      ? TextCapitalization.characters
                                      : TextCapitalization.words,
                                  textInputAction: TextInputAction.next,
                                  maxLength: campo.$1 == 'uf' ? 2 : null,
                                  onTapOutside: (_) => FocusManager
                                      .instance.primaryFocus
                                      ?.unfocus(),
                                  validator: (v) => campo.$3 &&
                                          _enderecoObrigatorio &&
                                          (v?.trim().isEmpty ?? true)
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
                              onChanged: _salvando || _carregandoPadrao
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
