import 'package:app/src/modulos/cardapio/modelos/modelo_acompanhamentos_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardAcompanhamentos extends StatefulWidget {
  final ModeloDadosOpcoesPacotes item;
  const CardAcompanhamentos({super.key, required this.item});

  @override
  State<CardAcompanhamentos> createState() => _CardAcompanhamentosState();
}

class _CardAcompanhamentosState extends State<CardAcompanhamentos> {
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  @override
  Widget build(BuildContext context) {
    var item = Modelowordacompanhamentosproduto.fromMap(widget.item.toMap());

    return Card(
      child: InkWell(
        onTap: () => _provedorProduto.selecionarAcompanhamentos(item),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        child: Padding(
          padding: const EdgeInsets.only(top: 5, bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: _provedorProduto.listaAcompanhamentos.where((element) => element.id == item.id).isNotEmpty,
                    onChanged: (value) {
                      _provedorProduto.selecionarAcompanhamentos(item);
                    },
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nome),
                      Text(
                        double.parse(item.valor) == 0 ? 'Grátis' : double.parse(item.valor).obterReal(),
                        style: const TextStyle(color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}