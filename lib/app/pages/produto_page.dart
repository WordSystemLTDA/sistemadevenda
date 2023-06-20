import 'package:app/app/data/models/produto_model.dart';
import 'package:app/app/pages/home_page.dart';
import 'package:flutter/material.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.produto.nome} ${widget.produto.tamanho}"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    widget.produto.imagem,
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                widget.produto.descricao,
                overflow: TextOverflow.fade,
                maxLines: 2,
                style:
                    const TextStyle(color: Color.fromARGB(255, 161, 161, 161)),
              ),
            ),
            Row(
              children: [
                const Text(
                  "Preço: ",
                  style: TextStyle(fontSize: 18),
                ),
                Text(
                  "R\$ ${widget.produto.valor}",
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
                  "R\$ ${widget.produto.valor * quantidade}",
                  style: const TextStyle(color: Colors.green, fontSize: 18),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
