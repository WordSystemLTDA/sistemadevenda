// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

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
  State<PaginaComandaDesocupada> createState() => _PaginaComandaDesocupadaState();
}

class _PaginaComandaDesocupadaState extends State<PaginaComandaDesocupada> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  final _mesaDestinoSearchController = TextEditingController();
  final _clienteSearchController = TextEditingController();
  final _obsconstroller = TextEditingController();

  bool carregando = true;
  bool salvando = false;

  Modeloworddadoscardapio? dados;

  String id = '0';
  String idMesa = '0';
  String idCliente = '0';

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
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
    }
  }

  @override
  void dispose() {
    _mesaDestinoSearchController.dispose();
    _clienteSearchController.dispose();
    _obsconstroller.dispose();
    super.dispose();
  }

  void listarDados() async {
    await servicoConfigBigchef.listar().then((value) {
      setState(() {
        configBigchef = value;
      });
    });
  }

  Future<void> listarPorCodigoQrcode() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido!, TipoCardapio.comanda, 'Não').then((value) {
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente!;
        _mesaDestinoSearchController.text = value.nomeMesa!;
        _obsconstroller.text = value.observacaoDoPedido!;
        idCliente = value.idCliente!;
        idMesa = value.idMesa!;
        carregando = false;
      });
    });
  }

  Future<void> listarComandasPedidos() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido!, TipoCardapio.comanda, 'Não').then((value) {
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente!;
        _mesaDestinoSearchController.text = value.nomeMesa!;
        _obsconstroller.text = value.observacaoDoPedido!;
        idCliente = value.idCliente!;
        idMesa = value.idMesa!;
        carregando = false;
      });
    });
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
    if (salvando) return;

    setState(() {
      salvando = true;
    });

    final Server server = Modular.get<Server>();
    final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();

    if (widget.tipo == TipoCardapio.mesa) {
      final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
      if (widget.idComandaPedido != null) {
        await provedorMesas.editarMesaOcupada(widget.idComandaPedido!, id, idCliente, _obsconstroller.text).then((sucesso) {
          if (context.mounted) {
            if (sucesso) {
              server.write(jsonEncode({
                'tipo': 'Mesa',
                'nomeConexao': usuarioProvedor.usuario!.nome,
              }));

              Navigator.pop(context);
              Navigator.pop(context);
            }

            if (!sucesso) {
              _mostrarErro('Ocorreu um erro');
            }
          }
        });
      } else {
        await provedorMesas.inserirMesaOcupada(id, idCliente, _obsconstroller.text).then((resposta) async {
          if (context.mounted) {
            provedorComanda.listarMesas('');

            if (resposta.sucesso) {
              server.write(jsonEncode({
                'tipo': 'Mesa',
                'nomeConexao': usuarioProvedor.usuario!.nome,
              }));
              Navigator.pop(context);
              if (configBigchef != null && configBigchef!.abrircomandadireto == 'Sim') {
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return PaginaCardapio(
                        tipo: TipoCardapio.mesa,
                        idComanda: '0',
                        idMesa: id,
                        idCliente: idCliente,
                        id: resposta.idcomandapedido,
                      );
                    },
                  ));
                }
              } else {
                Navigator.pop(context);
              }
            }

            if (!resposta.sucesso) {
              if (context.mounted) {
                _mostrarErro('Ocorreu um erro');
              }
            }
          }
        });
      }
    } else {
      if (widget.idComandaPedido != null) {
        await _state.editarComandaOcupada(widget.idComandaPedido!, idMesa, idCliente, _obsconstroller.text).then((sucesso) {
          if (context.mounted) {
            if (sucesso) {
              server.write(jsonEncode({
                'tipo': 'Comanda',
                'nomeConexao': usuarioProvedor.usuario!.nome,
              }));
              Navigator.pop(context);
              Navigator.pop(context);
            }

            if (!sucesso) {
              _mostrarErro('Ocorreu um erro');
            }
          }
        });
      } else {
        await _state.inserirComandaOcupada(id, idMesa, idCliente, _obsconstroller.text).then((resposta) async {
          if (context.mounted) {
            provedorComanda.listarComandas('');

            if (resposta.sucesso) {
              server.write(jsonEncode({
                'tipo': 'Comanda',
                'nomeConexao': usuarioProvedor.usuario!.nome,
              }));

              Navigator.pop(context);
              if (configBigchef != null && configBigchef!.abrircomandadireto == 'Sim') {
                if (context.mounted) {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return PaginaCardapio(
                        tipo: TipoCardapio.comanda,
                        idComanda: id,
                        idMesa: '0',
                        idCliente: idCliente,
                        id: resposta.idcomandapedido,
                      );
                    },
                  ));
                }
              } else {
                Navigator.pop(context);
              }
            }

            if (!resposta.sucesso) {
              if (context.mounted) {
                _mostrarErro('Ocorreu um erro');
              }
            }
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        salvando = false;
      });
    }
  }

  IconData get _iconeTipo => widget.tipo == TipoCardapio.mesa ? Icons.table_bar_outlined : Icons.fact_check_outlined;

  String get _labelAcao {
    final editando = widget.idComandaPedido != null;
    if (widget.tipo == TipoCardapio.mesa) {
      return editando ? 'Salvar alterações' : 'Abrir mesa';
    }
    return editando ? 'Salvar alterações' : 'Abrir comanda';
  }

  String get _labelHero {
    return widget.idComandaPedido != null ? 'EDITAR ${widget.tipo.nome.toUpperCase()}' : 'NOVA ${widget.tipo.nome.toUpperCase()}';
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
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          elevation: 0,
          title: Text(widget.tipo.nome, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: carregando
            ? null
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: salvando ? null : _salvar,
                    icon: salvando
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                          )
                        : const Icon(Icons.check_rounded, size: 20),
                    label: Text(
                      salvando ? 'Salvando...' : _labelAcao,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 4,
                    ),
                  ),
                ),
              ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
                  children: [
                    _HeroCard(icone: _iconeTipo, label: _labelHero, nome: widget.nome),
                    const SizedBox(height: 16),
                    if (mostrarMesaDestino) ...[
                      const _LabelCampo(icone: Icons.table_bar_outlined, texto: 'Mesa de destino', opcional: true),
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
                    const _LabelCampo(icone: Icons.person_outline_rounded, texto: 'Cliente', opcional: true),
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
                    const _LabelCampo(icone: Icons.notes_rounded, texto: 'Observação', opcional: true),
                    const SizedBox(height: 8),
                    _CampoObservacao(controller: _obsconstroller),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final IconData icone;
  final String label;
  final String nome;

  const _HeroCard({required this.icone, required this.label, required this.nome});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
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
            child: Icon(icone, size: 28, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nome,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelCampo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool opcional;

  const _LabelCampo({required this.icone, required this.texto, this.opcional = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icone, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: 0.1),
        ),
        if (opcional) ...[
          const SizedBox(width: 6),
          Text(
            '(opcional)',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
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
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => c.openView(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
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
                        fontWeight: temSelecionado ? FontWeight.w600 : FontWeight.w500,
                        color: temSelecionado ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (temSelecionado)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: onLimpar,
                      icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
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
                child: Text('Nada encontrado', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconeItem, size: 18, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['nome'].toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${e['id']}',
                                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
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
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => c.openView(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    temSelecionado ? Icons.person_rounded : Icons.search_rounded,
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
                        fontWeight: temSelecionado ? FontWeight.w600 : FontWeight.w500,
                        color: temSelecionado ? cs.onSurface : cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (temSelecionado)
                    IconButton(
                      tooltip: 'Limpar',
                      onPressed: onLimpar,
                      icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant),
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
                            MaterialPageRoute(builder: (context) => const InserirCliente()),
                          );
                          if (result is Map && result['idcliente'] != null) {
                            onCadastrar(
                              result['idcliente'].toString(),
                              (result['nomecliente'] ?? '').toString(),
                            );
                          }
                        },
                        icon: Icon(Icons.person_add_alt_1_rounded, size: 18, color: cs.onPrimaryContainer),
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
                child: Text('Nenhum cliente encontrado', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(Icons.person_outline_rounded, size: 18, color: cs.onPrimaryContainer),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e['nome'].toString(),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'ID: ${e['id']}',
                                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
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
  const _CampoObservacao({required this.controller});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        maxLines: 5,
        minLines: 4,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Digite aqui alguma observação...',
          hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
