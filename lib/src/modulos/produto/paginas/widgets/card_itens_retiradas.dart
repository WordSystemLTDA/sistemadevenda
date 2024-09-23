import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_itens_retirada_produto.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardItensRetiradas extends StatefulWidget {
  final ModeloDadosOpcoesPacotes item;
  const CardItensRetiradas({super.key, required this.item});

  @override
  State<CardItensRetiradas> createState() => _CardItensRetiradasState();
}

class _CardItensRetiradasState extends State<CardItensRetiradas> {
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

  @override
  Widget build(BuildContext context) {
    var item = Modeloworditensretiradaproduto.fromMap(widget.item.toMap());

    return Card(
      child: InkWell(
        onTap: () {
          _provedorProduto.selecionarItensRetirada(item);
        },
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _provedorProduto.listaItensRetirada.where((element) => element.id == item.id).isNotEmpty,
                    onChanged: (bool? value) {
                      _provedorProduto.selecionarItensRetirada(item);
                    },
                  ),
                  Text(item.nome),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
