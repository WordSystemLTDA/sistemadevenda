import 'package:app/src/essencial/widgets/linha_valor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

bool _idCardapioValido(Object? valor) {
  final texto = (valor ?? '').toString().trim().toLowerCase();
  return texto.isNotEmpty && texto != '0' && texto != 'null';
}

bool _grupoMontagemCardapio(ModeloOpcoesPacotes grupo) =>
    grupo.tipo == 8 ||
    tituloIngredientesCardapio(grupo.titulo) ||
    (grupo.dados ?? const []).any((dado) =>
        dado.montagemCardapio != null ||
        _idCardapioValido(dado.idCategoriaCardapio));

class TituloOpcoesCarrinho extends StatelessWidget {
  final Modelowordprodutos item;
  final ModeloOpcoesPacotes grupo;

  const TituloOpcoesCarrinho(
      {super.key, required this.item, required this.grupo});

  @override
  Widget build(BuildContext context) {
    final montagemCardapio = _grupoMontagemCardapio(grupo);
    final produtoCardapio = _idCardapioValido(item.idCategoriaCardapio) ||
        (item.opcoesPacotesListaFinal ?? const <ModeloOpcoesPacotes>[])
            .any(_grupoMontagemCardapio);
    final adicionaisCardapio =
        produtoCardapio && (grupo.tipo == 3 || grupo.id == 7);
    final titulo = _TituloGrupoCarrinho(
      titulo: montagemCardapio
          ? 'Cardápio:'
          : adicionaisCardapio
              ? 'Adicionais:'
              : grupo.titulo,
      meiaBorda: grupo.id == 6 &&
          (grupo.dados ?? []).any((dado) => dado.somenteMetadeBorda),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 4),
      child: !montagemCardapio && [6, 7, 10].contains(grupo.id)
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

class _TituloGrupoCarrinho extends StatelessWidget {
  final String titulo;
  final bool meiaBorda;

  const _TituloGrupoCarrinho({
    required this.titulo,
    required this.meiaBorda,
  });

  @override
  Widget build(BuildContext context) {
    final estilo = const TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

    if (!meiaBorda) {
      return Text(titulo, style: estilo);
    }

    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(titulo, style: estilo),
        const _EtiquetaMeiaBordaCarrinho(),
      ],
    );
  }
}

class _EtiquetaMeiaBordaCarrinho extends StatelessWidget {
  const _EtiquetaMeiaBordaCarrinho();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Meio (1/2)',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}

class TotalOpcoesCarrinho extends StatelessWidget {
  final Modelowordprodutos item;

  const TotalOpcoesCarrinho({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      child: Column(
        children: [
          const Divider(height: 1),
          const SizedBox(height: 10),
          LinhaValor(
            descricao: const Text(
              'Total',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            valor: Text(
              (double.tryParse(item.valorVenda) ?? 0).obterReal(),
              key: const ValueKey('total_opcoes_carrinho'),
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
