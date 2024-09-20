import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CardProduto extends StatefulWidget {
  final bool estaPesquisando;
  final SearchController? searchController;
  final dynamic item;
  final String tipo;
  final String idComanda;
  final String idMesa;
  const CardProduto({
    super.key,
    this.searchController,
    required this.estaPesquisando,
    required this.item,
    required this.tipo,
    required this.idComanda,
    required this.idMesa,
  });

  @override
  State<CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<CardProduto> {
  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        key: widget.key,
        onTap: () async {
          if (widget.estaPesquisando) {
            widget.searchController!.closeView(widget.item.nome);
          }

          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) {
              return PaginaProduto(idComanda: widget.idComanda, idMesa: widget.idMesa, tipo: widget.tipo, produto: widget.item);
            },
          ));
        },
        borderRadius: BorderRadius.circular(5),
        child: Row(
          children: [
            widget.item.foto.isEmpty
                ? Image.asset(Assets.produtoAsset, width: 100, height: 100)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8.0),
                    child: CachedNetworkImage(
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                      fadeOutDuration: const Duration(milliseconds: 100),
                      placeholder: (context, url) => const SizedBox(
                        height: 50.0,
                        width: 50.0,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const Icon(Icons.error),
                      imageUrl: widget.item.foto,
                    ),
                  ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 1.6,
                      child: Text(
                        "${widget.item.nome} ${widget.item.tamanho}",
                        style: const TextStyle(
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 1.6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Text(
                          widget.item.descricao.isEmpty ? 'Sem descrição' : widget.item.descricao,
                          overflow: TextOverflow.fade,
                          // softWrap: false,
                          maxLines: 2,
                          style: const TextStyle(
                            color: Color.fromARGB(255, 111, 111, 111),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 1.6,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        double.parse(widget.item.valorVenda).obterReal(),
                        style: const TextStyle(color: Colors.green, fontSize: 17),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
