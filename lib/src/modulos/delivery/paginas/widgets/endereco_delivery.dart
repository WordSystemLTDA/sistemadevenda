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
  bool _salvando = false,
      _padrao = false,
      _sitio = false,
      _carregandoPadrao = true;
  bool _temOutroEnderecoPadrao = false;
  List<Map<String, dynamic>> _outrosEnderecosPadrao = [];
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
    _sitio = _valor(endereco, ['tipolocalentrega']) == 'Sitio';
  }

  Future<void> _carregarPadraoEndereco() async {
    ConfiguracaoEnderecoCliente? configuracao;
    List<Map<String, dynamic>>? outrosEnderecosPadrao;
    try {
      final resposta =
          await widget.servico.consultar('config_clientes/listar_cliente.php');
      configuracao = ConfiguracaoEnderecoCliente.fromResposta(resposta);
    } catch (_) {
      // Se a configuracao padrao nao vier, o usuario segue preenchendo manualmente.
    }

    try {
      outrosEnderecosPadrao = await _buscarOutrosEnderecosPadrao();
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
          if (outrosEnderecosPadrao != null) {
            _outrosEnderecosPadrao = outrosEnderecosPadrao;
            _temOutroEnderecoPadrao = outrosEnderecosPadrao.isNotEmpty;
          }
          if (outrosEnderecosPadrao?.isEmpty == true) _padrao = true;
          _carregandoPadrao = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _buscarOutrosEnderecosPadrao() async {
    final resposta = await widget.servico
        .consultar('enderecos_clientes/listar_por_cliente.php', {
      'cliente': widget.cliente,
      'pesquisa': '',
    });
    final enderecos = resposta is List ? resposta : const [];
    final idAtual = widget.endereco?['id']?.toString().trim() ?? '';
    return [
      for (final endereco in enderecos)
        if (endereco is Map &&
            (endereco['id']?.toString().trim() ?? '') != idAtual &&
            _ehPadrao(endereco['padrao']))
          Map<String, dynamic>.from(endereco)
    ];
  }

  Future<bool> _confirmarTrocaEnderecoPadrao() async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Alterar endereço padrão?'),
        content: const Text(
            'Este cliente já possui um endereço padrão. Deseja mudar o endereço padrão para este endereço atual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Não'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, alterar'),
          ),
        ],
      ),
    );
    return confirmar == true;
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

  Future<void> _salvarEnderecoExistenteComoNaoPadrao(
      Map<String, dynamic> endereco) async {
    await widget.servico.salvar('clientes/inserir_endereco.php', {
      'cep': _valor(endereco, ['cep']),
      'endereco': _valor(endereco, ['endereco']),
      'numero': _valor(endereco, ['numero']),
      'bairro': _valor(endereco, ['bairro']),
      'complemento': _valor(endereco, ['complemento']),
      'cidade': _valor(endereco, ['cidade']),
      'uf': _valor(endereco, ['estado', 'uf']).toUpperCase(),
      'id': endereco['id']?.toString() ?? '',
      'idCliente': widget.cliente,
      'padrao': 'Não',
      'tipoLocalEntrega': _valor(endereco, ['tipolocalentrega']) == 'Sitio'
          ? 'Sitio'
          : 'Normal',
      'substituirPadrao': false,
      'podeInserirNovaCidade': false,
    });
  }

  Future<void> _salvar() async {
    if (_salvando || _carregandoPadrao || !_form.currentState!.validate()) {
      return;
    }
    var salvarComoPadrao = _padrao;
    var substituirPadrao = false;
    if (_padrao && _temOutroEnderecoPadrao) {
      substituirPadrao = await _confirmarTrocaEnderecoPadrao();
      if (!mounted) return;
      salvarComoPadrao = substituirPadrao;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _salvando = true;
      _padrao = salvarComoPadrao;
      _erro = null;
    });
    try {
      if (substituirPadrao) {
        for (final endereco in _outrosEnderecosPadrao) {
          await _salvarEnderecoExistenteComoNaoPadrao(endereco);
        }
      }
      await widget.servico.salvar('clientes/inserir_endereco.php', {
        for (final e in _campos.entries) e.key: e.value.text.trim(),
        'uf': _campos['uf']!.text.trim().toUpperCase(),
        'id': widget.endereco?['id']?.toString() ?? '',
        'idCliente': widget.cliente,
        'padrao': salvarComoPadrao ? 'Sim' : 'Não',
        'tipoLocalEntrega': _sitio ? 'Sitio' : 'Normal',
        'substituirPadrao': substituirPadrao,
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
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              secondary: const Icon(Icons.agriculture_outlined),
                              title: const Text('Endereço em sítio'),
                              subtitle: const Text(
                                  'Aplica a taxa especial configurada para área rural.'),
                              value: _sitio,
                              onChanged: _salvando || _carregandoPadrao
                                  ? null
                                  : (v) => setState(() => _sitio = v)),
                          if (_erro != null)
                            Text(_erro!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error)),
                        ])))),
      ));
}
