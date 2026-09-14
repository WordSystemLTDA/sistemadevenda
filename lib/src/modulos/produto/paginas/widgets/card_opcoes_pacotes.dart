// ignore_for_file: deprecated_member_use

import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardOpcoesPacotes extends StatefulWidget {
  final ModeloOpcoesPacotes opcoesPacote;
  final ModeloDadosOpcoesPacotes item;
  final bool kit;
  final String idProduto;
  final ProvedorProduto? provedor;
  final bool compacto;

  const CardOpcoesPacotes({
    super.key,
    required this.kit,
    required this.opcoesPacote,
    required this.item,
    required this.idProduto,
    this.provedor,
    this.compacto = false,
  });

  @override
  State<CardOpcoesPacotes> createState() => _CardOpcoesPacotesState();
}

class _CardOpcoesPacotesState extends State<CardOpcoesPacotes> {
  ProvedorProduto get _provedorProduto =>
      widget.provedor ?? Modular.get<ProvedorProduto>();

  void _selecionarItem(BuildContext context) {
    if (_provedorProduto
        .bordaPrecisaSelecionarQuantidade(widget.opcoesPacote)) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione a quantidade de sabores da borda primeiro.'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final estadoAnterior = _assinaturaOpcaoSelecionada();
    if (widget.opcoesPacote.id == 7) widget.item.quantidade ??= 1;
    _provedorProduto.selecionarItem(
      widget.item,
      widget.opcoesPacote,
      widget.kit,
      widget.idProduto,
    );
    if (estadoAnterior != _assinaturaOpcaoSelecionada()) {
      FeedbackUsuario.selecaoAlterada();
    } else if (widget.opcoesPacote.id == 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content:
            Text('Limite de bordas atingido. Desmarque uma borda para trocar.'),
      ));
    }
  }

  String _assinaturaOpcaoSelecionada() {
    return _provedorProduto
        .retornarDadosPorID(
          [widget.opcoesPacote.id],
          widget.kit,
          widget.idProduto,
        )
        .map((dado) =>
            '${dado.id}:${dado.quantidade ?? ''}:${dado.somenteMetadeBorda}')
        .join('|');
  }

  void _alterarQuantidade(int diferenca) {
    final selecionado = _provedorProduto
        .retornarDadosPorID(
            [widget.opcoesPacote.id], widget.kit, widget.idProduto)
        .where((dado) => dado.id == widget.item.id)
        .firstOrNull;
    if (selecionado == null) {
      if (diferenca > 0) _selecionarItem(context);
      return;
    }
    final quantidade = selecionado.quantidade ?? 1;
    if (quantidade + diferenca < 1) {
      _selecionarItem(context);
      return;
    }
    setState(() => selecionado.quantidade = quantidade + diferenca);
    FeedbackUsuario.selecaoAlterada();
    _provedorProduto.calcularValorVenda(widget.kit, widget.idProduto);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final grupo = widget.opcoesPacote;
    final cs = Theme.of(context).colorScheme;
    final dadosSelecionados = _provedorProduto
        .retornarDadosPorID([grupo.id], widget.kit, widget.idProduto);
    final selecionado =
        dadosSelecionados.where((dado) => dado.id == item.id).firstOrNull;
    final ativo = selecionado != null;
    final adicional = grupo.id == 7;
    final cor = VisualAtendimento.verde(context);
    final meiaBorda = grupo.id == 6 && selecionado?.somenteMetadeBorda == true;
    final valor = _valorExibido(grupo, item, selecionado, dadosSelecionados);
    final valorBase = double.tryParse(selecionado?.valorOriginal ??
            item.valorOriginal ??
            item.valor ??
            '') ??
        0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        key: ValueKey('opcao_${grupo.id}_${item.id}'),
        color: ativo
            ? Color.alphaBlend(cor.withValues(alpha: 0.07),
                VisualAtendimento.superficie(context))
            : VisualAtendimento.superficie(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
              color: ativo
                  ? cor.withValues(alpha: 0.6)
                  : cs.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _selecionarItem(context),
          child: LayoutBuilder(builder: (context, constraints) {
            final temFoto = !widget.compacto &&
                adicional &&
                item.foto?.isNotEmpty == true &&
                constraints.maxWidth >= 400;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(children: [
                if (temFoto) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item.foto!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      placeholder: (_, url) =>
                          const SizedBox.square(dimension: 44),
                      errorWidget: (_, url, error) =>
                          const Icon(Icons.restaurant_outlined),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (!adicional)
                  if ([1, 4, 11].contains(grupo.id))
                    Radio<bool>(
                        value: true,
                        groupValue: ativo,
                        onChanged: (_) => _selecionarItem(context))
                  else
                    Checkbox(
                        value: ativo,
                        onChanged: (_) => _selecionarItem(context)),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.nome,
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w500)),
                        if (meiaBorda) ...[
                          const SizedBox(height: 5),
                          _EtiquetaMeiaBorda(cor: cor),
                        ],
                        if (valor > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                              meiaBorda && valorBase > valor
                                  ? 'Cobrança: ${valor.obterReal()} • inteira ${valorBase.obterReal()}'
                                  : valor.obterReal(),
                              style: TextStyle(
                                  fontSize: 13, color: cs.onSurfaceVariant)),
                        ],
                      ]),
                ),
                if (adicional) ...[
                  const SizedBox(width: 6),
                  Semantics(
                    label: 'Quantidade de ${item.nome}',
                    value: '${selecionado?.quantidade ?? 0}',
                    child: SizedBox(
                      key: ValueKey('quantidade_adicional_${item.id}'),
                      width: 128,
                      height: 48,
                      child: Row(children: [
                        IconButton(
                          tooltip: 'Diminuir ${item.nome}',
                          constraints: const BoxConstraints.tightFor(
                              width: 48, height: 48),
                          padding: EdgeInsets.zero,
                          onPressed:
                              ativo ? () => _alterarQuantidade(-1) : null,
                          icon:
                              const Icon(Icons.remove_circle_outline, size: 24),
                        ),
                        SizedBox(
                            width: 32,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('${selecionado?.quantidade ?? 0}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            )),
                        IconButton(
                          tooltip: 'Aumentar ${item.nome}',
                          constraints: const BoxConstraints.tightFor(
                              width: 48, height: 48),
                          padding: EdgeInsets.zero,
                          onPressed: () => _alterarQuantidade(1),
                          icon: Icon(Icons.add_circle_outline,
                              size: 24, color: cor),
                        ),
                      ]),
                    ),
                  ),
                ],
              ]),
            );
          }),
        ),
      ),
    );
  }

  double _valorExibido(
    ModeloOpcoesPacotes grupo,
    ModeloDadosOpcoesPacotes item,
    ModeloDadosOpcoesPacotes? selecionado,
    List<ModeloDadosOpcoesPacotes> dadosSelecionados,
  ) {
    if (grupo.id == 6 && selecionado != null) {
      final dadosRateados = ValoresPizza.ratear(
          dadosSelecionados, _provedorProduto.modeloValorBorda);
      final rateado =
          dadosRateados.where((dado) => dado.id == selecionado.id).firstOrNull;
      return double.tryParse(rateado?.valor ?? selecionado.valor ?? '') ?? 0;
    }

    return double.tryParse(item.valor ?? '') ?? 0;
  }
}

class _EtiquetaMeiaBorda extends StatelessWidget {
  final Color cor;

  const _EtiquetaMeiaBorda({required this.cor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cor.withValues(alpha: 0.25)),
      ),
      child: Text(
        'Meia pizza',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: cs.brightness == Brightness.dark ? Colors.white : cor,
        ),
      ),
    );
  }
}
