import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProdutoPage extends StatefulWidget {
  final ProdutoModel produto;
  final String tipo;
  final String idComanda;
  final String idMesa;
  const ProdutoPage({super.key, required this.produto, required this.tipo, required this.idComanda, required this.idMesa});

  @override
  State<ProdutoPage> createState() => _ProdutoPageState();
}

class _ProdutoPageState extends State<ProdutoPage> {
  final ItensComandaState stateItensComanda = ItensComandaState();
  bool isLoading = false;

  TextEditingController controller = TextEditingController();

  int counter = 1;
  void updateCounter(bool isDecrement) {
    if (isDecrement) {
      if (counter == 1) return;
      setState(() => --counter);
    } else {
      setState(() => counter++);
    }
  }

  @override
  void initState() {
    super.initState();

    print('Tipo: ${widget.tipo}');
    print('Mesa: ${widget.idMesa}');
    print('Comanda: ${widget.idComanda}');
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;
    final idComanda = widget.idComanda;
    final tipo = widget.tipo;

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);

        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("${produto.nome} ${produto.tamanho}"),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            var comanda = idComanda!.isEmpty ? null : idComanda;
            var valor = produto.valorVenda;
            var idProduto = produto.id;
            var observacaoMesa = '';
            var observacao = controller.text;

            setState(() => isLoading = !isLoading);
            final res = await stateItensComanda.inserir(widget.idMesa, comanda, valor, observacaoMesa, idProduto, counter, observacao);
            setState(() => isLoading = !isLoading);

            if (res) {
              Navigator.pop(context);
              return;
            }

            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Ocorreu um erro'),
              showCloseIcon: true,
            ));
          },
          child: isLoading ? const CircularProgressIndicator() : const Icon(Icons.check),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
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
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => updateCounter(true),
                        icon: Icon(
                          Icons.remove_circle_outline,
                          size: 30,
                          color: counter == 1 ? Colors.grey : Colors.red,
                        ),
                      ),
                      Text(
                        counter.toString(),
                        style: const TextStyle(fontSize: 20),
                      ),
                      IconButton(
                        onPressed: () => updateCounter(false),
                        icon: const Icon(
                          Icons.add_circle_outline,
                          size: 30,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 5),
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
              Row(
                children: [
                  const Text(
                    "Preço: ",
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    Utils.coverterEmReal.format(double.parse(produto.valorVenda)),
                    style: const TextStyle(color: Colors.green, fontSize: 18),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text(
                    "Total: ",
                    style: TextStyle(fontSize: 18),
                  ),
                  Text(
                    Utils.coverterEmReal.format(double.parse(produto.valorVenda) * counter),
                    style: const TextStyle(color: Colors.green, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(
                  alignLabelWithHint: true,
                  labelText: "Observação do Produto",
                  hintStyle: TextStyle(fontWeight: FontWeight.w300),
                  border: OutlineInputBorder(),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
