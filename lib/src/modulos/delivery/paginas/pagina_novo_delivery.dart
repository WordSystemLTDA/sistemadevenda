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

class PaginaNovoDelivery extends StatefulWidget {
  final ServicoDelivery servico;
  const PaginaNovoDelivery({super.key, required this.servico});
  @override
  State<PaginaNovoDelivery> createState() => _PaginaNovoDeliveryState();
}

class _PaginaNovoDeliveryState extends State<PaginaNovoDelivery> {
  final _observacao = TextEditingController();
  String _tipo = '1', _cliente = '0', _nome = '', _telefone = '';
  Map<String, dynamic>? _endereco;
  List<Map<String, dynamic>> _enderecos = [];
  bool _carregando = false, _salvando = false;
  String? _erro;
  String? _idCriado;
  ConfigDelivery? _config;
  double get _taxa => _tipo == '1'
      ? _config?.taxaEntrega(_endereco?['valortaxabairro']) ?? 0
      : 0;
  int _consulta = 0;
  @override
  void dispose() {
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _selecionarCliente({bool novo = false}) async {
    Map<String, dynamic>? resultado;
    if (novo) {
      final res = await Navigator.push<Map<String, dynamic>>(
          context, MaterialPageRoute(builder: (_) => const InserirCliente()));
      if (res != null) {
        resultado = {'id': res['idcliente'], 'nome': res['nomecliente']};
      }
    } else {
      resultado = await buscarDelivery(
        context,
        titulo: 'Selecionar cliente',
        buscar: (termo) async =>
            (await Modular.get<ServicoBalcao>().listarClientes(termo))
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList(),
        nome: (e) => '${e['nome'] ?? ''}',
        detalhe: (e) => '${e['celular'] ?? ''}',
      );
    }
    if (!mounted || resultado == null) return;
    setState(() {
      _cliente = '${resultado!['id']}';
      _nome = '${resultado['nome'] ?? ''}';
      _telefone = '${resultado['celular'] ?? ''}';
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

  Future<void> _abrir() async {
    if (_salvando) return;
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
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => PaginaCardapio(
                    tipo: TipoCardapio.delivery,
                    id: id,
                    idCliente: _cliente,
                    tipodeentrega: _tipo,
                    nomeAtendimento: 'Delivery #$id',
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
              title: const Text('Novo Delivery'),
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
                          : const Icon(Icons.restaurant_menu),
                      label: Text(_salvando
                          ? 'Abrindo pedido...'
                          : 'Abrir cardápio')))),
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
                            _titulo('Tipo de entrega', Icons.delivery_dining),
                            Wrap(spacing: 8, runSpacing: 4, children: [
                              for (final opcao in const [
                                ('1', 'Entrega', Icons.delivery_dining),
                                ('2', 'Retirada', Icons.shopping_bag_outlined),
                                ('3', 'No local', Icons.restaurant_outlined)
                              ])
                                ChoiceChip(
                                    avatar: Icon(opcao.$3, size: 18),
                                    label: Text(opcao.$2),
                                    selected: _tipo == opcao.$1,
                                    onSelected: _salvando
                                        ? null
                                        : (_) =>
                                            setState(() => _tipo = opcao.$1)),
                            ]),
                            const SizedBox(height: 20),
                            Row(children: [
                              Expanded(
                                  child:
                                      _titulo('Cliente', Icons.person_outline)),
                              IconButton(
                                  tooltip: 'Cadastrar cliente',
                                  onPressed: _salvando
                                      ? null
                                      : () => _selecionarCliente(novo: true),
                                  icon: const Icon(
                                      Icons.person_add_alt_1_outlined))
                            ]),
                            ListTile(
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
                                IconButton(
                                    tooltip: 'Cadastrar endereço',
                                    onPressed: _cliente == '0' || _salvando
                                        ? null
                                        : () async {
                                            final salvo = await Navigator.push<
                                                    bool>(
                                                context,
                                                MaterialPageRoute(
                                                    builder: (_) =>
                                                        EnderecoDelivery(
                                                            servico:
                                                                widget.servico,
                                                            cliente:
                                                                _cliente)));
                                            if (mounted && salvo == true) {
                                              await _carregarEnderecos();
                                            }
                                          },
                                    icon: const Icon(
                                        Icons.add_location_alt_outlined)),
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
                            if (_erro != null)
                              Text(_erro!, style: TextStyle(color: cs.error)),
                          ])))),
        ));
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
}
