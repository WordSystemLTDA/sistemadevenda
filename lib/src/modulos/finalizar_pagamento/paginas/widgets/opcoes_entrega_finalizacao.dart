import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class OpcoesEntregaFinalizacao extends StatefulWidget {
  final ValueChanged<PedidoDelivery> aoAtualizar;
  final ValueChanged<bool>? aoAlterarCarregamento;

  const OpcoesEntregaFinalizacao({
    super.key,
    required this.aoAtualizar,
    this.aoAlterarCarregamento,
  });

  @override
  State<OpcoesEntregaFinalizacao> createState() =>
      _OpcoesEntregaFinalizacaoState();
}

class _OpcoesEntregaFinalizacaoState extends State<OpcoesEntregaFinalizacao> {
  final _servico = Modular.get<ServicoDelivery>();
  final _pagamento = Modular.get<ProvedorFinalizarPagamento>();
  final _cardapio = Modular.get<ProvedorCardapio>();
  final _controladorEnderecos = ExpansibleController();

  PedidoDelivery? _pedido;
  ConfigDelivery? _config;
  List<Map<String, dynamic>> _enderecos = const [];
  String? _enderecoSelecionado;
  String? _erro;
  bool _carregando = true;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _pagamento.addListener(_sincronizarPedido);
    _carregar();
  }

  @override
  void dispose() {
    _pagamento.removeListener(_sincronizarPedido);
    _controladorEnderecos.dispose();
    super.dispose();
  }

  void _sincronizarPedido() {
    final pedido = _pagamento.pedidoDelivery;
    if (!mounted || pedido == null || identical(pedido, _pedido)) return;
    setState(() {
      _pedido = pedido;
      if (pedido.tipoEntrega == '1') {
        final id = pedido.texto('idendereco').trim();
        if (id.isNotEmpty && id != '0') _enderecoSelecionado = id;
      }
    });
  }

  String _idEndereco(Map<String, dynamic> endereco) =>
      endereco['id']?.toString() ?? '';

  bool _enderecoPadrao(Map<String, dynamic> endereco) {
    final valor = endereco['padrao']?.toString().trim().toLowerCase() ?? '';
    return {'sim', 's', '1', 'true'}.contains(valor);
  }

  Future<void> _carregar() async {
    if (_cardapio.tipo != TipoCardapio.delivery) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final pedido = _pagamento.pedidoDelivery ??
          await _servico.pedido(_pagamento.idVenda);
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        if (pedido.tipoEntrega == '1') {
          final id = pedido.texto('idendereco').trim();
          if (id.isNotEmpty && id != '0') _enderecoSelecionado = id;
        }
      });
      if (_pagamento.pedidoDelivery == null) {
        _pagamento.atualizarPedidoDelivery(pedido);
      }
      final config = await _servico.configuracao();
      final resposta = (int.tryParse(pedido.cliente) ?? 0) > 0
          ? await _servico.consultar(
              'enderecos_clientes/listar_por_cliente.php',
              {'cliente': pedido.cliente, 'pesquisa': ''},
            )
          : const <dynamic>[];
      final enderecos = [
        for (final item in resposta as List)
          Map<String, dynamic>.from(item as Map),
      ];
      final enderecoPedido =
          pedido.tipoEntrega == '1' ? pedido.texto('idendereco').trim() : '';
      final ultimoEndereco = _pagamento.ultimoEnderecoDelivery ?? '';
      final selecionado = enderecos
              .where((item) => _idEndereco(item) == enderecoPedido)
              .firstOrNull ??
          enderecos
              .where((item) => _idEndereco(item) == ultimoEndereco)
              .firstOrNull ??
          enderecos.where(_enderecoPadrao).firstOrNull ??
          enderecos.firstOrNull;
      if (!mounted) return;
      setState(() {
        _pedido = pedido;
        _config = config;
        _enderecos = enderecos;
        _enderecoSelecionado =
            selecionado == null ? null : _idEndereco(selecionado);
        _carregando = false;
      });
      if (_cardapio.tipodeentrega != pedido.tipoEntrega) {
        _cardapio.tipodeentrega = pedido.tipoEntrega;
      }
    } catch (erro) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _erro = erro is StateError
            ? erro.message.toString()
            : 'Não foi possível carregar as opções do Delivery.';
      });
    }
  }

  Map<String, dynamic>? get _enderecoAtual => _enderecos
      .where((item) => _idEndereco(item) == _enderecoSelecionado)
      .firstOrNull;

  String _textoEndereco(Map<String, dynamic> endereco) {
    final linha = [
      endereco['endereco']?.toString().trim() ?? '',
      endereco['numero']?.toString().trim() ?? '',
    ].where((item) => item.isNotEmpty).join(', ');
    final detalhe = [
      endereco['bairro']?.toString().trim() ?? '',
      endereco['cidade']?.toString().trim() ?? '',
    ].where((item) => item.isNotEmpty).join(' · ');
    return [linha, detalhe].where((item) => item.isNotEmpty).join(' — ');
  }

  Future<void> _alterarTipo(String tipo) async {
    final pedido = _pedido;
    if (pedido == null || _salvando || pedido.tipoEntrega == tipo) return;
    if (tipo != '1') {
      await _salvar(tipo: tipo, endereco: null, taxa: 0);
      return;
    }
    final endereco = _enderecoAtual;
    if (endereco == null) {
      setState(() => _erro = 'Selecione um endereço para entrega.');
      _controladorEnderecos.expand();
      return;
    }
    final taxa = _config?.taxaEntrega(endereco['valortaxabairro']);
    if (taxa == null) {
      setState(() => _erro = 'Não foi possível calcular a taxa de entrega.');
      return;
    }
    await _salvar(tipo: tipo, endereco: endereco, taxa: taxa);
  }

  Future<void> _selecionarEndereco(Map<String, dynamic> endereco) async {
    if (_salvando || _pedido?.tipoEntrega != '1') return;
    final id = _idEndereco(endereco);
    if (id == _enderecoSelecionado) return;
    final taxa = _config?.taxaEntrega(endereco['valortaxabairro']);
    if (taxa == null) {
      setState(() => _erro = 'Não foi possível calcular a taxa de entrega.');
      return;
    }
    await _salvar(tipo: '1', endereco: endereco, taxa: taxa);
  }

  Future<void> _salvar({
    required String tipo,
    required Map<String, dynamic>? endereco,
    required double taxa,
  }) async {
    final pedido = _pedido;
    if (pedido == null || _salvando) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _salvando = true;
      _erro = null;
    });
    widget.aoAlterarCarregamento?.call(true);
    try {
      final atualizado = await _servico.alterarEntrega(
        pedido,
        tipo: tipo,
        endereco: endereco == null ? '0' : _idEndereco(endereco),
        taxa: taxa,
        dadosEndereco: endereco,
      );
      if (!mounted) return;
      _pagamento.atualizarPedidoDelivery(atualizado);
      _cardapio.tipodeentrega = atualizado.tipoEntrega;
      setState(() {
        _pedido = atualizado;
        if (tipo == '1' && endereco != null) {
          _enderecoSelecionado = _idEndereco(endereco);
        }
      });
      widget.aoAtualizar(atualizado);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _erro = erro is StateError
          ? erro.message.toString()
          : 'Não foi possível atualizar o Delivery.');
    } finally {
      widget.aoAlterarCarregamento?.call(false);
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pedido = _pedido;
    final tipo = pedido?.tipoEntrega ?? _cardapio.tipodeentrega;
    final endereco = _enderecoAtual;
    final enderecoResumo = tipo == '1'
        ? (endereco == null
            ? (pedido?.endereco.isNotEmpty == true
                ? pedido!.endereco
                : 'Nenhum endereço selecionado')
            : _textoEndereco(endereco))
        : 'Disponível ao selecionar Entrega';

    return AbsorbPointer(
      absorbing: _salvando,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.delivery_dining_outlined, size: 19, color: cs.primary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Tipo de entrega',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          if (_salvando)
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ]),
        const SizedBox(height: 10),
        if (_carregando)
          const LinearProgressIndicator(minHeight: 2)
        else
          Row(children: [
            for (final opcao in const [
              ('1', 'Entrega', Icons.delivery_dining_rounded),
              ('2', 'Retirada', Icons.shopping_bag_outlined),
              ('3', 'No local', Icons.restaurant_outlined),
            ]) ...[
              Expanded(
                child: _OpcaoTipoEntrega(
                  key: ValueKey('tipo-entrega-finalizacao-${opcao.$1}'),
                  nome: opcao.$2,
                  icone: opcao.$3,
                  selecionada: tipo == opcao.$1,
                  onTap: _erro != null && pedido == null
                      ? null
                      : () => _alterarTipo(opcao.$1),
                ),
              ),
              if (opcao.$1 != '3') const SizedBox(width: 8),
            ],
          ]),
        const SizedBox(height: 10),
        Material(
          color: cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: ExpansionTile(
            key: const ValueKey('opcoes-endereco-finalizacao'),
            controller: _controladorEnderecos,
            enabled: !_carregando && pedido != null,
            initiallyExpanded: false,
            maintainState: true,
            tilePadding: const EdgeInsets.symmetric(horizontal: 12),
            childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            leading: Icon(Icons.location_on_outlined, color: cs.primary),
            title: const Text('Opções de Endereço',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              enderecoResumo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            children: [
              if (tipo != '1')
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Selecione Entrega para escolher um endereço.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else if (_enderecos.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Nenhum endereço cadastrado para este cliente.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              else
                for (final item in _enderecos)
                  _OpcaoEndereco(
                    endereco: item,
                    texto: _textoEndereco(item),
                    selecionada: _idEndereco(item) == _enderecoSelecionado,
                    onTap: () => _selecionarEndereco(item),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tipo == '1'
              ? 'Taxa de entrega: ${(pedido?.taxaEntrega ?? 0).obterReal()}'
              : 'Sem taxa de entrega',
          style: TextStyle(
            color: tipo == '1' ? cs.primary : cs.onSurfaceVariant,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (_erro != null) ...[
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.error_outline_rounded, size: 18, color: cs.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(_erro!,
                  style: TextStyle(color: cs.error, fontSize: 12.5)),
            ),
            if (pedido == null)
              TextButton(onPressed: _carregar, child: const Text('Tentar')),
          ]),
        ],
      ]),
    );
  }
}

class _OpcaoTipoEntrega extends StatelessWidget {
  final String nome;
  final IconData icone;
  final bool selecionada;
  final VoidCallback? onTap;

  const _OpcaoTipoEntrega({
    super.key,
    required this.nome,
    required this.icone,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selecionada
          ? cs.primaryContainer.withValues(alpha: 0.65)
          : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selecionada ? cs.primary : cs.outlineVariant,
          width: selecionada ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 72,
          child: Stack(children: [
            Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icone,
                    size: 23,
                    color: selecionada ? cs.primary : cs.onSurfaceVariant),
                const SizedBox(height: 5),
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selecionada ? cs.primary : cs.onSurface,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ]),
            ),
            if (selecionada)
              Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.check_circle_rounded,
                    size: 16, color: cs.primary),
              ),
          ]),
        ),
      ),
    );
  }
}

class _OpcaoEndereco extends StatelessWidget {
  final Map<String, dynamic> endereco;
  final String texto;
  final bool selecionada;
  final VoidCallback onTap;

  const _OpcaoEndereco({
    required this.endereco,
    required this.texto,
    required this.selecionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: selecionada
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(children: [
              Icon(
                selecionada
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selecionada ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(texto,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (_enderecoPadrao(endereco)) ...[
                const SizedBox(width: 6),
                Icon(Icons.home_rounded, size: 16, color: cs.primary),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  bool _enderecoPadrao(Map<String, dynamic> endereco) {
    final valor = endereco['padrao']?.toString().trim().toLowerCase() ?? '';
    return {'sim', 's', '1', 'true'}.contains(valor);
  }
}
