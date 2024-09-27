import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_acompanhamentos.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_adicionais.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_itens_retiradas.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_tamanhos.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaProduto extends StatefulWidget {
  final ModeloProduto produto;
  final String tipo;
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  const PaginaProduto({super.key, required this.produto, required this.tipo, required this.idComanda, required this.idComandaPedido, required this.idMesa});

  @override
  State<PaginaProduto> createState() => _PaginaProdutoState();
}

class _PaginaProdutoState extends State<PaginaProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

  ModeloProduto? produto;
  bool isLoading = false;
  TextEditingController obsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    produto = widget.produto;
    _provedorProduto.listaAcompanhamentos = widget.produto.acompanhamentos;
    _provedorProduto.valorVenda = double.parse(widget.produto.valorVenda);
  }

  void inserirNoCarrinho() async {
    final idComanda = widget.idComanda;
    final idMesa = widget.idMesa;

    var comanda = idComanda.isEmpty ? 0 : idComanda;
    var mesa = idMesa.isEmpty ? 0 : idMesa;
    var valor = produto!.valorVenda;
    var idProduto = produto!.id;
    var observacaoMesa = '';
    var observacao = obsController.text;

    // print(_provedorProduto.listaTamanhos);
    // return;

    if (widget.produto.tamanhos.isNotEmpty && _provedorProduto.listaTamanhos.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Selecione um tamanho antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    setState(() => isLoading = !isLoading);

    widget.produto.quantidade = _provedorProduto.quantidade.toDouble();
    widget.produto.valorVenda = _provedorProduto.valorVenda.toStringAsFixed(2);
    widget.produto.tamanhos = _provedorProduto.listaTamanhos;
    widget.produto.adicionais = _provedorProduto.listaAdicionais;
    widget.produto.acompanhamentos = _provedorProduto.listaAcompanhamentos;
    widget.produto.itensRetiradas = _provedorProduto.listaItensRetirada;

    await carrinhoProvedor
        .inserir(
      produto!,
      widget.tipo,
      mesa,
      comanda,
      widget.idComandaPedido,
      valor,
      observacaoMesa,
      idProduto,
      produto!.nome,
      produto!.quantidade,
      observacao,
    )
        .then((sucesso) {
      if (sucesso) {
        _provedorProduto.resetarTudo();
        if (mounted) Navigator.pop(context);
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ocorreu um erro'),
          showCloseIcon: true,
        ));
      }
    }).whenComplete(() {
      setState(() => isLoading = !isLoading);
    });
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);

        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: AnimatedBuilder(
        animation: _provedorProduto,
        builder: (context, valueProdutoProvedor) {
          return Scaffold(
            appBar: AppBar(
              title: Text("${produto.nome} ${produto.tamanho}"),
              backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            ),
            // backgroundColor: Colors.white,
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                inserirNoCarrinho();
              },
              label: isLoading
                  ? const CircularProgressIndicator()
                  : Row(
                      children: [
                        const SizedBox(width: 10),
                        Text('${_provedorProduto.quantidade}x ${(_provedorProduto.valorVenda).obterReal()}'),
                        const SizedBox(width: 10),
                        const Icon(Icons.check),
                        const SizedBox(width: 10),
                      ],
                    ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        produto.foto.isEmpty
                            ? Image.asset(Assets.boxAsset, width: 120, height: 120)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedNetworkImage(
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.contain,
                                  fadeOutDuration: const Duration(milliseconds: 100),
                                  placeholder: (context, url) => const SizedBox(
                                    height: 50.0,
                                    width: 50.0,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                  imageUrl: produto.foto,
                                ),
                              ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _provedorProduto.aoDiminuirQuantidade(),
                                  icon: Icon(
                                    Icons.remove_circle_outline,
                                    size: 30,
                                    color: _provedorProduto.quantidade == 1 ? Colors.grey : Colors.red,
                                  ),
                                ),
                                Text(
                                  _provedorProduto.quantidade.toString(),
                                  style: const TextStyle(fontSize: 20),
                                ),
                                IconButton(
                                  onPressed: () => _provedorProduto.aoAumentarQuantidade(),
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    size: 30,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const Text("Preço", style: TextStyle(fontSize: 18)),
                            Text(
                              (widget.produto.tamanhos.isNotEmpty && _provedorProduto.listaTamanhos.isEmpty)
                                  ? "${double.parse(widget.produto.tamanhos.first.valor).obterReal()} à ${double.parse(widget.produto.tamanhos.last.valor).obterReal()}"
                                  : (_provedorProduto.valorVenda).obterReal(),
                              style: const TextStyle(color: Colors.green, fontSize: 18),
                            ),
                            const Row(
                              children: [
                                Text("Total", style: TextStyle(fontSize: 18)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Observações: ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text(
                          (_provedorProduto.valorVenda * _provedorProduto.quantidade).obterReal(),
                          style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    child: TextField(
                      controller: obsController,
                      decoration: const InputDecoration(
                        alignLabelWithHint: true,
                        hintText: "Digite alguma observação",
                        hintStyle: TextStyle(fontWeight: FontWeight.w300),
                        border: UnderlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  if (produto.descricao.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        produto.descricao,
                        overflow: TextOverflow.fade,
                        maxLines: 6,
                        style: const TextStyle(color: Color.fromARGB(255, 161, 161, 161)),
                      ),
                    ),
                  ],
                  if (produto.opcoesPacotes!.isNotEmpty) ...[
                    ...produto.opcoesPacotes!.map((opcoesPacote) {
                      return Container(
                        padding: const EdgeInsets.only(left: 20, right: 20),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.5),
                              blurRadius: 30.0,
                              spreadRadius: -30,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Card(
                              margin: EdgeInsets.zero,
                              color: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              elevation: 0,
                              child: Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(left: 10),
                                          child: Text(
                                            '${opcoesPacote.titulo} (${opcoesPacote.dados.length})',
                                            style: const TextStyle(fontSize: 16),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: opcoesPacote.dados.length,
                                    padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                    itemBuilder: (context, index) {
                                      var item = opcoesPacote.dados[index];

                                      if (opcoesPacote.id == 1) {
                                        return CardTamanhos(item: item);
                                      } else if (opcoesPacote.id == 2) {
                                        return CardAcompanhamentos(item: item);
                                      } else if (opcoesPacote.id == 3) {
                                        return CardAdicionais(item: item);
                                      } else {
                                        return CardItensRetiradas(item: item);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
