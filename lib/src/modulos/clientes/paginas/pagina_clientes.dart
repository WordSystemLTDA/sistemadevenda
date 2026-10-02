import 'dart:async';

import 'package:app/src/modulos/clientes/modelos/cliente_cadastro.dart';
import 'package:app/src/modulos/clientes/servicos/servico_clientes.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/endereco_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaClientes extends StatefulWidget {
  const PaginaClientes({super.key, this.repositorio});

  final RepositorioClientes? repositorio;

  @override
  State<PaginaClientes> createState() => _PaginaClientesState();
}

class _PaginaClientesState extends State<PaginaClientes> {
  final _pesquisaController = TextEditingController();
  late final RepositorioClientes _repositorio;
  Timer? _debounce;
  List<ClienteCadastro> _clientes = const [];
  final Map<String, List<EnderecoClienteCadastro>> _enderecos = {};
  final Set<String> _carregandoEnderecos = {};
  final Map<String, String> _errosEnderecos = {};
  bool _carregando = true;
  String? _erro;
  int _versaoConsulta = 0;

  @override
  void initState() {
    super.initState();
    _repositorio = widget.repositorio ?? Modular.get<RepositorioClientes>();
    unawaited(_carregarClientes());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _pesquisaController.dispose();
    super.dispose();
  }

  String _mensagemErro(Object erro, String fallback) {
    return erro is StateError ? erro.message.toString() : fallback;
  }

  Future<void> _carregarClientes() async {
    final versao = ++_versaoConsulta;
    if (mounted) {
      setState(() {
        _carregando = true;
        _erro = null;
      });
    }
    try {
      final clientes =
          await _repositorio.listarClientes(_pesquisaController.text);
      if (!mounted || versao != _versaoConsulta) return;
      final ids = clientes.map((cliente) => cliente.id).toSet();
      setState(() {
        _clientes = clientes;
        _enderecos.removeWhere((id, _) => !ids.contains(id));
        _errosEnderecos.removeWhere((id, _) => !ids.contains(id));
        _carregandoEnderecos.removeWhere((id) => !ids.contains(id));
        _carregando = false;
      });
      for (final cliente in clientes) {
        unawaited(_carregarEnderecos(cliente.id, versao: versao));
      }
    } catch (erro) {
      if (!mounted || versao != _versaoConsulta) return;
      setState(() {
        _carregando = false;
        _erro = _mensagemErro(
          erro,
          'Não foi possível carregar os clientes.',
        );
      });
    }
  }

  Future<void> _carregarEnderecos(
    String idCliente, {
    int? versao,
  }) async {
    final versaoEsperada = versao ?? _versaoConsulta;
    if (mounted) {
      setState(() {
        _carregandoEnderecos.add(idCliente);
        _errosEnderecos.remove(idCliente);
      });
    }
    try {
      final enderecos = await _repositorio.listarEnderecos(idCliente);
      if (!mounted || versaoEsperada != _versaoConsulta) return;
      final enderecosOrdenados = [
        ...enderecos.where((endereco) => endereco.padrao),
        ...enderecos.where((endereco) => !endereco.padrao),
      ];
      setState(() => _enderecos[idCliente] = enderecosOrdenados);
    } catch (erro) {
      if (!mounted || versaoEsperada != _versaoConsulta) return;
      setState(() {
        _errosEnderecos[idCliente] = _mensagemErro(
          erro,
          'Não foi possível carregar os endereços.',
        );
      });
    } finally {
      if (mounted && versaoEsperada == _versaoConsulta) {
        setState(() => _carregandoEnderecos.remove(idCliente));
      }
    }
  }

  void _aoPesquisar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _carregarClientes);
  }

  void _limparPesquisa() {
    unawaited(_recarregarTodosClientes());
  }

  Future<void> _recarregarTodosClientes() async {
    _debounce?.cancel();
    _pesquisaController.clear();
    await _carregarClientes();
  }

  Future<void> _abrirCadastro() async {
    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'CadastrarCliente'),
        builder: (_) => InserirCliente(
          servicoEndereco: _repositorio.servicoEndereco,
          aoCadastrarCliente: (nome, celular, email, observacao) =>
              _repositorio.cadastrarCliente(
            nome,
            celular,
            email,
            observacao,
          ),
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    await _recarregarTodosClientes();
  }

  Future<void> _editarCliente(ClienteCadastro cliente) async {
    final resultado = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'EditarCliente'),
        builder: (_) => InserirCliente(
          idCliente: cliente.id,
          dadosIniciais: cliente.dadosFormulario,
          aoEditarCliente: (nome, celular, email, observacao) =>
              _repositorio.editarCliente(
            cliente.id,
            nome,
            celular,
            email,
            observacao,
          ),
        ),
      ),
    );
    if (!mounted || resultado == null) return;
    await _recarregarTodosClientes();
  }

  Future<void> _abrirEndereco(
    ClienteCadastro cliente, [
    EnderecoClienteCadastro? endereco,
  ]) async {
    final alterou = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        settings: RouteSettings(
          name: endereco == null ? 'CadastrarEndereco' : 'EditarEndereco',
        ),
        builder: (_) => EnderecoDelivery(
          servico: _repositorio.servicoEndereco,
          cliente: cliente.id,
          endereco: endereco?.dadosOriginais,
        ),
      ),
    );
    if (!mounted || alterou != true) return;
    await _carregarEnderecos(cliente.id);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Clientes'),
        backgroundColor: cs.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Atualizar clientes',
            onPressed: _carregando ? null : _carregarClientes,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: MediaQuery.sizeOf(context).width < 620
          ? FloatingActionButton.extended(
              key: const ValueKey('novo-cliente-flutuante'),
              onPressed: _abrirCadastro,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Novo cliente'),
            )
          : null,
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CabecalhoClientes(
                  controller: _pesquisaController,
                  carregando: _carregando,
                  total: _clientes.length,
                  onChanged: _aoPesquisar,
                  onLimpar: _limparPesquisa,
                  onNovo: _abrirCadastro,
                ),
                Expanded(child: _conteudo()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _conteudo() {
    if (_carregando && _clientes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_erro != null && _clientes.isEmpty) {
      return _EstadoClientes(
        icone: Icons.cloud_off_outlined,
        titulo: 'Não foi possível carregar',
        descricao: _erro!,
        textoAcao: 'Tentar novamente',
        onAcao: _carregarClientes,
      );
    }
    if (_clientes.isEmpty) {
      return _EstadoClientes(
        icone: Icons.person_search_outlined,
        titulo: 'Nenhum cliente encontrado',
        descricao: _pesquisaController.text.trim().isEmpty
            ? 'Cadastre o primeiro cliente para começar.'
            : 'Confira o nome ou o celular pesquisado.',
        textoAcao: 'Cadastrar cliente',
        onAcao: _abrirCadastro,
      );
    }
    return RefreshIndicator(
      onRefresh: _carregarClientes,
      child: ListView.separated(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 104),
        itemCount: _clientes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, indice) {
          final cliente = _clientes[indice];
          return _CartaoCliente(
            cliente: cliente,
            enderecos: _enderecos[cliente.id] ?? const [],
            carregandoEnderecos: _carregandoEnderecos.contains(cliente.id),
            erroEnderecos: _errosEnderecos[cliente.id],
            onEditarCliente: () => _editarCliente(cliente),
            onNovoEndereco: () => _abrirEndereco(cliente),
            onEditarEndereco: (endereco) => _abrirEndereco(cliente, endereco),
            onTentarEnderecos: () => _carregarEnderecos(cliente.id),
          );
        },
      ),
    );
  }
}

class _CabecalhoClientes extends StatelessWidget {
  const _CabecalhoClientes({
    required this.controller,
    required this.carregando,
    required this.total,
    required this.onChanged,
    required this.onLimpar,
    required this.onNovo,
  });

  final TextEditingController controller;
  final bool carregando;
  final int total;
  final ValueChanged<String> onChanged;
  final VoidCallback onLimpar;
  final VoidCallback onNovo;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(builder: (context, limites) {
            final campo = TextField(
              key: const ValueKey('pesquisa-clientes'),
              controller: controller,
              onChanged: onChanged,
              onSubmitted: (_) => onChanged(controller.text),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Nome, celular ou código',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar pesquisa',
                        onPressed: onLimpar,
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: cs.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: cs.outlineVariant),
                ),
              ),
            );
            if (limites.maxWidth < 620) return campo;
            return Row(children: [
              Expanded(child: campo),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: FilledButton.icon(
                  key: const ValueKey('novo-cliente-cabecalho'),
                  onPressed: onNovo,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Novo cliente'),
                ),
              ),
            ]);
          }),
          const SizedBox(height: 9),
          Row(children: [
            Icon(Icons.people_alt_outlined,
                size: 17, color: cs.onSurfaceVariant),
            const SizedBox(width: 7),
            Text(
              '$total ${total == 1 ? 'cliente encontrado' : 'clientes encontrados'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (carregando) ...[
              const Spacer(),
              const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ]),
        ],
      ),
    );
  }
}

class _CartaoCliente extends StatelessWidget {
  const _CartaoCliente({
    required this.cliente,
    required this.enderecos,
    required this.carregandoEnderecos,
    required this.erroEnderecos,
    required this.onEditarCliente,
    required this.onNovoEndereco,
    required this.onEditarEndereco,
    required this.onTentarEnderecos,
  });

  final ClienteCadastro cliente;
  final List<EnderecoClienteCadastro> enderecos;
  final bool carregandoEnderecos;
  final String? erroEnderecos;
  final VoidCallback onEditarCliente;
  final VoidCallback onNovoEndereco;
  final ValueChanged<EnderecoClienteCadastro> onEditarEndereco;
  final VoidCallback onTentarEnderecos;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      key: ValueKey('cliente-${cliente.id}'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: cs.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundColor: cs.primaryContainer,
                  foregroundColor: cs.onPrimaryContainer,
                  child: Text(
                    cliente.inicial,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cliente.nome.isEmpty
                            ? 'Cliente sem nome'
                            : cliente.nome,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.phone_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            cliente.celular.isEmpty
                                ? 'Sem celular cadastrado'
                                : cliente.celular,
                            style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  key: ValueKey('editar-cliente-${cliente.id}'),
                  tooltip: 'Editar nome e celular',
                  onPressed: onEditarCliente,
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 11),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 19, color: cs.primary),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Endereços (${enderecos.length})',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                key: ValueKey('novo-endereco-${cliente.id}'),
                onPressed: onNovoEndereco,
                icon: const Icon(Icons.add_location_alt_outlined, size: 19),
                label: const Text('Adicionar'),
              ),
            ]),
            const SizedBox(height: 6),
            if (carregandoEnderecos && enderecos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (erroEnderecos != null)
              _ErroEnderecos(
                mensagem: erroEnderecos!,
                onTentar: onTentarEnderecos,
              )
            else if (enderecos.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Nenhum endereço cadastrado.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              )
            else
              LayoutBuilder(builder: (context, limites) {
                final duasColunas = limites.maxWidth >= 680;
                final largura = duasColunas
                    ? (limites.maxWidth - 10) / 2
                    : limites.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final endereco in enderecos)
                      SizedBox(
                        width: largura,
                        child: _CartaoEndereco(
                          clienteId: cliente.id,
                          endereco: endereco,
                          onEditar: () => onEditarEndereco(endereco),
                        ),
                      ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _CartaoEndereco extends StatelessWidget {
  const _CartaoEndereco({
    required this.clienteId,
    required this.endereco,
    required this.onEditar,
  });

  final String clienteId;
  final EnderecoClienteCadastro endereco;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('endereco-$clienteId-${endereco.id}'),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: endereco.padrao
            ? cs.primaryContainer.withValues(alpha: 0.45)
            : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: endereco.padrao ? cs.primary : cs.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              endereco.sitio
                  ? Icons.agriculture_outlined
                  : Icons.home_work_outlined,
              size: 20,
              color: endereco.padrao ? cs.primary : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      endereco.linhaPrincipal,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (endereco.padrao)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Padrão',
                        style: TextStyle(
                          color: cs.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ]),
                if (endereco.linhaSecundaria.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    endereco.linhaSecundaria,
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            key: ValueKey('editar-endereco-$clienteId-${endereco.id}'),
            tooltip: 'Editar endereço',
            onPressed: onEditar,
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
        ],
      ),
    );
  }
}

class _ErroEnderecos extends StatelessWidget {
  const _ErroEnderecos({required this.mensagem, required this.onTentar});

  final String mensagem;
  final VoidCallback onTentar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: cs.onErrorContainer),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensagem,
            style: TextStyle(color: cs.onErrorContainer, fontSize: 12.5),
          ),
        ),
        TextButton(onPressed: onTentar, child: const Text('Tentar')),
      ]),
    );
  }
}

class _EstadoClientes extends StatelessWidget {
  const _EstadoClientes({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.textoAcao,
    required this.onAcao,
  });

  final IconData icone;
  final String titulo;
  final String descricao;
  final String textoAcao;
  final VoidCallback onAcao;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 54, color: cs.onSurfaceVariant),
            const SizedBox(height: 14),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              descricao,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAcao,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(textoAcao),
            ),
          ],
        ),
      ),
    );
  }
}
