import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/delivery/modelos/configuracao_endereco_cliente.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

typedef ResultadoCadastroCliente = ({
  bool sucesso,
  String idcliente,
  String nomecliente,
  String mensagem,
});

typedef AoCadastrarCliente = Future<ResultadoCadastroCliente> Function(
    String nome, String celular, String email, String observacao);

class InserirCliente extends StatefulWidget {
  final ServicoDelivery? servicoEndereco;
  final AoCadastrarCliente? aoCadastrarCliente;

  const InserirCliente({
    super.key,
    this.servicoEndereco,
    this.aoCadastrarCliente,
  });

  @override
  State<InserirCliente> createState() => _InserirClienteState();
}

class _InserirClienteState extends State<InserirCliente> {
  final _form = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _enderecoControllers = {
    for (final campo in ['cep', 'endereco', 'numero', 'bairro', 'cidade', 'uf'])
      campo: TextEditingController(),
  };

  bool _salvando = false;
  bool _carregandoEndereco = false;
  ConfiguracaoEnderecoCliente _configuracaoEndereco =
      const ConfiguracaoEnderecoCliente();
  String? _idClienteCriado;
  String? _nomeClienteCriado;
  String? _mensagemClienteCriado;

  bool get _incluiEndereco => widget.servicoEndereco != null;

  @override
  void initState() {
    super.initState();
    if (_incluiEndereco) _carregarConfiguracaoEndereco();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _observacaoController.dispose();
    for (final controller in _enderecoControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _carregarConfiguracaoEndereco() async {
    setState(() => _carregandoEndereco = true);
    try {
      final resposta = await widget.servicoEndereco!
          .consultar('config_clientes/listar_cliente.php');
      final configuracao = ConfiguracaoEnderecoCliente.fromResposta(resposta);
      if (!mounted) return;
      setState(() {
        _configuracaoEndereco = configuracao;
        _preencherEnderecoSeVazio('cep', configuracao.cep);
        _preencherEnderecoSeVazio('cidade', configuracao.cidade);
        _preencherEnderecoSeVazio('uf', configuracao.uf);
      });
    } catch (_) {
      // Mantem o preenchimento manual, como na tela completa de endereco.
    } finally {
      if (mounted) setState(() => _carregandoEndereco = false);
    }
  }

  void _preencherEnderecoSeVazio(String campo, String valor) {
    final controller = _enderecoControllers[campo];
    if (controller == null ||
        valor.isEmpty ||
        controller.text.trim().isNotEmpty) {
      return;
    }
    controller.text = campo == 'uf' ? valor.toUpperCase() : valor;
  }

  Future<ResultadoCadastroCliente> _cadastrarCliente() {
    final callback = widget.aoCadastrarCliente;
    if (callback != null) {
      return callback(
        _nomeController.text.trim(),
        _celularController.text,
        _emailController.text.trim(),
        _observacaoController.text.trim(),
      );
    }
    return Modular.get<ProvedorComanda>().inserirCliente(
      _nomeController.text.trim(),
      _celularController.text,
      _emailController.text.trim(),
      _observacaoController.text.trim(),
    );
  }

  Future<void> _salvarEnderecoPadrao(String idCliente) async {
    await widget.servicoEndereco!.salvar('clientes/inserir_endereco.php', {
      for (final campo in _enderecoControllers.entries)
        campo.key: campo.value.text.trim(),
      'uf': _enderecoControllers['uf']!.text.trim().toUpperCase(),
      'complemento': '',
      'id': '',
      'idCliente': idCliente,
      'padrao': 'Sim',
      'podeInserirNovaCidade': false,
    });
  }

  Future<void> _salvar() async {
    if (_salvando || _carregandoEndereco) return;

    if (_nomeController.text.trim().isEmpty) {
      _mostrarMensagem('Informe o nome do cliente', sucesso: false);
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) return;

    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _salvando = true);

    try {
      if (_idClienteCriado == null) {
        final resposta = await _cadastrarCliente();
        if (!mounted) return;
        if (!resposta.sucesso) {
          setState(() => _salvando = false);
          _mostrarMensagem(resposta.mensagem, sucesso: false);
          return;
        }
        _idClienteCriado = resposta.idcliente;
        _nomeClienteCriado = resposta.nomecliente;
        _mensagemClienteCriado = resposta.mensagem;
      }

      if (_incluiEndereco) {
        await _salvarEnderecoPadrao(_idClienteCriado!);
      }
      if (!mounted) return;

      _mostrarMensagem(
        _incluiEndereco
            ? 'Cliente e endereço cadastrados com sucesso'
            : (_mensagemClienteCriado ?? 'Cliente cadastrado com sucesso'),
        sucesso: true,
      );
      Navigator.pop(context, {
        'idcliente': _idClienteCriado,
        'nomecliente': _nomeClienteCriado,
        'enderecoPadraoCriado': _incluiEndereco,
      });
    } catch (erro) {
      if (!mounted) return;
      setState(() => _salvando = false);
      _mostrarMensagem(
        erro is StateError
            ? erro.message.toString()
            : _idClienteCriado != null
                ? 'Cliente cadastrado. Não foi possível salvar o endereço; tente novamente.'
                : 'Não foi possível cadastrar o cliente.',
        sucesso: false,
      );
    }
  }

  void _mostrarMensagem(String mensagem, {required bool sucesso}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor: sucesso ? Colors.green.shade600 : cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }

  String? _validarEndereco(String campo, String? valor) {
    if (!_incluiEndereco || !_configuracaoEndereco.enderecoObrigatorio) {
      return null;
    }
    const obrigatorios = {'endereco', 'numero', 'bairro', 'cidade', 'uf'};
    return obrigatorios.contains(campo) && (valor?.trim().isEmpty ?? true)
        ? 'Campo obrigatório'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: const Text('Cadastrar cliente',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _salvando || _carregandoEndereco ? null : _salvar,
            icon: _salvando || _carregandoEndereco
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              _carregandoEndereco
                  ? 'Carregando dados...'
                  : _salvando
                      ? 'Salvando...'
                      : _incluiEndereco
                          ? 'Salvar cliente e endereço'
                          : 'Salvar cliente',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Form(
          key: _form,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            children: [
              _CartaoCabecalho(incluirEndereco: _incluiEndereco),
              const SizedBox(height: 18),
              const _LabelCampo(
                  icone: Icons.badge_outlined,
                  texto: 'Nome',
                  obrigatorio: true),
              const SizedBox(height: 8),
              _CampoTexto(
                campoKey: const ValueKey('cliente-nome'),
                controller: _nomeController,
                hint: 'Nome completo',
                icone: Icons.person_outline_rounded,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 18),
              const _LabelCampo(icone: Icons.phone_outlined, texto: 'Celular'),
              const SizedBox(height: 8),
              _CampoTexto(
                campoKey: const ValueKey('cliente-celular'),
                controller: _celularController,
                hint: '(00) 00000-0000',
                icone: Icons.phone_iphone_rounded,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  TelefoneInputFormatter(),
                ],
              ),
              if (_incluiEndereco) ...[
                const SizedBox(height: 24),
                _CabecalhoEndereco(carregando: _carregandoEndereco),
                const SizedBox(height: 16),
                if (_carregandoEndereco) const LinearProgressIndicator(),
                if (!_carregandoEndereco)
                  for (final campo in const [
                    ('cep', 'CEP', Icons.location_searching_outlined),
                    ('endereco', 'Rua / avenida', Icons.signpost_outlined),
                    ('numero', 'Número', Icons.pin_outlined),
                    ('bairro', 'Bairro', Icons.location_city_outlined),
                    ('cidade', 'Cidade', Icons.apartment_outlined),
                    ('uf', 'UF', Icons.map_outlined),
                  ]) ...[
                    _LabelCampo(
                      icone: campo.$3,
                      texto: campo.$2,
                      obrigatorio: campo.$1 != 'cep' &&
                          _configuracaoEndereco.enderecoObrigatorio,
                    ),
                    const SizedBox(height: 8),
                    _CampoTexto(
                      campoKey: ValueKey('cliente-${campo.$1}'),
                      controller: _enderecoControllers[campo.$1]!,
                      hint: campo.$2,
                      icone: campo.$3,
                      keyboardType: campo.$1 == 'cep' || campo.$1 == 'numero'
                          ? TextInputType.number
                          : TextInputType.streetAddress,
                      textInputAction: TextInputAction.next,
                      textCapitalization: campo.$1 == 'uf'
                          ? TextCapitalization.characters
                          : TextCapitalization.words,
                      inputFormatters: campo.$1 == 'cep'
                          ? [
                              FilteringTextInputFormatter.digitsOnly,
                              CepInputFormatter(),
                            ]
                          : null,
                      maxLength: campo.$1 == 'uf' ? 2 : null,
                      readOnly: _configuracaoEndereco.bloquearCidade &&
                          (campo.$1 == 'cidade' || campo.$1 == 'uf'),
                      validator: (valor) => _validarEndereco(campo.$1, valor),
                    ),
                    const SizedBox(height: 18),
                  ],
              ],
              const _LabelCampo(
                  icone: Icons.alternate_email_rounded, texto: 'E-mail'),
              const SizedBox(height: 8),
              _CampoTexto(
                campoKey: const ValueKey('cliente-email'),
                controller: _emailController,
                hint: 'cliente@email.com',
                icone: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 18),
              const _LabelCampo(
                  icone: Icons.notes_rounded, texto: 'Observação'),
              const SizedBox(height: 8),
              _CampoTexto(
                campoKey: const ValueKey('cliente-observacao'),
                controller: _observacaoController,
                hint: 'Anotações sobre o cliente...',
                icone: Icons.sticky_note_2_outlined,
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartaoCabecalho extends StatelessWidget {
  final bool incluirEndereco;

  const _CartaoCabecalho({required this.incluirEndereco});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
              color: cs.shadow.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_add_alt_1_rounded,
                size: 28, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOVO CADASTRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dados do cliente',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  incluirEndereco
                      ? 'O endereço será salvo como padrão.'
                      : 'Apenas o nome é obrigatório.',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CabecalhoEndereco extends StatelessWidget {
  final bool carregando;

  const _CabecalhoEndereco({required this.carregando});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.home_work_outlined, color: cs.onPrimaryContainer),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Endereço de entrega',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            Text(
              carregando
                  ? 'Carregando regras do cadastro...'
                  : 'Será selecionado como endereço padrão',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    ]);
  }
}

class _LabelCampo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool obrigatorio;

  const _LabelCampo({
    required this.icone,
    required this.texto,
    this.obrigatorio = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icone, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
              letterSpacing: 0.1),
        ),
        if (obrigatorio) ...[
          const SizedBox(width: 4),
          Text('*',
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: cs.error)),
        ],
      ],
    );
  }
}

class _CampoTexto extends StatelessWidget {
  final Key? campoKey;
  final TextEditingController controller;
  final String hint;
  final IconData icone;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final String? Function(String?)? validator;

  const _CampoTexto({
    this.campoKey,
    required this.controller,
    required this.hint,
    required this.icone,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
    this.maxLength,
    this.readOnly = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: readOnly
            ? cs.surfaceContainerHighest.withValues(alpha: 0.6)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding:
          EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 4 : 2),
      child: Row(
        crossAxisAlignment:
            maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(icone, size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              key: campoKey,
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              minLines: maxLines > 1 ? maxLines - 1 : 1,
              maxLength: maxLength,
              readOnly: readOnly,
              validator: validator,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle:
                    TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
