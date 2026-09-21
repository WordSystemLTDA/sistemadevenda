import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/busca_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/endereco_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/campos_recorrencia.dart';

class PaginaNovoDelivery extends StatefulWidget {
  final bool recorrente;
  final ServicoDelivery servico;
  final PedidoDelivery? clonar;
  final bool semCliente;
  final PedidoDelivery? editarPedido;
  final Future<void> Function(Map<String, dynamic>)? aoSalvarEdicao;
  final bool permitirEntrega;
  const PaginaNovoDelivery(
      {super.key,
      this.recorrente = false,
      required this.servico,
      this.clonar,
      this.semCliente = false,
      this.editarPedido,
      this.aoSalvarEdicao,
      this.permitirEntrega = true});
  @override
  State<PaginaNovoDelivery> createState() => _PaginaNovoDeliveryState();
}

class _PaginaNovoDeliveryState extends State<PaginaNovoDelivery> {
  ConfiguracaoRecorrencia _recorrencia = const ConfiguracaoRecorrencia();
  final _chaveRecorrencia = ServicosRecorrentes.novaChave();
  final _observacao = TextEditingController();
  String _tipo = '1', _cliente = '0', _nome = '', _telefone = '';
  Map<String, dynamic>? _endereco;
  List<Map<String, dynamic>> _enderecos = [];
  bool _carregando = false, _salvando = false;
  String? _erro;
  String? _idCriado;
  MensagemClienteDelivery? _mensagemEnviando;
  ConfigDelivery? _config;
  double get _taxa {
    if (_tipo != '1') return 0;
    final original = widget.editarPedido;
    if (original != null &&
        original.tipoEntrega == _tipo &&
        original.cliente == _cliente &&
        original.texto('idendereco') == '${_endereco?['id']}') {
      return original.taxaEntrega;
    }
    return _config?.taxaEntrega(_endereco?['valortaxabairro']) ?? 0;
  }

  int _consulta = 0;
  bool _clonePreparado = false;
  @override
  void initState() {
    super.initState();
    final base = widget.editarPedido ?? widget.clonar;
    if (base != null) {
      _observacao.text = base.observacao;
      _tipo = base.tipoEntrega;
      if (!widget.semCliente) {
        _cliente = base.cliente;
        _nome = base.nome;
        _telefone = base.texto('celularCliente');
        _endereco = {'id': base.texto('idendereco')};
        _carregarEnderecos();
      }
    }
  }

  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  String _textoCliente(Map<String, dynamic> dados, List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  String _formatarTelefoneCliente(String valor) {
    final texto = valor.trim();
    if (texto.isEmpty) return '';
    final digitos = texto.replaceAll(RegExp(r'\D'), '');
    if (digitos.length < 8) return texto;
    return UtilBrasilFields.obterTelefone(digitos);
  }

  String _nomeClienteBusca(Map<String, dynamic> dados) {
    final nome = _textoCliente(
        dados, ['nome_puro', 'nomePuro', 'nomeCliente', 'nomecliente', 'nome']);
    if (nome.isNotEmpty) return nome;
    return _textoCliente(dados, ['razao_social', 'razaoSocial']);
  }

  String _detalheClienteBusca(Map<String, dynamic> dados) {
    final nome = _nomeClienteBusca(dados);
    final razao = _textoCliente(dados, ['razao_social', 'razaoSocial']);
    final celular = _formatarTelefoneCliente(
        _textoCliente(dados, ['celular', 'telefone', 'celularCliente']));
    return [
      'Celular: ${celular.isEmpty ? 'Sem celular' : celular}',
      if (razao.isNotEmpty && razao != nome) 'Razão social: $razao',
    ].join('\n');
  }

  Future<Map<String, dynamic>?> _cadastrarCliente(BuildContext context) async {
    final res = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
            builder: (_) => InserirCliente(servicoEndereco: widget.servico)));
    if (res == null) return null;
    return {'id': res['idcliente'], 'nome': res['nomecliente']};
  }

  Future<void> _selecionarCliente({bool novo = false}) async {
    Map<String, dynamic>? resultado;
    if (novo) {
      resultado = await _cadastrarCliente(context);
    } else {
      resultado = await buscarDelivery(
        context,
        titulo: 'Selecionar cliente',
        buscar: (termo) async =>
            (await Modular.get<ServicoBalcao>().listarClientes(termo))
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
        nome: _nomeClienteBusca,
        detalhe: _detalheClienteBusca,
        novo: _cadastrarCliente,
        buscarCelular: true,
      );
    }
    if (!mounted || resultado == null) return;
    setState(() {
      _cliente = '${resultado!['id']}';
      _nome = _nomeClienteBusca(resultado);
      _telefone = _formatarTelefoneCliente(
          _textoCliente(resultado, ['celular', 'telefone', 'celularCliente']));
      _endereco = null;
      _enderecos = [];
    });
    await _carregarEnderecos();
  }

  Future<void> _carregarEnderecos() async {
    final consulta = ++_consulta;
    final cliente = _cliente;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final config =
          await widget.servico.consultar('config_bigchef/listar.php');
      final dados = await widget.servico.consultar(
          'enderecos_clientes/listar_por_cliente.php',
          {'cliente': cliente, 'pesquisa': ''});
      if (!mounted || consulta != _consulta || cliente != _cliente) return;
      setState(() {
        _config =
            ConfigDelivery.fromMap(Map<String, dynamic>.from(config as Map));
        _enderecos = [
          for (final e in dados as List) Map<String, dynamic>.from(e as Map)
        ];
        _endereco =
            _enderecos.where((e) => e['id'] == _endereco?['id']).firstOrNull ??
                _enderecos.where((e) => e['padrao'] == 'Sim').firstOrNull ??
                (_enderecos.length == 1 ? _enderecos.first : null);
      });
    } catch (_) {
      if (mounted && consulta == _consulta) {
        setState(() => _erro = 'Não foi possível carregar os endereços.');
      }
    } finally {
      if (mounted && consulta == _consulta) setState(() => _carregando = false);
    }
  }

  Future<void> _abrirEndereco({Map<String, dynamic>? endereco}) async {
    if (_cliente == '0' || _salvando) return;
    final salvo = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
            builder: (_) => EnderecoDelivery(
                  servico: widget.servico,
                  cliente: _cliente,
                  endereco: endereco,
                )));
    if (!mounted || salvo != true) return;
    if (endereco != null) _endereco = endereco;
    await _carregarEnderecos();
  }

  Future<void> _notificarCliente(MensagemClienteDelivery mensagem) async {
    if (_cliente == '0' || _mensagemEnviando != null || _salvando) return;
    if (mensagem == MensagemClienteDelivery.confirmarEndereco &&
        (_tipo != '1' || _endereco == null)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _mensagemEnviando = mensagem);
    try {
      final retorno = await widget.servico.notificarCliente(
        mensagem,
        cliente: _cliente,
        endereco: _tipo == '1' ? '${_endereco?['id'] ?? '0'}' : '0',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(retorno),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ));
    } catch (erro) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(erro is StateError
              ? erro.message.toString()
              : 'Não foi possível enviar a mensagem.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
    } finally {
      if (mounted) setState(() => _mensagemEnviando = null);
    }
  }

  Future<void> _abrir() async {
    if (_salvando) return;
    if (widget.recorrente && (_cliente == '0' || _recorrencia.erro != null)) {
      setState(() =>
          _erro = _recorrencia.erro ?? 'Selecione um cliente cadastrado.');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_erro!)));
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    if (_tipo == '1' &&
        (_cliente == '0' ||
            _endereco == null ||
            _carregando ||
            _config == null)) {
      setState(() => _erro = 'Selecione o cliente e o endereço para entrega.');
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      if (widget.editarPedido != null) {
        await widget.aoSalvarEdicao!({
          'cliente': _cliente,
          'endereco': _tipo == '1' ? '${_endereco?['id'] ?? '0'}' : '0',
          'tipoentrega': _tipo,
          'taxa': _taxa.toStringAsFixed(2),
          'observacao': _observacao.text.trim(),
        });
        if (mounted) Navigator.pop(context, true);
        return;
      }
      if (widget.recorrente) {
        _idCriado ??= await ServicosRecorrentes(
                Modular.get<DioCliente>(), Modular.get<UsuarioProvedor>())
            .inserir(
          chave: _chaveRecorrencia,
          cliente: _cliente,
          endereco: '${_endereco?['id'] ?? '0'}',
          tipoEntrega: _tipo,
          observacao: _observacao.text.trim(),
          configuracao: _recorrencia,
        );
      }
      _idCriado ??= await widget.servico.criar(
          cliente: _cliente,
          endereco: '${_endereco?['id'] ?? '0'}',
          tipo: _tipo,
          observacao: _observacao.text.trim());
      final id = _idCriado!;
      await widget.servico
          .salvar('cardapio/editar_tipo_de_entrega_cliente.php', {
        'id_delivery': id,
        'tipo_de_entrega': _tipo,
        'novo_valor_entrega': _taxa.toStringAsFixed(2),
      });
      if (widget.clonar != null && !_clonePreparado) {
        await widget.servico.prepararClone(id, widget.clonar!.produtos);
        _clonePreparado = true;
      }
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaCardapio(
                    tipo: TipoCardapio.delivery,
                    id: id,
                    idCliente: _cliente,
                    tipodeentrega: _tipo,
                    nomeAtendimento: widget.recorrente
                        ? 'Modelo recorrente'
                        : 'Delivery #$id',
                    modeloRecorrente: widget.recorrente,
                  )));
    } catch (e) {
      if (mounted) {
        setState(() {
          _salvando = false;
          _erro = e is StateError
              ? e.message.toString()
              : 'Não foi possível confirmar. Atualize o Delivery antes de tentar novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !_salvando,
        child: Scaffold(
          appBar: AppBar(
              title: Text(widget.editarPedido != null
                  ? 'Editar pedido'
                  : widget.recorrente
                      ? 'Novo Recorrente'
                      : 'Novo Delivery'),
              backgroundColor: cs.inversePrimary),
          bottomNavigationBar: SafeArea(
              top: false,
              minimum: const EdgeInsets.all(16),
              child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                      onPressed: _salvando ? null : _abrir,
                      icon: _salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(widget.editarPedido != null
                              ? Icons.check
                              : Icons.restaurant_menu),
                      label: Text(_salvando
                          ? (widget.editarPedido != null
                              ? 'Salvando...'
                              : 'Abrindo pedido...')
                          : (widget.editarPedido != null
                              ? 'Salvar alterações'
                              : 'Abrir cardápio'))))),
          body: AbsorbPointer(
              absorbing: _idCriado != null,
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
                      child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (widget.recorrente) ...[
                              CamposRecorrencia(
                                  valor: _recorrencia,
                                  primeiroPedido: true,
                                  onChanged: (valor) =>
                                      setState(() => _recorrencia = valor)),
                              const Divider(height: 32),
                            ],
                            _titulo('Tipo de entrega', Icons.delivery_dining),
                            Row(children: [
                              for (final opcao in [
                                if (widget.permitirEntrega)
                                  ('1', 'Entrega', Icons.delivery_dining),
                                ('2', 'Retirada', Icons.shopping_bag_outlined),
                                if (!widget.recorrente)
                                  ('3', 'No local', Icons.restaurant_outlined)
                              ]) ...[
                                Expanded(
                                  child: _cardTipoEntrega(
                                      valor: opcao.$1,
                                      texto: opcao.$2,
                                      icone: opcao.$3),
                                ),
                                if (opcao.$1 != '3') const SizedBox(width: 8),
                              ]
                            ]),
                            const SizedBox(height: 20),
                            _titulo('Cliente', Icons.person_outline),
                            ListTile(
                                key: const ValueKey('selecionar-cliente'),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: cs.outlineVariant)),
                                tileColor: cs.surfaceContainerLowest,
                                leading:
                                    const Icon(Icons.person_search_outlined),
                                title: Text(_nome.isEmpty
                                    ? 'Selecionar cliente'
                                    : _nome),
                                subtitle:
                                    _telefone.isEmpty ? null : Text(_telefone),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _salvando ? null : _selecionarCliente),
                            const SizedBox(height: 8),
                            SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: FilledButton.tonalIcon(
                                    key: const ValueKey('novo-cliente'),
                                    onPressed: _salvando
                                        ? null
                                        : () => _selecionarCliente(novo: true),
                                    icon: const Icon(
                                        Icons.person_add_alt_1_outlined),
                                    label: const Text('Novo Cliente'))),
                            if (_tipo == '1') ...[
                              const SizedBox(height: 20),
                              Row(children: [
                                Expanded(
                                    child: _titulo('Endereço de entrega',
                                        Icons.location_on_outlined)),
                                IconButton(
                                    tooltip: 'Atualizar endereços',
                                    onPressed: _cliente == '0' || _carregando
                                        ? null
                                        : _carregarEnderecos,
                                    icon: const Icon(Icons.refresh)),
                              ]),
                              if (_carregando)
                                const LinearProgressIndicator()
                              else if (_enderecos.isEmpty)
                                Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    child: Text(
                                        _cliente == '0'
                                            ? 'Selecione um cliente'
                                            : 'Nenhum endereço cadastrado',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant)))
                              else
                                ..._enderecos.map((e) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      selected: e['id'] == _endereco?['id'],
                                      selectedTileColor: cs.primaryContainer
                                          .withValues(alpha: .4),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          side: BorderSide(
                                              color: e['id'] == _endereco?['id']
                                                  ? cs.primary
                                                  : cs.outlineVariant)),
                                      leading: Icon(e['id'] == _endereco?['id']
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked),
                                      trailing: IconButton(
                                          tooltip: 'Editar endereço',
                                          onPressed: _salvando
                                              ? null
                                              : () =>
                                                  _abrirEndereco(endereco: e),
                                          icon: const Icon(Icons
                                              .edit_location_alt_outlined)),
                                      title: Text(
                                          '${e['endereco']}, ${e['numero']}'),
                                      subtitle: Text([
                                        e['bairro'],
                                        e['cidade'],
                                        e['complemento']
                                      ]
                                          .where((s) =>
                                              s != null &&
                                              s.toString().isNotEmpty)
                                          .join(' · ')),
                                      onTap: _salvando
                                          ? null
                                          : () => setState(() => _endereco = e),
                                    ))),
                              const SizedBox(height: 8),
                              SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: FilledButton.tonalIcon(
                                      key: const ValueKey('novo-endereco'),
                                      onPressed: _cliente == '0' || _salvando
                                          ? null
                                          : () => _abrirEndereco(),
                                      icon: const Icon(
                                          Icons.add_location_alt_outlined),
                                      label: const Text('Novo endereço'))),
                              if (_endereco != null && !_carregando)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: Text(
                                        'Taxa de entrega: ${_taxa.obterReal()}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                            ],
                            const SizedBox(height: 20),
                            _titulo('Observação', Icons.edit_note),
                            TextField(
                                controller: _observacao,
                                maxLines: 3,
                                maxLength: 200,
                                enabled: !_salvando,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                onTapOutside: (_) => FocusManager
                                    .instance.primaryFocus
                                    ?.unfocus(),
                                decoration: const InputDecoration(
                                    hintText: 'Observação do pedido',
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 8),
                            _mensagensCliente(),
                            if (_erro != null)
                              Text(_erro!, style: TextStyle(color: cs.error)),
                          ])))),
        ));
  }

  Widget _mensagensCliente() {
    final confirmacaoEnderecoDisponivel =
        _tipo == '1' && _endereco != null && !_carregando;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _titulo('Mensagens no WhatsApp', Icons.chat_outlined),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 72,
          children: [
            _botaoMensagem(
              mensagem: MensagemClienteDelivery.confirmarEndereco,
              texto: 'Confirmar endereço',
              icone: Icons.add_location_alt_outlined,
              habilitado: confirmacaoEnderecoDisponivel,
            ),
            _botaoMensagem(
              mensagem: MensagemClienteDelivery.formaPagamento,
              texto: 'Forma de pagamento',
              icone: Icons.payments_outlined,
            ),
            _botaoMensagem(
              mensagem: MensagemClienteDelivery.oferecerBebida,
              texto: 'Oferecer bebida',
              icone: Icons.local_drink_outlined,
            ),
            _botaoMensagem(
              mensagem: MensagemClienteDelivery.algoMais,
              texto: 'Mais alguma coisa?',
              icone: Icons.add_comment_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _botaoMensagem({
    required MensagemClienteDelivery mensagem,
    required String texto,
    required IconData icone,
    bool habilitado = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final enviando = _mensagemEnviando == mensagem;
    final podeEnviar = _cliente != '0' &&
        habilitado &&
        _mensagemEnviando == null &&
        !_salvando;
    return OutlinedButton.icon(
      key: ValueKey('mensagem-delivery-${mensagem.codigo}'),
      onPressed: podeEnviar ? () => _notificarCliente(mensagem) : null,
      icon: enviando
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icone, size: 21),
      label: Text(
        texto,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: cs.primary,
        backgroundColor: cs.primaryContainer.withValues(alpha: .18),
        side: BorderSide(color: cs.primary.withValues(alpha: .4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _titulo(String texto, IconData icone) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
            child: Text(texto,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)))
      ]));

  Widget _cardTipoEntrega({
    required String valor,
    required String texto,
    required IconData icone,
  }) {
    final cs = Theme.of(context).colorScheme;
    final selecionado = _tipo == valor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: _salvando ? null : () => setState(() => _tipo = valor),
        child: AnimatedContainer(
          key: ValueKey('tipo-entrega-$valor'),
          duration: const Duration(milliseconds: 150),
          height: 90,
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
          decoration: BoxDecoration(
            color: selecionado
                ? cs.primaryContainer.withValues(alpha: .55)
                : cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selecionado ? cs.primary : cs.outlineVariant,
                width: selecionado ? 1.5 : 1),
          ),
          child: Stack(children: [
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          selecionado ? cs.primary : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icone,
                        size: 20,
                        color:
                            selecionado ? cs.onPrimary : cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(texto,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selecionado ? cs.primary : cs.onSurface)),
                  ),
                ],
              ),
            ),
            if (selecionado)
              Align(
                alignment: Alignment.topRight,
                child: Icon(Icons.check_circle, size: 18, color: cs.primary),
              ),
          ]),
        ),
      ),
    );
  }
}
