import 'package:app/src/essencial/widgets/linha_valor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class TituloOpcoesCarrinho extends StatelessWidget {
  final Modelowordprodutos item;
  final ModeloOpcoesPacotes grupo;

  const TituloOpcoesCarrinho(
      {super.key, required this.item, required this.grupo});

  @override
  Widget build(BuildContext context) {
    final titulo = Text(grupo.titulo,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
      child: [6, 7, 10].contains(grupo.id)
          ? LinhaValor(
              descricao: titulo,
              valor: Text(
                ValoresPizza.subtotal(item, grupo).obterReal(),
                key: ValueKey('subtotal_opcao_${grupo.id}'),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.primary),
              ),
            )
          : titulo,
    );
  }
}
