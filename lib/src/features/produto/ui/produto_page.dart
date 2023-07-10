import 'package:app/src/features/produtos/interactor/models/produto_model.dart';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProdutoPage extends StatefulWidget {
  final ProdutoModel produto;
  const ProdutoPage({super.key, required this.produto});

  @override
  State<ProdutoPage> createState() => _ProdutoPageState();
}

class _ProdutoPageState extends State<ProdutoPage> {
  late int quantidade = 1;

  void incrementar() {
    setState(() {
      quantidade++;
    });
  }

  void decrementar() {
    if (quantidade > 1) {
      setState(() {
        quantidade--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;

    return Scaffold(
      appBar: AppBar(
        title: Text("${produto.nome} ${produto.tamanho}"),
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
                  child: Image.network(
                    produto.imagem,
                    fit: BoxFit.cover,
                    width: 120,
                    height: 120,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: decrementar,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        size: 30,
                        color: quantidade == 1 ? Colors.grey : Colors.red,
                      ),
                    ),
                    Text(
                      quantidade.toString(),
                      style: const TextStyle(fontSize: 20),
                    ),
                    IconButton(
                      onPressed: incrementar,
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
                  maxLines: 2,
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
                  "R\$ ${produto.valor}",
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
                  "R\$ ${produto.valor * quantidade}",
                  style: const TextStyle(color: Colors.green, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Modular.to.pop();
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
