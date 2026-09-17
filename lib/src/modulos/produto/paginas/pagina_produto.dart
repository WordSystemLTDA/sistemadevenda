import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/sugestoes_observacao.dart';
import 'package:app/src/modulos/cardapio/uteis/montagem_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_kit.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/paginas/widgets/etapa_montagem_cardapio.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum _FiltroComplementos { todos, adicionais, retirada }

class PaginaProduto extends StatefulWidget {
  final Modelowordprodutos produto;
  final double? valorVenda;
  final bool editar;
  final bool montagemPizza;
  final int? indexProduto;
  final Function(Modelowordprodutos produto)? inserirEmItensRecorrentes;

  const PaginaProduto({
    super.key,
    required this.produto,
    this.valorVenda,
    this.editar = false,
    this.montagemPizza = false,
    this.indexProduto,
    this.inserirEmItensRecorrentes,
  });

  @override
  State<PaginaProduto> createState() => _PaginaProdutoState();
}

class _PaginaProdutoState extends State<PaginaProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  Modelowordprodutos? itemProduto;
  bool carregando = false;
  String? erroConsulta;
  TextEditingController obsController = TextEditingController();
  final TextEditingController _pesquisaOpcoesController =
      TextEditingController();
  final TextEditingController _pesquisaMontagemController =
      TextEditingController();
  final _focoObservacao = FocusNode();
  _FiltroComplementos _filtroComplementos = _FiltroComplementos.todos;
  String _baseHostImagens = 'https://bigchef.com.br';
  bool _montagemConfirmada = false;
  bool _montagemJaConfirmada = false;
  ModeloDadosOpcoesPacotes? _itemTrocaCardapio;
  ModeloDadosOpcoesPacotes? _destinoTrocaCardapio;
  String? _tipoDestinoTrocaCardapio;
  int _quantidadeTrocaCardapio = 1;

  @override
  void initState() {
    super.initState();
    if (widget.editar) obsController.text = widget.produto.observacao ?? '';
    _pesquisaOpcoesController.addListener(_atualizarPesquisaOpcoes);
    _carregarBaseHostImagens();

    if (widget.editar == false) {
      itemProduto = widget.produto;
      _prepararProdutoParaExibicao(widget.produto);
      listar(forcar: true);
    } else {
      itemProduto = widget.produto;
      _montagemConfirmada = true;
      _montagemJaConfirmada = true;
      _provedorProduto.opcoesPacotesListaFinal =
          widget.produto.opcoesPacotesListaFinal ?? [];
      _provedorProduto.valorVenda = double.parse(widget.produto.valorVenda);
      _provedorProduto.valorVendaOriginal =
          double.parse(widget.produto.valorVenda);
      _provedorProduto.calcularValorVenda(false, '0');
    }
  }

  void _prepararProdutoParaExibicao(Modelowordprodutos produto) {
    itemProduto = produto;
    _provedorProduto.quantidade = 1;
    final valor = widget.valorVenda ?? double.tryParse(produto.valorVenda) ?? 0;
    final bordasSelecionadas = widget.montagemPizza
        ? _grupoBordasSelecionadas(_provedorProduto.opcoesPacotesListaFinal) ??
            _grupoBordasSelecionadas(produto.opcoesPacotesListaFinal ?? [])
        : null;
    final opcoesIniciais = _opcoesIniciaisProduto(produto);
    _preservarBordasSelecionadas(opcoesIniciais, bordasSelecionadas);
    _provedorProduto.valorVenda = valor;
    _provedorProduto.valorVendaOriginal = _provedorProduto.valorVenda;
    _provedorProduto.definirOpcoesPacotesListaFinal(
      opcoesIniciais,
      notificar: false,
    );
    _provedorProduto.calcularValorVenda(false, '0', notificar: false);
  }

  List<ModeloOpcoesPacotes> _opcoesIniciaisProduto(
    Modelowordprodutos produto,
  ) {
    return [
      for (final opcao in produto.opcoesPacotes ?? <ModeloOpcoesPacotes>[])
        ModeloOpcoesPacotes.fromMap(opcao.toMap())
    ].map((e) {
      if (_grupoMontagemCardapio(e)) {
        final salvos = widget.produto.opcoesPacotesListaFinal
            ?.where(_grupoMontagemCardapio)
            .firstOrNull
            ?.dados;
        e.dados = MontagemCardapio.iniciar(e.dados ?? [], salvos: salvos);
        return e;
      }

      if (e.id == 2) {
        e.produtos = e.produtos?.map((produto) {
          produto.opcoesPacotes = produto.opcoesPacotes?.map((opcao) {
            if (opcao.id == 5) return opcao;
            if (opcao.id == 1) {
              opcao.dados = (opcao.dados ?? [])
                  .where((element) => element.estaSelecionado == true)
                  .toList();
              return opcao;
            }
            opcao.dados = [];
            return opcao;
          }).toList();
          return produto;
        }).toList();

        return e;
      }

      if (e.id == 5) return e;

      if (e.id == 1) {
        e.dados = (e.dados ?? [])
            .where((element) => element.estaSelecionado == true)
            .toList();
        return e;
      }

      e.dados = [];
      return e;
    }).toList();
  }

  ModeloOpcoesPacotes? _grupoBordasSelecionadas(
    List<ModeloOpcoesPacotes> opcoes,
  ) {
    final bordas = opcoes.where((opcao) => opcao.id == 6).firstOrNull;
    if (bordas == null || (bordas.dados?.isNotEmpty ?? false) == false) {
      return null;
    }
    return ModeloOpcoesPacotes.fromMap(bordas.toMap());
  }

  void _preservarBordasSelecionadas(
    List<ModeloOpcoesPacotes> opcoes,
    ModeloOpcoesPacotes? bordasSelecionadas,
  ) {
    if (bordasSelecionadas == null) return;

    final index = opcoes.indexWhere((opcao) => opcao.id == 6);
    if (index < 0) {
      opcoes.add(bordasSelecionadas);
      return;
    }

    opcoes[index] = bordasSelecionadas;
  }

  @override
  void dispose() {
    _pesquisaOpcoesController.removeListener(_atualizarPesquisaOpcoes);
    _pesquisaOpcoesController.dispose();
    _pesquisaMontagemController.dispose();
    obsController.dispose();
    _focoObservacao.dispose();
    super.dispose();
  }

  void _atualizarPesquisaOpcoes() {
    if (mounted) setState(() {});
  }

  Future<void> _carregarBaseHostImagens() async {
    final baseHost = await UrlImagem.obterBaseHostImagens();
    if (!mounted) {
      return;
    }
    setState(() {
      _baseHostImagens = baseHost;
    });
  }

  Future<void> listar({bool forcar = false}) async {
    if (carregando && !forcar) return;
    setState(() {
      carregando = true;
      erroConsulta = null;
    });

    var inicioServico = Modular.get<ServicoProduto>();
    final idTamanhoPizza =
        widget.montagemPizza ? provedorCardapio.tamanhosPizza?.id ?? '0' : '0';
    await inicioServico
        .listarPorId(widget.produto.id, idTamanhoPizza)
        .then((value) {
      if (!mounted) return;
      itemProduto = value;
      if (value != null) {
        value.idCategoriaCardapio ??= widget.produto.idCategoriaCardapio;
        if (_idCardapioValido(value.idCategoriaCardapio) &&
            !(value.opcoesPacotes?.any(_grupoMontagemCardapio) ?? false)) {
          itemProduto = null;
          throw StateError('Os ingredientes do cardápio não foram carregados.');
        }
        if (widget.valorVenda == null) {
          final bordasSelecionadas = widget.montagemPizza
              ? _grupoBordasSelecionadas(
                      _provedorProduto.opcoesPacotesListaFinal) ??
                  _grupoBordasSelecionadas(
                      widget.produto.opcoesPacotesListaFinal ?? [])
              : null;
          final opcoesIniciais = _opcoesIniciaisProduto(value);
          _preservarBordasSelecionadas(opcoesIniciais, bordasSelecionadas);
          _provedorProduto.opcoesPacotesListaFinal = opcoesIniciais;

          _provedorProduto.valorVenda = double.parse(value.valorVenda);
          _provedorProduto.valorVendaOriginal = double.parse(value.valorVenda);
          _provedorProduto.calcularValorVenda(false, '0');
        }
      }
    }).catchError((Object erro) {
      if (mounted) {
        setState(() {
          itemProduto = null;
          erroConsulta = 'Não foi possível carregar o produto.';
        });
      }
    }).whenComplete(() {
      if (mounted) setState(() => carregando = false);
    });
  }

  void inserirNoCarrinho() async {
    if (carregando || itemProduto == null) return;

    if (widget.montagemPizza &&
        (provedorCardapio.tamanhosPizza == null ||
            provedorCardapio.saboresPizzaSelecionados.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Selecione o tamanho e os sabores da pizza antes de continuar.'),
      ));
      return;
    }

    final idComanda = provedorCardapio.idComanda;
    final idMesa = provedorCardapio.idMesa;

    var comanda = idComanda.isEmpty ? 0 : idComanda;
    var mesa = idMesa.isEmpty ? 0 : idMesa;
    var valor = itemProduto!.valorVenda;
    var idProduto = itemProduto!.id;
    var observacaoMesa = '';
    var observacao = normalizarObservacaoProduto(obsController.text);

    if ((itemProduto?.opcoesPacotes?.where((element) => element.id == 4) ?? [])
            .isNotEmpty &&
        _provedorProduto.retornarDadosPorID([4], false, '0').isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um tamanho antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    if ((itemProduto?.opcoesPacotes?.where((element) => element.id == 11) ?? [])
            .isNotEmpty &&
        _provedorProduto.retornarDadosPorID([11], false, '0').isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um sabor antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() => carregando = !carregando);

    if (widget.montagemPizza && provedorCardapio.tamanhosPizza != null) {
      _provedorProduto.opcoesPacotesListaFinal
          .removeWhere((opcao) => opcao.id == 9 || opcao.id == 10);
      _provedorProduto.opcoesPacotesListaFinal.insert(
        0,
        ModeloOpcoesPacotes(
          id: 9,
          titulo: 'Tamanho Pizza',
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: provedorCardapio.tamanhosPizza!.id,
              nome: provedorCardapio.tamanhosPizza!.nomedotamanho,
              valor: provedorCardapio.calcularPrecoPizza().toStringAsFixed(2),
            )
          ],
        ),
      );

      _provedorProduto.opcoesPacotesListaFinal.insert(
        1,
        ModeloOpcoesPacotes(
            id: 10,
            titulo:
                'Sabores Pizza (${provedorCardapio.saboresPizzaSelecionados.length})',
            obrigatorio: false,
            dados: provedorCardapio.saboresParaCarrinho()),
      );
    }

    itemProduto!.quantidade = _provedorProduto.quantidade.toDouble();
    if (widget.montagemPizza) {
      itemProduto!.limiteSaboresBorda =
          provedorCardapio.limiteSaborBordaSelecionado;
    }
    itemProduto!.valorVenda = _provedorProduto.valorVenda.toStringAsFixed(2);
    itemProduto!.observacao = observacao;

    _provedorProduto.opcoesPacotesListaFinal
        .removeWhere(grupoObservacaoProduto);
    if (observacao.isNotEmpty) {
      _provedorProduto.opcoesPacotesListaFinal.insert(
        _provedorProduto.opcoesPacotesListaFinal.length,
        montarGrupoObservacaoProduto(observacao),
      );
    }

    itemProduto!.opcoesPacotesListaFinal =
        _provedorProduto.opcoesParaCarrinho();

    if (widget.inserirEmItensRecorrentes != null) {
      widget.inserirEmItensRecorrentes!(itemProduto!);
      Navigator.pop(context);
      return;
    }

    bool sucesso = false;

    if (widget.editar) {
      sucesso =
          await carrinhoProvedor.editar(itemProduto!, widget.indexProduto!);
    } else {
      sucesso = await carrinhoProvedor.inserir(
        itemProduto!,
        provedorCardapio.tipo.nome,
        mesa,
        comanda,
        valor,
        observacaoMesa,
        idProduto,
        itemProduto!.nome,
        itemProduto!.quantidade,
        observacao,
      );
    }

    if (sucesso) {
      if (widget.montagemPizza) {
        provedorCardapio.limiteSaborBordaSelecionado = -1;
        provedorCardapio.tamanhosPizza = null;
        provedorCardapio.saboresPizzaSelecionados = [];
      }
      _provedorProduto.resetarTudo();
      if (mounted) Navigator.pop(context);
      if (widget.valorVenda != null) {
        if (mounted) Navigator.pop(context);
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Ocorreu um erro'),
        showCloseIcon: true,
      ));
    }

    setState(() => carregando = !carregando);
  }

  bool _idCardapioValido(String? id) {
    final texto = id?.trim() ?? '';
    return texto.isNotEmpty && texto != '0' && texto.toLowerCase() != 'null';
  }

  bool _grupoMontagemCardapio(ModeloOpcoesPacotes opcoesPacote) {
    if (grupoObservacaoProduto(opcoesPacote)) return false;
    if (opcoesPacote.tipo == 8) return true;
    return (opcoesPacote.dados ?? const <ModeloDadosOpcoesPacotes>[]).any(
      (dado) =>
          dado.montagemCardapio != null ||
          _idCardapioValido(dado.idCategoriaCardapio),
    );
  }

  ModeloOpcoesPacotes? get _grupoMontagemSelecionado =>
      _provedorProduto.opcoesPacotesListaFinal
          .where(_grupoMontagemCardapio)
          .firstOrNull;

  bool get _produtoTemMontagemCardapio {
    final grupo = _grupoMontagemSelecionado;
    if (grupo == null) return false;
    return _idCardapioValido(itemProduto?.idCategoriaCardapio) ||
        grupo.tipo == 8 ||
        (grupo.dados ?? const <ModeloDadosOpcoesPacotes>[]).any((dado) =>
            dado.montagemCardapio != null ||
            _idCardapioValido(dado.idCategoriaCardapio));
  }

  List<ModeloDadosOpcoesPacotes> get _ingredientesMontagemCardapio =>
      _grupoMontagemSelecionado?.dados ?? const <ModeloDadosOpcoesPacotes>[];

  List<ModeloDadosOpcoesPacotes> _adicionaisDisponiveisTrocaCardapio() {
    final opcoes = itemProduto?.opcoesPacotes ?? const <ModeloOpcoesPacotes>[];
    return opcoes
        .where((grupo) => grupo.id == 7 || grupo.tipo == 3)
        .expand((grupo) => grupo.dados ?? const <ModeloDadosOpcoesPacotes>[])
        .map((dado) => ModeloDadosOpcoesPacotes.fromMap(dado.toMap()))
        .toList();
  }

  void _alterarIngredienteCardapio(
    ModeloDadosOpcoesPacotes item,
    AcaoIngredienteCardapio acao,
  ) {
    final grupo = _grupoMontagemSelecionado;
    final dados = grupo?.dados;
    if (dados == null) return;
    final index = dados.indexWhere((dado) => dado.id == item.id);
    if (index < 0) return;

    final atual = dados[index];
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    final montagem = montagemAtual.copyWith(
      acao: acao,
      limparDestino: acao != AcaoIngredienteCardapio.trocar,
      separado: acao == AcaoIngredienteCardapio.sem ||
              acao == AcaoIngredienteCardapio.normal
          ? false
          : montagemAtual.separado,
    );

    setState(() {
      dados[index] = MontagemCardapio.aplicar(atual, montagem);
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
    });
    _provedorProduto.calcularValorVenda(false, '0');
  }

  void _separarIngredienteCardapio(
    ModeloDadosOpcoesPacotes item,
    bool separado,
  ) {
    final grupo = _grupoMontagemSelecionado;
    final dados = grupo?.dados;
    if (dados == null) return;
    final index = dados.indexWhere((dado) => dado.id == item.id);
    if (index < 0) return;

    final atual = dados[index];
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    if (montagemAtual.acao == AcaoIngredienteCardapio.sem) return;

    setState(() {
      dados[index] = MontagemCardapio.aplicar(
        atual,
        montagemAtual.copyWith(separado: separado),
      );
    });
    _provedorProduto.calcularValorVenda(false, '0');
  }

  void _iniciarTrocaCardapio(ModeloDadosOpcoesPacotes item) {
    setState(() {
      _itemTrocaCardapio = item;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = item.montagemCardapio?.quantidadeTroca ?? 1;
      _pesquisaMontagemController.clear();
    });
  }

  void _selecionarDestinoTrocaCardapio(
    ModeloDadosOpcoesPacotes item,
    String tipo,
  ) {
    setState(() {
      _destinoTrocaCardapio = item;
      _tipoDestinoTrocaCardapio = tipo;
    });
  }

  void _confirmarTrocaCardapio() {
    final origem = _itemTrocaCardapio;
    final destino = _destinoTrocaCardapio;
    final tipo = _tipoDestinoTrocaCardapio;
    final grupo = _grupoMontagemSelecionado;
    final dados = grupo?.dados;
    if (origem == null || destino == null || tipo == null || dados == null) {
      return;
    }

    final erro = MontagemCardapio.validarTroca(
      dados,
      origem.id,
      destino.id,
      tipo,
    );
    if (erro != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(erro)));
      return;
    }

    final index = dados.indexWhere((dado) => dado.id == origem.id);
    if (index < 0) return;
    final atual = dados[index];
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    final nomeDestino = destino.montagemCardapio?.nomeOriginal ?? destino.nome;

    setState(() {
      dados[index] = MontagemCardapio.aplicar(
        atual,
        montagemAtual.copyWith(
          acao: AcaoIngredienteCardapio.trocar,
          destinoId: destino.id,
          destinoNome: nomeDestino,
          destinoTipo: tipo,
          quantidadeTroca: _quantidadeTrocaCardapio,
        ),
      );
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
      _pesquisaMontagemController.clear();
    });
    _provedorProduto.calcularValorVenda(false, '0');
  }

  void _restaurarMontagemCardapio() {
    final grupo = _grupoMontagemSelecionado;
    if (grupo == null) return;
    setState(() {
      grupo.dados = MontagemCardapio.iniciar(grupo.dados ?? []);
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
      _pesquisaMontagemController.clear();
    });
    _provedorProduto.calcularValorVenda(false, '0');
  }

  void _confirmarMontagemCardapio() {
    setState(() {
      _montagemConfirmada = true;
      _montagemJaConfirmada = true;
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
      _pesquisaMontagemController.clear();
    });
  }

  void _voltarMontagemCardapio() {
    if (_itemTrocaCardapio != null) {
      setState(() {
        _itemTrocaCardapio = null;
        _destinoTrocaCardapio = null;
        _tipoDestinoTrocaCardapio = null;
        _quantidadeTrocaCardapio = 1;
        _pesquisaMontagemController.clear();
      });
      return;
    }
    if (_montagemJaConfirmada) {
      setState(() => _montagemConfirmada = true);
      return;
    }
    Navigator.pop(context);
  }

  int get _quantidadeAdicionaisSelecionados {
    return _provedorProduto.retornarDadosPorID([7], false, '0').fold<int>(0,
        (total, adicional) {
      return total + (adicional.quantidade ?? 1);
    });
  }

  bool _grupoComplemento(ModeloOpcoesPacotes opcoesPacote) =>
      !_grupoMontagemCardapio(opcoesPacote) &&
      (opcoesPacote.id == 7 || opcoesPacote.id == 8);

  bool _mostrarGrupoOpcoes(ModeloOpcoesPacotes opcoesPacote) {
    if (_grupoMontagemCardapio(opcoesPacote)) return false;
    if (opcoesPacote.id == 6) return false;
    if (!_grupoComplemento(opcoesPacote)) return true;
    return switch (_filtroComplementos) {
      _FiltroComplementos.todos => true,
      _FiltroComplementos.adicionais => opcoesPacote.id == 7,
      _FiltroComplementos.retirada => opcoesPacote.id == 8,
    };
  }

  List<ModeloDadosOpcoesPacotes> _dadosFiltrados(
      ModeloOpcoesPacotes opcoesPacote) {
    final dados = opcoesPacote.dados ?? const <ModeloDadosOpcoesPacotes>[];
    if (!_grupoComplemento(opcoesPacote)) return dados;

    final pesquisa = _normalizarPesquisa(_pesquisaOpcoesController.text);
    if (pesquisa.isEmpty) return dados;

    return dados
        .where((item) => _normalizarPesquisa(item.nome).contains(pesquisa))
        .toList();
  }

  String _normalizarPesquisa(String texto) {
    const acentos = {
      'á': 'a',
      'à': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'í': 'i',
      'ì': 'i',
      'î': 'i',
      'ï': 'i',
      'ó': 'o',
      'ò': 'o',
      'ô': 'o',
      'õ': 'o',
      'ö': 'o',
      'ú': 'u',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    final buffer = StringBuffer();
    for (final codigo in texto.toLowerCase().runes) {
      final char = String.fromCharCode(codigo);
      buffer.write(acentos[char] ?? char);
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final alturaTeclado = MediaQuery.viewInsetsOf(context).bottom;

    if (itemProduto == null) {
      if (carregando == false) {
        return Scaffold(
          appBar: AppBar(backgroundColor: cs.inversePrimary),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined,
                    size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text(erroConsulta ?? 'Produto não existe',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium),
                if (erroConsulta != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: listar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente')),
                ],
              ],
            ),
          ),
        );
      }

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([_provedorProduto, _focoObservacao]),
        builder: (context, _) {
          if (_produtoTemMontagemCardapio && !_montagemConfirmada) {
            final itemTroca = _itemTrocaCardapio;
            final confirmarHabilitado = itemTroca == null
                ? _ingredientesMontagemCardapio.isNotEmpty
                : _destinoTrocaCardapio != null;
            final confirmar = itemTroca == null
                ? _confirmarMontagemCardapio
                : _confirmarTrocaCardapio;
            return Scaffold(
              extendBody: false,
              backgroundColor: VisualAtendimento.fundo(context),
              appBar: AppBar(
                backgroundColor: cs.inversePrimary,
                elevation: 0,
                title: const Text('Montagem do produto'),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: BotaoAcaoPedido(
                    rotulo: itemTroca == null ? 'Confirmar' : 'Confirmar troca',
                    total: _provedorProduto.valorVenda.obterReal(),
                    habilitado: confirmarHabilitado,
                    onPressed: confirmar,
                  ),
                ),
              ),
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  child: itemTroca == null
                      ? EtapaMontagemCardapio(
                          nomeProduto: itemProduto!.nome,
                          valor: itemProduto!.valorVenda,
                          ingredientes: _ingredientesMontagemCardapio,
                          pesquisaController: _pesquisaMontagemController,
                          aoAlterar: _alterarIngredienteCardapio,
                          aoSeparar: _separarIngredienteCardapio,
                          aoTrocar: _iniciarTrocaCardapio,
                          aoRestaurar: _restaurarMontagemCardapio,
                          aoVoltar: _voltarMontagemCardapio,
                        )
                      : EtapaTrocaCardapio(
                          item: itemTroca,
                          ingredientes: _ingredientesMontagemCardapio,
                          adicionais: _adicionaisDisponiveisTrocaCardapio(),
                          destinoSelecionado: _destinoTrocaCardapio,
                          tipoSelecionado: _tipoDestinoTrocaCardapio,
                          quantidade: _quantidadeTrocaCardapio,
                          pesquisaController: _pesquisaMontagemController,
                          aoVoltar: _voltarMontagemCardapio,
                          aoSelecionar: _selecionarDestinoTrocaCardapio,
                          aoAlterarQuantidade: (quantidade) => setState(
                              () => _quantidadeTrocaCardapio = quantidade),
                        ),
                ),
              ),
            );
          }

          final opcoesProduto = itemProduto!.opcoesPacotes ?? [];
          final faixaPreco = (_provedorProduto
                  .retornarDadosPorID([4], false, '0').isEmpty &&
              _provedorProduto
                      .retornarDadosPorID([4], false, '0').firstOrNull ==
                  null &&
              opcoesProduto.where((element) => element.id == 4).firstOrNull !=
                  null);
          final precoExibido = faixaPreco
              ? "${double.parse(opcoesProduto.where((element) => element.id == 4).first.dados!.first.valor ?? '0').obterReal()} à ${double.parse(opcoesProduto.where((element) => element.id == 4).first.dados!.last.valor ?? '0').obterReal()}"
              : (_provedorProduto.valorVenda).obterReal();
          final total =
              (_provedorProduto.valorVenda * _provedorProduto.quantidade)
                  .obterReal();
          final quantidadeAdicionaisSelecionados =
              _quantidadeAdicionaisSelecionados;
          final temAdicionais = opcoesProduto.any(
              (opcao) => opcao.id == 7 && (opcao.dados?.isNotEmpty ?? false));
          final temRetirada = opcoesProduto.any((opcao) =>
              !_grupoMontagemCardapio(opcao) &&
              opcao.id == 8 &&
              (opcao.dados?.isNotEmpty ?? false));

          return Scaffold(
            extendBody: alturaTeclado == 0,
            backgroundColor: VisualAtendimento.fundo(context),
            appBar: AppBar(
              backgroundColor: cs.inversePrimary,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fastfood_outlined,
                        size: 18, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${itemProduto!.nome}${itemProduto!.tamanho.isNotEmpty ? ' ${itemProduto!.tamanho}' : ''}",
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + alturaTeclado),
                child: TextFieldTapRegion(
                    child: BotaoAcaoPedido(
                  key: const Key('adicionar_produto_carrinho'),
                  rotulo: quantidadeAdicionaisSelecionados > 0
                      ? 'Adicionar ao ($quantidadeAdicionaisSelecionados)'
                      : 'Adicionar ao',
                  iconeRotulo: Icons.shopping_cart_outlined,
                  rotuloSemantico: 'Adicionar ao carrinho',
                  carregando: carregando,
                  quantidade: _provedorProduto.quantidade,
                  total: total,
                  onPressed: inserirNoCarrinho,
                )),
              ),
            ),
            body: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.only(
                bottom: alturaTeclado > 0
                    ? 16
                    : MediaQuery.paddingOf(context).bottom +
                        MediaQuery.textScalerOf(context).scale(88),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ResumoProduto(
                    foto: itemProduto!.foto,
                    baseHost: _baseHostImagens,
                    descricao: itemProduto!.descricao,
                    quantidade: _provedorProduto.quantidade,
                    precoExibido: precoExibido,
                    total: total,
                    onDiminuir: _provedorProduto.aoDiminuirQuantidade,
                    onAumentar: _provedorProduto.aoAumentarQuantidade,
                  ),
                  if (opcoesProduto.isNotEmpty) ...[
                    if (temAdicionais || temRetirada)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: _FiltroComplementosProduto(
                          controller: _pesquisaOpcoesController,
                          filtro: _filtroComplementos,
                          temAdicionais: temAdicionais,
                          temRetirada: temRetirada,
                          onFiltroAlterado: (filtro) =>
                              setState(() => _filtroComplementos = filtro),
                        ),
                      ),
                    ...opcoesProduto
                        .where(_mostrarGrupoOpcoes)
                        .map((opcoesPacote) {
                      final dados = _dadosFiltrados(opcoesPacote);
                      final count = opcoesPacote.id == 2
                          ? opcoesPacote.produtos!.length
                          : dados.length;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: _SecaoProduto(
                          icon: _iconePorTipo(opcoesPacote.id),
                          titulo: opcoesPacote.titulo,
                          contagem: count,
                          obrigatorio: opcoesPacote.obrigatorio,
                          child: count == 0 &&
                                  _grupoComplemento(opcoesPacote) &&
                                  _pesquisaOpcoesController.text
                                      .trim()
                                      .isNotEmpty
                              ? const _EstadoOpcoesVazio()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: count,
                                  padding: const EdgeInsets.only(bottom: 8),
                                  itemBuilder: (context, index) {
                                    if (opcoesPacote.id == 2) {
                                      return CardKit(
                                          item: opcoesPacote.produtos![index]);
                                    }
                                    return CardOpcoesPacotes(
                                      opcoesPacote: opcoesPacote,
                                      item: dados[index],
                                      kit: false,
                                      idProduto: '0',
                                    );
                                  },
                                ),
                        ),
                      );
                    }),
                  ],
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    child: _SecaoProduto(
                      icon: Icons.edit_note_rounded,
                      titulo: 'Observação do Produto',
                      contagem: null,
                      obrigatorio: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            key: const Key('observacao_adicionais_produto'),
                            controller: obsController,
                            focusNode: _focoObservacao,
                            minLines: 2,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _focoObservacao.unfocus(),
                            onTapUpOutside: (_) => _focoObservacao.unfocus(),
                            scrollPadding:
                                const EdgeInsets.fromLTRB(20, 20, 20, 64),
                            decoration: InputDecoration(
                              suffixIcon: _focoObservacao.hasFocus
                                  ? IconButton(
                                      tooltip: 'Ocultar teclado',
                                      onPressed: _focoObservacao.unfocus,
                                      icon: const Icon(
                                          Icons.keyboard_hide_outlined),
                                    )
                                  : null,
                              alignLabelWithHint: true,
                              hintText: "Ex.: Sem cebola, ponto da carne...",
                              hintStyle: TextStyle(
                                fontWeight: FontWeight.w300,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : cs.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.3),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: cs.outline.withValues(alpha: 0.25),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: cs.primary, width: 1.4),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SugestoesObservacao(controller: obsController),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconePorTipo(int? id) {
    switch (id) {
      case 1:
        return Icons.card_giftcard_rounded; // cortesia
      case 2:
        return Icons.inventory_2_outlined; // kits/combos
      case 4:
        return Icons.straighten_rounded; // tamanho
      case 5:
        return Icons.restaurant_menu_rounded; // acompanhamentos
      case 7:
        return Icons.add_circle_outline_rounded; // adicionais
      case 8:
        return Icons.remove_circle_outline_rounded; // itens para retirar
      case 11:
        return Icons.local_pizza_rounded; // sabor
      default:
        return Icons.tune_rounded;
    }
  }
}

class _FiltroComplementosProduto extends StatelessWidget {
  final TextEditingController controller;
  final _FiltroComplementos filtro;
  final bool temAdicionais;
  final bool temRetirada;
  final ValueChanged<_FiltroComplementos> onFiltroAlterado;

  const _FiltroComplementosProduto({
    required this.controller,
    required this.filtro,
    required this.temAdicionais,
    required this.temRetirada,
    required this.onFiltroAlterado,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(
        key: const ValueKey('pesquisa_opcoes_produto'),
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  key: const ValueKey('limpar_pesquisa_opcoes_produto'),
                  tooltip: 'Limpar pesquisa',
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
          hintText: temRetirada
              ? 'Pesquisar adicional ou item'
              : 'Pesquisar adicional',
          filled: true,
          fillColor: VisualAtendimento.superficie(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.35)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide:
                BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: cs.primary, width: 1.4),
          ),
        ),
      ),
      if (temAdicionais && temRetirada) ...[
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<_FiltroComplementos>(
            showSelectedIcon: false,
            selected: {filtro},
            onSelectionChanged: (selecionado) =>
                onFiltroAlterado(selecionado.single),
            segments: const [
              ButtonSegment(
                value: _FiltroComplementos.todos,
                icon: Icon(Icons.layers_outlined),
                label: Text('Todos'),
              ),
              ButtonSegment(
                value: _FiltroComplementos.adicionais,
                icon: Icon(Icons.add_circle_outline_rounded),
                label: Text(
                  'Adicionais',
                  key: ValueKey('filtro_adicionais_produto'),
                ),
              ),
              ButtonSegment(
                value: _FiltroComplementos.retirada,
                icon: Icon(Icons.remove_circle_outline_rounded),
                label: Text(
                  'Retirada',
                  key: ValueKey('filtro_itens_retirar_produto'),
                ),
              ),
            ],
          ),
        ),
      ],
    ]);
  }
}

class _EstadoOpcoesVazio extends StatelessWidget {
  const _EstadoOpcoesVazio();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(Icons.search_off_rounded, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Nenhum item encontrado',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ]),
    );
  }
}

class _ResumoProduto extends StatelessWidget {
  final String foto;
  final String baseHost;
  final String descricao;
  final int quantidade;
  final String precoExibido;
  final String total;
  final VoidCallback onDiminuir;
  final VoidCallback onAumentar;

  const _ResumoProduto({
    required this.foto,
    required this.baseHost,
    required this.descricao,
    required this.quantidade,
    required this.precoExibido,
    required this.total,
    required this.onDiminuir,
    required this.onAumentar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ColoredBox(
      color: VisualAtendimento.superficie(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            if (foto.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl:
                      UrlImagem.montarUrlImagem(foto: foto, baseHost: baseHost),
                  width: 64,
                  height: 64,
                  fit: BoxFit.contain,
                  placeholder: (_, url) => const SizedBox.square(dimension: 64),
                  errorWidget: (_, url, error) =>
                      const Icon(Icons.restaurant_outlined, size: 32),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Preço unit.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(precoExibido,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            )),
          ]),
          const SizedBox(height: 16),
          Wrap(
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _StepperQuantidade(
                    quantidade: quantidade,
                    onDiminuir: onDiminuir,
                    onAumentar: onAumentar),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Total',
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  Text(total,
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: VisualAtendimento.verde(context))),
                ]),
              ]),
          if (descricao.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(descricao,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

class _StepperQuantidade extends StatelessWidget {
  final int quantidade;
  final VoidCallback onDiminuir;
  final VoidCallback onAumentar;

  const _StepperQuantidade({
    required this.quantidade,
    required this.onDiminuir,
    required this.onAumentar,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 144,
        height: 48,
        child: Row(children: [
          IconButton(
            tooltip: 'Diminuir quantidade do produto',
            onPressed: quantidade > 1 ? onDiminuir : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
              child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('$quantidade',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600)))),
          IconButton(
            tooltip: 'Aumentar quantidade do produto',
            onPressed: onAumentar,
            icon: Icon(Icons.add_circle_outline,
                color: VisualAtendimento.verde(context)),
          ),
        ]),
      );
}

class _SecaoProduto extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final int? contagem;
  final bool obrigatorio;
  final Widget child;

  const _SecaoProduto({
    required this.icon,
    required this.titulo,
    required this.contagem,
    required this.obrigatorio,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(titulo,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                if (obrigatorio)
                  Text('Obrigatório',
                      style: TextStyle(fontSize: 12, color: cs.error)),
              ])),
          if (contagem != null)
            Text('$contagem',
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
        ]),
      ),
      child,
    ]);
  }
}
