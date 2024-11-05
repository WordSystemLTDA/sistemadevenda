import 'package:app/src/essencial/widgets/keep_alive_wrapper.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_lista_financeiro_venda.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaDetalhesDaVendaBalcao extends StatefulWidget {
  final String idVenda;
  const PaginaDetalhesDaVendaBalcao({super.key, required this.idVenda});

  @override
  State<PaginaDetalhesDaVendaBalcao> createState() => _PaginaDetalhesDaVendaBalcaoState();
}

class _PaginaDetalhesDaVendaBalcaoState extends State<PaginaDetalhesDaVendaBalcao> {
  var servico = Modular.get<ServicoBalcao>();
  RetornoListarPorIdBalcao? informacoes;
  bool carregando = true;
  List<Modelolistafinanceirovenda> parcelas = [];

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    informacoes = await servico.listarPorId(widget.idVenda);
    parcelas = await servico.listarFinanceiroVenda(widget.idVenda);

    setState(() {
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes Balcão'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Visibility(
        visible: informacoes != null,
        replacement: const Center(child: CircularProgressIndicator()),
        child: DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: [
                  Tab(child: Text('Geral')),
                  Tab(child: Text('Financeiro')),
                ],
              ),
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    KeepAliveWrapper(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text.rich(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      TextSpan(
                                        text: 'Cliente: ',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        children: [
                                          TextSpan(
                                            text: informacoes?.informacoes.nomeCliente,
                                            style: const TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: Text.rich(
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      TextSpan(
                                        text: 'Vendedor(a): ',
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                        children: [
                                          TextSpan(
                                            text: (informacoes?.informacoes.nomevendedor ?? '').isEmpty ? 'Sem Vendedor' : informacoes?.informacoes.nomevendedor,
                                            style: const TextStyle(fontWeight: FontWeight.normal),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Telefone: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: (informacoes?.informacoes.telefonecliente ?? '').isEmpty ? 'Sem Telefone' : informacoes?.informacoes.telefonecliente,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Celular: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: (informacoes?.informacoes.celularcliente ?? '').isEmpty ? 'Sem Celular' : informacoes?.informacoes.celularcliente,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text.rich(
                                    TextSpan(
                                      text: 'Data: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: informacoes?.informacoes.datalanc,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text.rich(
                                    TextSpan(
                                      text: 'Pedido: ',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                      children: [
                                        TextSpan(
                                          text: informacoes?.informacoes.numerodopedido,
                                          style: const TextStyle(fontWeight: FontWeight.normal),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text.rich(
                                TextSpan(
                                  text: 'Endereço: ',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  children: [
                                    TextSpan(
                                      text:
                                          '${informacoes?.informacoes.enderecoenderecocliente}, ${informacoes?.informacoes.nomebairro}, ${informacoes?.informacoes.nomecidade} - ${informacoes?.informacoes.nomeestado} ${informacoes?.informacoes.cependerecocliente}.',
                                      style: const TextStyle(fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.only(left: 4, bottom: 4),
                                child: Text(
                                  'Produtos e Serviços (${informacoes?.produtos.length})',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: informacoes?.produtos.length,
                                itemBuilder: (context, index) {
                                  var item = informacoes?.produtos[index];

                                  return Card(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text("Código: ${item!.codigo}", style: const TextStyle(fontSize: 13)),
                                          Text(item.nome, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(double.parse(item.valorVenda).obterReal()),
                                              const Text('x'),
                                              Text(item.quantidade.toString()),
                                              const Text('='),
                                              Text((double.parse(item.valorVenda) * num.parse(item.quantidade.toString())).obterReal()),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    KeepAliveWrapper(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 4),
                              child: Text(
                                'Meios de Pagamentos (${parcelas.length})',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: parcelas.length,
                              itemBuilder: (context, index) {
                                var item = parcelas[index];

                                return Card(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Parcela: ${item.descricaoMov}", style: const TextStyle(fontSize: 13)),
                                        Text(item.valorMovF, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 5),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(item.entradaMov),
                                            Text(item.vencimentoMovF),
                                            Text(item.statusMov),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
