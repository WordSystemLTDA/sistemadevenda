import 'package:app/src/modulos/vendas/modelos/salvar_vendas_modelo.dart';
import 'package:app/src/modulos/vendas/paginas/widgets/dados_gerais_listar_vendas.dart';
import 'package:app/src/modulos/vendas/paginas/widgets/nota_referenciada_listar_vendas.dart';
import 'package:app/src/modulos/vendas/paginas/widgets/obs_interna_listar_vendas.dart';
import 'package:app/src/modulos/vendas/paginas/widgets/transportadora_listar_vendas.dart';
import 'package:app/src/modulos/vendas/provedores/provedores_listar_vendas.dart';
import 'package:app/src/modulos/vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class CadastrarListarVendas extends StatefulWidget {
  final Function aoSalvar;
  const CadastrarListarVendas({super.key, required this.aoSalvar});

  @override
  State<CadastrarListarVendas> createState() => _CadastrarListarVendasState();
}

class _CadastrarListarVendasState extends State<CadastrarListarVendas> with TickerProviderStateMixin {
  final ProvedoresListarVendas _provedor = Modular.get<ProvedoresListarVendas>();

  late final TabController _tabController;

  final _clienteController = TextEditingController();
  final _nomeClienteController = TextEditingController();
  final _naturezaController = TextEditingController();
  final _nomeNaturezaController = TextEditingController();
  final _vendedorController = TextEditingController();
  final _nomeVendedorController = TextEditingController();
  final _dataLancamentoController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));

  final _transportadoraController = TextEditingController();
  final _nomeTransportadoraController = TextEditingController();
  final _fretePorContaController = TextEditingController();
  final _nomeFretePorContaController = TextEditingController();
  final _placaDoVeiculoController = TextEditingController();
  final _ufController = TextEditingController();
  final _quantidadeController = TextEditingController();
  final _especieController = TextEditingController();
  final _marcaController = TextEditingController();
  final _numeracaoController = TextEditingController();
  final _pesoBrutoController = TextEditingController();
  final _pesoLiquidoController = TextEditingController();

  final _tipoReferenciaController = TextEditingController();
  final _nomeTipoReferenciaController = TextEditingController();
  final _chaveAcessoController = TextEditingController();

  final _observacoesInternaController = TextEditingController();
  final _dadosAdicionaisController = TextEditingController();

  void inserir() async {
    if (_clienteController.text.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um Cliente'),
        backgroundColor: Colors.red,
        showCloseIcon: true,
      ));
      return;
    }

    final data = _dataLancamentoController.text.split('/');

    final res = await _provedor.inserir(
      SalvarVendasModelo(
        id: '',
        cliente: _clienteController.text,
        nomeCliente: _nomeClienteController.text,
        natureza: _naturezaController.text,
        nomeNatureza: _nomeNaturezaController.text,
        vendedor: _vendedorController.text,
        nomeVendedor: _nomeVendedorController.text,
        dataLancamento: data.length == 1 ? '' : '${data[2]}-${data[1]}-${data[0]}',
        transportadora: _transportadoraController.text,
        nomeTransportadora: '',
        fretePorConta: _fretePorContaController.text,
        nomeFretePorConta: '',
        placaDoVeiculo: _placaDoVeiculoController.text,
        uf: _ufController.text,
        quantidade: _quantidadeController.text,
        especie: _especieController.text,
        marca: _marcaController.text,
        numeracao: _numeracaoController.text,
        pesoBruto: _pesoBrutoController.text,
        pesoLiquido: _pesoLiquidoController.text,
        tipoReferencia: _tipoReferenciaController.text,
        nomeTipoReferencia: _nomeTipoReferenciaController.text,
        chaveAcesso: _chaveAcessoController.text,
        observacoesInterna: _observacoesInternaController.text,
        dadosAdicionais: _dadosAdicionaisController.text,
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (res) {
      widget.aoSalvar();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Cadastrado com Sucesso!'),
        backgroundColor: Colors.green,
        showCloseIcon: true,
      ));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Ocorreu um Erro!'),
      backgroundColor: Colors.red,
      showCloseIcon: true,
    ));
  }

  void listarNatureza() async {
    final res = await Modular.get<ServicosListarVendas>().listarNatureza('');

    res.map((e) {
      if (e.nome == 'Venda') {
        _naturezaController.text = e.id;
        _nomeNaturezaController.text = e.nome;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 4, vsync: this);

    listarNatureza();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabAlignment: TabAlignment.start,
          isScrollable: true,
          tabs: const [
            Tab(
              text: 'Dados Gerais',
            ),
            Tab(
              text: 'Transportadora / Volumes',
            ),
            Tab(
              text: 'Nota Referenciada',
            ),
            Tab(
              text: 'Obs Interna',
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => inserir(),
        label: const Text('Adicionar Item'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          DadosGeraisListarVendas(
            clienteController: _clienteController,
            nomeClienteController: _nomeClienteController,
            naturezaController: _naturezaController,
            nomeNaturezaController: _nomeNaturezaController,
            vendedorController: _vendedorController,
            nomeVendedorController: _nomeVendedorController,
            dataLancamentoController: _dataLancamentoController,
          ),
          TransportadoraListarVendas(
            transportadoraController: _transportadoraController,
            nomeTransportadoraController: _nomeTransportadoraController,
            fretePorContaController: _fretePorContaController,
            nomeFretePorContaController: _nomeFretePorContaController,
            placaDoVeiculoController: _placaDoVeiculoController,
            ufController: _ufController,
            quantidadeController: _quantidadeController,
            especieController: _especieController,
            marcaController: _marcaController,
            numeracaoController: _numeracaoController,
            pesoBrutoController: _pesoBrutoController,
            pesoLiquidoController: _pesoLiquidoController,
          ),
          NotaReferenciadaListarVendas(
            tipoReferenciaController: _tipoReferenciaController,
            nomeTipoReferenciaController: _nomeTipoReferenciaController,
            chaveAcessoController: _chaveAcessoController,
          ),
          ObsInternaListarVendas(
            observacoesInternaController: _observacoesInternaController,
            dadosAdicionaisController: _dadosAdicionaisController,
          ),
        ],
      ),
    );
  }
}
