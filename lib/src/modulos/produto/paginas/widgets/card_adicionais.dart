import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_adicionais_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardAdicionais extends StatefulWidget {
  final ModeloDadosOpcoesPacotes item;
  const CardAdicionais({super.key, required this.item});

  @override
  State<CardAdicionais> createState() => _CardAdicionaisState();
}

class _CardAdicionaisState extends State<CardAdicionais> {
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

  @override
  Widget build(BuildContext context) {
    var item = Modelowordadicionaisproduto.fromMap(widget.item.toMap());

    return Column(
      children: [
        Stack(
          children: [
            Card(
              margin: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _provedorProduto.selecionarAdicional(item),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        item.foto.isEmpty
                            ? Image.asset(Assets.produtoAsset, width: 70, height: 70)
                            : ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: CachedNetworkImage(
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.contain,
                                  fadeOutDuration: const Duration(milliseconds: 100),
                                  placeholder: (context, url) => const SizedBox(
                                    height: 70,
                                    width: 70,
                                    child: Center(child: CircularProgressIndicator()),
                                  ),
                                  errorWidget: (context, url, error) => const Icon(Icons.error),
                                  imageUrl: item.foto,
                                ),
                              ),
                        const SizedBox(width: 5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.nome, style: const TextStyle(fontSize: 15)),
                            Text(
                              double.parse(item.valor).obterReal(),
                              style: const TextStyle(fontSize: 15, color: Colors.green),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (_provedorProduto.listaAdicionais.isNotEmpty && _provedorProduto.listaAdicionais.where((element) => element.id == item.id).isNotEmpty) ...[
                      Row(
                        children: [
                          IconButton(
                            onPressed: () {
                              if (_provedorProduto.listaAdicionais.firstWhere((element) => element.id == item.id).quantidade > 1) {
                                setState(() {
                                  _provedorProduto.listaAdicionais.firstWhere((element) => element.id == item.id).quantidade--;
                                });
                              }
                            },
                            icon: Icon(
                              Icons.remove_circle_outline,
                              size: 30,
                              color: _provedorProduto.listaAdicionais.firstWhere((element) => element.id == item.id).quantidade == 1 ? Colors.grey : Colors.red,
                            ),
                          ),
                          Text(
                            _provedorProduto.listaAdicionais.firstWhere((element) => element.id == item.id).quantidade.toString(),
                            style: const TextStyle(fontSize: 20),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _provedorProduto.listaAdicionais.firstWhere((element) => element.id == item.id).quantidade++;
                              });
                            },
                            icon: const Icon(
                              Icons.add_circle_outline,
                              size: 30,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            ),
            if (item.estaSelecionado) ...[
              const Positioned(
                top: -10,
                left: -10,
                child: Icon(Icons.check, size: 90, color: Colors.green),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}