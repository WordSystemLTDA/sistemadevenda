import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardOpcoesPacotes extends StatefulWidget {
  final ModeloOpcoesPacotes opcoesPacote;
  final ModeloDadosOpcoesPacotes item;
  final bool kit;
  final String idProduto;

  const CardOpcoesPacotes({
    super.key,
    required this.kit,
    required this.opcoesPacote,
    required this.item,
    required this.idProduto,
  });

  @override
  State<CardOpcoesPacotes> createState() => _CardOpcoesPacotesState();
}

class _CardOpcoesPacotesState extends State<CardOpcoesPacotes> {
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

  @override
  Widget build(BuildContext context) {
    var item = widget.item;
    var opcoesPacote = widget.opcoesPacote;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Stack(
        children: [
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _provedorProduto.selecionarItem(item, opcoesPacote, widget.kit, widget.idProduto),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (item.foto != null && item.foto!.isNotEmpty && opcoesPacote.id == 7) ...[
                        ClipRRect(
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
                            imageUrl: item.foto!,
                          ),
                        ),
                      ],
                      if (opcoesPacote.id == 8 || opcoesPacote.id == 5 || opcoesPacote.id == 6) ...[
                        Checkbox(
                          value: _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).where((element) => element.id == item.id).isNotEmpty,
                          onChanged: (bool? value) {
                            _provedorProduto.selecionarItem(item, opcoesPacote, widget.kit, widget.idProduto);
                          },
                        ),
                      ],
                      if (opcoesPacote.id == 1 || opcoesPacote.id == 4) ...[
                        Radio<bool>(
                          value: true,
                          groupValue: _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).where((element) => element.id == item.id).isNotEmpty,
                          onChanged: (bool? value) {
                            _provedorProduto.selecionarItem(item, opcoesPacote, widget.kit, widget.idProduto);

                            // if (sucesso == false) {
                            //   ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            //     content: Text('Máximo de produtos cortesia já escolhidos.'),
                            //     backgroundColor: Colors.red,
                            //   ));
                            // } else {
                            //   if (_provedorProduto.listaCortesias.firstOrNull != null) {
                            //     ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            //     ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            //       content: Text("${_provedorProduto.listaCortesias.length}/${_provedorProduto.listaCortesias.first.quantimaximaselecao} Selecionados"),
                            //       behavior: SnackBarBehavior.floating,
                            //     ));
                            //   }
                            // }
                          },
                        ),
                      ],
                      const SizedBox(width: 5),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(item.nome, style: const TextStyle(fontSize: 15)),
                          if (item.valor != null) ...[
                            Text(
                              double.parse(item.valor ?? '0').obterReal(),
                              style: const TextStyle(fontSize: 15, color: Colors.green),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  if (opcoesPacote.id == 7 &&
                      _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).where((element) => element.id == item.id).isNotEmpty) ...[
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (_provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade! >
                                1) {
                              setState(() {
                                _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade =
                                    _provedorProduto
                                            .retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto)
                                            .firstWhere((element) => element.id == item.id)
                                            .quantidade! -
                                        1;
                              });
                            }
                          },
                          icon: Icon(
                            Icons.remove_circle_outline,
                            size: 30,
                            color:
                                _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade == 1
                                    ? Colors.grey
                                    : Colors.red,
                          ),
                        ),
                        Text(
                          _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade.toString(),
                          style: const TextStyle(fontSize: 20),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade =
                                  _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).firstWhere((element) => element.id == item.id).quantidade! +
                                      1;
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
          if (opcoesPacote.id == 7 &&
              _provedorProduto.opcoesPacotesListaFinal.isNotEmpty &&
              _provedorProduto.retornarDadosPorID([opcoesPacote.id], widget.kit, widget.idProduto).where((element) => element.id == item.id).isNotEmpty) ...[
            const Positioned(
              top: -10,
              left: -10,
              child: Icon(Icons.check, size: 90, color: Colors.green),
            ),
          ],
        ],
      ),
    );
  }
}
