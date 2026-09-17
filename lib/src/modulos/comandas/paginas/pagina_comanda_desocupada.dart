// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaComandaDesocupada extends StatefulWidget {
  final String id;
  final String? idComandaPedido;
  final String? codigoQrcode;
  final String nome;
  final TipoCardapio tipo;

  const PaginaComandaDesocupada({
    super.key,
    required this.id,
    this.idComandaPedido,
    this.codigoQrcode,
    required this.nome,
    required this.tipo,
  });

  @override
  State<PaginaComandaDesocupada> createState() =>
      _PaginaComandaDesocupadaState();
}

class _PaginaComandaDesocupadaState extends State<PaginaComandaDesocupada> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  final _mesaDestinoSearchController = TextEditingController();
  final _clienteSearchController = TextEditingController();
  final _obsconstroller = TextEditingController();
  final _observacaoFocusNode = FocusNode();

  bool carregando = true;
  bool salvando = false;
  String? erroConsulta;

  Modeloworddadoscardapio? dados;

  String id = '0';
  String idMesa = '0';
  String idCliente = '0';

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ServicoConfigBigchef servicoConfigBigchef =
      Modular.get<ServicoConfigBigchef>();
  ModeloConfigBigchef? configBigchef;

  @override
  void initState() {
    super.initState();
    id = widget.id;

    listarDados();
    if (widget.idComandaPedido != null) {
      listarComandasPedidos();
    } else {
      carregando = false;
      _focarObservacaoDepoisDoFrame();
    }
  }

  @override
  void dispose() {
    _mesaDestinoSearchController.dispose();
    _clienteSearchController.dispose();
    _obsconstroller.dispose();
    _observacaoFocusNode.dispose();
    super.dispose();
  }

  void _focarObservacaoDepoisDoFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || carregando || erroConsulta != null) return;
      _observacaoFocusNode.requestFocus();
    });
  }

  Future<void> listarDados() async {
    try {
      final value = await servicoConfigBigchef.listar();
      if (mounted) setState(() => configBigchef = value);
    } catch (_) {
      // A abertura continua disponivel quando a configuracao nao esta em cache.
    }
  }

  Future<void> listarPorCodigoQrcode() => listarComandasPedidos();

  Future<void> listarComandasPedidos() async {
    setState(() {
      carregando = true;
      erroConsulta = null;
    });
    try {
      final value = await servicoCardapio.listarPorId(
          widget.idComandaPedido!, widget.tipo, 'Não');
      if (!mounted) return;
      if (value.id != widget.idComandaPedido) {
        throw StateError('Atendimento diferente do solicitado.');
      }
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente ?? '';
        _mesaDestinoSearchController.text = value.nomeMesa ?? '';
        _obsconstroller.text = value.observacaoDoPedido ?? '';
        idCliente = value.idCliente ?? '0';
        idMesa = value.idMesa ?? '0';
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => erroConsulta = 'Não foi possível carregar o atendimento.');
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
        _focarObservacaoDepoisDoFrame();
      }
    }
  }

  void _mostrarErro(String mensagem) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _salvar() async {
    if (salvando || erroConsulta != null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => salvando = true);
    final server = Modular.get<Server>();
    final editando = widget.idComandaPedido != null;
    final mesa = widget.tipo == TipoCardapio.mesa;
    String? novoAtendimento;
    try {
      if (mesa) {
        final provedor = Modular.get<ProvedorMesas>();
        if (editando) {
          final sucesso = await provedor.editarMesaOcupada(
              widget.idComandaPedido!, id, idCliente, _obsconstroller.text);
          if (!sucesso) {
            if (mounted) {
              _mostrarErro(provedor.erro ?? 'Não foi possível salvar a mesa.');
            }
            return;
          }
        } else {
          final resposta = await provedor.inserirMesaOcupada(
              id, idCliente, _obsconstroller.text);
          if (!resposta.sucesso) {
            if (mounted) {
              _mostrarErro(provedor.erro ?? 'Não foi possível abrir a mesa.');
            }
            return;
          }
          novoAtendimento = resposta.idcomandapedido;
        }
      } else {
        if (editando) {
          final sucesso = await _state.editarComandaOcupada(
              widget.idComandaPedido!, idMesa, idCliente, _obsconstroller.text);
          if (!sucesso) {
            if (mounted) {
              _mostrarErro(_state.erro ?? 'Não foi possível salvar a comanda.');
            }
            return;
          }
        } else {
          final resposta = await _state.inserirComandaOcupada(
              id, idMesa, idCliente, _obsconstroller.text);
          if (!resposta.sucesso) {
            if (mounted) {
              _mostrarErro(_state.erro ?? 'Não foi possível abrir a comanda.');
            }
            return;
          }
          novoAtendimento = resposta.idcomandapedido;
        }
      }
      server.write(jsonEncode({
        'tipo': mesa ? 'Mesa' : 'Comanda',
        'nomeConexao': usuarioProvedor.usuario?.nome ?? '',
      }));
      if (!mounted) return;
      if (!editando && configBigchef?.abrircomandadireto == 'Sim') {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => PaginaCardapio(
            nomeAtendimento: widget.nome,
            tipo: widget.tipo,
            idComanda: mesa ? '0' : id,
            idMesa: mesa ? id : '0',
            idCliente: idCliente,
            id: novoAtendimento,
          ),
        ));
      } else {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        _mostrarErro(
            'Não foi possível concluir. Verifique as pendências de sincronização.');
      }
    } finally {
      if (mounted) setState(() => salvando = false);
    }
  }

  IconData get _iconeTipo => widget.tipo == TipoCardapio.mesa
      ? Icons.table_bar_outlined
      : Icons.fact_check_outlined;

  String get _labelAcao {
    final editando = widget.idComandaPedido != null;
    if (widget.tipo == TipoCardapio.mesa) {
      return editando ? 'Salvar alterações' : 'Abrir mesa';
    }
    return editando ? 'Salvar alterações' : 'Abrir comanda';
  }

  String get _labelHero {
    return widget.idComandaPedido != null
        ? 'EDITAR ${widget.tipo.nome.toUpperCase()}'
        : 'NOVA ${widget.tipo.nome.toUpperCase()}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mostrarMesaDestino = widget.tipo != TipoCardapio.mesa;
    final clienteSelecionado = _clienteSearchController.text;
    final mesaSelecionada = _mesaDestinoSearchController.text;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: VisualAtendimento.superficie(context),
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          elevation: 0,
          title: Text(widget.tipo.nome,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        bottomNavigationBar: carregando || erroConsulta != null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      16, 10, 16, 12 + MediaQuery.viewInsetsOf(context).bottom),
                  child: FilledButton.icon(
                    onPressed: salvando ? null : _salvar,
                    icon: salvando
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_rounded),
                    label: Text(salvando ? 'Salvando...' : _labelAcao),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      textStyle: Theme.of(context)
                          .textTheme
                          .labelLarge
                          ?.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : erroConsulta != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(erroConsulta!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                              onPressed: listarComandasPedidos,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Tentar novamente')),
                        ])))
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                      children: [
                        _IdentificacaoAtendimento(
                            icone: _iconeTipo,
                            label: _labelHero,
                            nome: widget.nome),
                        const SizedBox(height: 16),
                        if (mostrarMesaDestino) ...[
                          const _LabelCampo(
                              icone: Icons.table_bar_outlined,
                              texto: 'Mesa de destino',
                              opcional: true),
                          const SizedBox(height: 8),
                          _SeletorGenerico(
                            valor: mesaSelecionada,
                            hint: 'Selecionar mesa',
                            iconePreenchido: Icons.table_restaurant_rounded,
                            listar: _state.listarMesas,
                            itensExtras: const [
                              {'nome': 'Sem Mesa', 'id': '0'}
                            ],
                            iconeItem: Icons.table_bar_outlined,
                            onSelecionar: (id, nome) {
                              setState(() {
                                idMesa = id;
                                _mesaDestinoSearchController.text = nome;
                              });
                            },
                            onLimpar: () {
                              setState(() {
                                idMesa = '0';
                                _mesaDestinoSearchController.clear();
                              });
                            },
                          ),
                          const SizedBox(height: 18),
                        ],
                        const _LabelCampo(
                            icone: Icons.person_outline_rounded,
                            texto: 'Cliente',
                            opcional: true),
                        const SizedBox(height: 8),
                        _SeletorCliente(
                          valor: clienteSelecionado,
                          listar: _state.listarClientes,
                          onSelecionar: (id, nome) {
                            setState(() {
                              idCliente = id;
                              _clienteSearchController.text = nome;
                            });
                          },
                          onLimpar: () {
                            setState(() {
                              idCliente = '0';
                              _clienteSearchController.clear();
                            });
                          },
                          onCadastrar: (id, nome) {
                            setState(() {
                              idCliente = id;
                              _clienteSearchController.text = nome;
                            });
                          },
                        ),
                        const SizedBox(height: 18),
                        const _LabelCampo(
                            icone: Icons.notes_rounded,
                            texto: 'Nome / observação',
                            opcional: true),
                        const SizedBox(height: 8),
                        _CampoObservacao(
                          controller: _obsconstroller,
                          focusNode: _observacaoFocusNode,
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _IdentificacaoAtendimento extends StatelessWidget {
  final IconData icone;
  final String label;
  final String nome;

  const _IdentificacaoAtendimento(
      {required this.icone, required this.label, required this.nome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icone, size: 32, color: VisualAtendimento.azul(context)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant,
                  letterSpacing: 0)),
          const SizedBox(height: 6),
          Text(nome,
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _LabelCampo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool opcional;

  const _LabelCampo(
      {required this.icone, required this.texto, this.opcional = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        Icon(icone, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              letterSpacing: 0),
        ),
        if (opcional) ...[
          const SizedBox(width: 6),
          Text(
            '(opcional)',
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: cs.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _SeletorGenerico extends StatelessWidget {
  final String valor;
  final String hint;
  final IconData iconePreenchido;
  final IconData iconeItem;
  final Future<List<dynamic>> Function(String) listar;
  final List<Map<String, String>> itensExtras;
  final void Function(String id, String nome) onSelecionar;
  final VoidCallback onLimpar;

  const _SeletorGenerico({
    required this.valor,
    required this.hint,
    required this.iconePreenchido,
    required this.iconeItem,
    required this.listar,
    required this.onSelecionar,
    required this.onLimpar,
    this.itensExtras = const [],
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temSelecionado = valor.isNotEmpty;
    final controller = SearchController();

    return SearchAnchor(
      searchController: controller,
      builder: (BuildContext context, SearchController c) {
        return Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => c.openView(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    temSelecionado ? iconePreenchido : Icons.search_rounded,
                    size: 20,
                    color: temSelecionado ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      temSelecionado ? valor : hint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            temSelecionado ? FontWeight.w600 : FontWeight.w500,
                        color:
                            temSelecionado ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (temSelecionado)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: onLimpar,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController c) async {
        final keyword = c.value.text;
        final res = await listar(keyword);
        final lista = [...itensExtras, ...res];
        if (lista.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Nada encontrado',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              ),
            ),
          ];
        }
        return [
          ...lista.map((e) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    c.closeView('');
                    onSelecionar(e['id'].toString(), e['nome'].toString());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconeItem,
                              size: 18, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['nome'].toString(),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${e['id']}',
                                style: TextStyle(
                                    fontSize: 11.5, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ];
      },
    );
  }
}

class _SeletorCliente extends StatelessWidget {
  final String valor;
  final Future<List<dynamic>> Function(String) listar;
  final void Function(String id, String nome) onSelecionar;
  final void Function(String id, String nome) onCadastrar;
  final VoidCallback onLimpar;

  const _SeletorCliente({
    required this.valor,
    required this.listar,
    required this.onSelecionar,
    required this.onCadastrar,
    required this.onLimpar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final temSelecionado = valor.isNotEmpty;
    final controller = SearchController();

    return SearchAnchor(
      searchController: controller,
      builder: (BuildContext context, SearchController c) {
        return Material(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => c.openView(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    temSelecionado
                        ? Icons.person_rounded
                        : Icons.search_rounded,
                    size: 20,
                    color: temSelecionado ? cs.primary : cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      temSelecionado ? valor : 'Selecionar cliente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            temSelecionado ? FontWeight.w600 : FontWeight.w500,
                        color:
                            temSelecionado ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (temSelecionado)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: onLimpar,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: cs.onSurfaceVariant),
                      visualDensity: VisualDensity.compact,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        tooltip: 'Cadastrar cliente',
                        onPressed: () async {
                          final result = await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const InserirCliente()),
                          );
                          if (result is Map && result['idcliente'] != null) {
                            onCadastrar(
                              result['idcliente'].toString(),
                              (result['nomecliente'] ?? '').toString(),
                            );
                          }
                        },
                        icon: Icon(Icons.person_add_alt_1_rounded,
                            size: 18, color: cs.onPrimaryContainer),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController c) async {
        final keyword = c.value.text;
        final res = await listar(keyword);
        if (res.isEmpty) {
          return [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Nenhum cliente encontrado',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
              ),
            ),
          ];
        }
        return [
          ...res.map((e) => Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    c.closeView('');
                    onSelecionar(e['id'].toString(), e['nome'].toString());
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_outline_rounded,
                              size: 18, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['nome'].toString(),
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${e['id']}',
                                style: TextStyle(
                                    fontSize: 11.5, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ];
      },
    );
  }
}

class _CampoObservacao extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  const _CampoObservacao({required this.controller, required this.focusNode});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        key: const Key('observacao_abertura_atendimento'),
        controller: controller,
        focusNode: focusNode,
        maxLines: 5,
        minLines: 3,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Nome do cliente ou observação para o preparo',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
