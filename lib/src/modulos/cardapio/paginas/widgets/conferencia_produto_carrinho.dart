import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/botao_editar_produto_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';

class CardConferenciaCarrinho extends StatelessWidget {
  final bool conferido;
  final Widget child;

  const CardConferenciaCarrinho({
    super.key,
    required this.conferido,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: conferido
          ? (escuro ? const Color(0xFF19372B) : const Color(0xFFEDF8F0))
          : VisualAtendimento.superficie(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: conferido
              ? (escuro ? const Color(0xFF4C9F73) : const Color(0xFF8AC5A0))
              : Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.6),
        ),
      ),
      child: child,
    );
  }
}

class AcoesProdutoCarrinho extends StatefulWidget {
  final Modelowordprodutos item;
  final int index;
  final bool recorrentes;
  final Future<bool> Function(bool conferido) aoConferir;

  const AcoesProdutoCarrinho({
    super.key,
    required this.item,
    required this.index,
    required this.aoConferir,
    this.recorrentes = false,
  });

  @override
  State<AcoesProdutoCarrinho> createState() => _AcoesProdutoCarrinhoState();
}

class _AcoesProdutoCarrinhoState extends State<AcoesProdutoCarrinho> {
  bool _salvando = false;

  Future<void> _alternarConferencia() async {
    if (_salvando) return;
    setState(() => _salvando = true);
    try {
      final salvo = await widget.aoConferir(!widget.item.conferidoNoCarrinho);
      if (!salvo) throw StateError('Conferencia nao salva.');
      FeedbackUsuario.selecaoAlterada();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'N\u00e3o foi poss\u00edvel salvar a confer\u00eancia. Tente novamente.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final conferido = widget.item.conferidoNoCarrinho;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final verde = escuro ? const Color(0xFF9FE1B6) : const Color(0xFF21663D);
    final editar = BotaoEditarProdutoCarrinho(
      item: widget.item,
      index: widget.index,
      recorrentes: widget.recorrentes,
      padding: EdgeInsets.zero,
    );
    final conferir = Semantics(
      toggled: conferido,
      child: Tooltip(
        message: conferido ? 'Desmarcar confer\u00eancia' : 'Conferir produto',
        child: OutlinedButton.icon(
          onPressed: _salvando ? null : _alternarConferencia,
          icon: _salvando
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  conferido ? Icons.check_circle : Icons.check_circle_outline,
                  size: 20),
          label: Text(conferido ? 'Conferido' : 'Conferir'),
          style: OutlinedButton.styleFrom(
            foregroundColor: verde,
            backgroundColor: conferido
                ? (escuro ? const Color(0xFF264F39) : const Color(0xFFD9EFDF))
                : Colors.transparent,
            side: BorderSide(color: verde.withValues(alpha: 0.45)),
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: LayoutBuilder(builder: (context, constraints) {
        final escala = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 320 * escala) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [editar, const SizedBox(height: 8), conferir],
          );
        }
        return Row(
          children: [
            Expanded(child: editar),
            const SizedBox(width: 8),
            Expanded(child: conferir),
          ],
        );
      }),
    );
  }
}
