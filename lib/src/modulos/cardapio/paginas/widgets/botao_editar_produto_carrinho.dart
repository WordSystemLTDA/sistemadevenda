import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class BotaoEditarProdutoCarrinho extends StatefulWidget {
  final Modelowordprodutos item;
  final int index;
  final bool recorrentes;

  const BotaoEditarProdutoCarrinho({
    super.key,
    required this.item,
    required this.index,
    this.recorrentes = false,
  });

  @override
  State<BotaoEditarProdutoCarrinho> createState() =>
      _BotaoEditarProdutoCarrinhoState();
}

class _BotaoEditarProdutoCarrinhoState
    extends State<BotaoEditarProdutoCarrinho> {
  bool _aberto = false;

  Future<void> _editar() async {
    if (_aberto) return;
    setState(() => _aberto = true);
    try {
      final original = Modelowordprodutos.fromMap(widget.item.toMap());
      final index = widget.index;
      final carrinho =
          widget.recorrentes ? null : Modular.get<ProvedorCarrinho>();
      final recorrentes =
          widget.recorrentes ? Modular.get<ProvedorItensRecorrentes>() : null;
      final contexto = carrinho?.contexto ?? recorrentes?.contexto;
      if (contexto == null) throw StateError('Carrinho indisponível.');
      final edicao = EdicaoProdutoCarrinho(
        item: original,
        servico: Modular.get<ServicoProduto>(),
        categorias: Modular.get<ServicosCategoria>(),
        usuario: Modular.get<UsuarioProvedor>(),
      );
      final salvo = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PaginaEditarProdutoCarrinho(
          edicao: edicao,
          carregarConfiguracao: () =>
              Modular.get<ServicoConfigBigchef>().listar(),
          aoSalvar: (produto) => carrinho != null
              ? carrinho.editar(produto, index,
                  contexto: contexto, original: original)
              : recorrentes!.editar(contexto.idAtendimento, produto, index,
                  contexto: contexto, original: original),
        ),
      ));
      if (mounted && salvo == true) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Produto atualizado no carrinho.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível abrir a edição do produto. Tente novamente.')));
      }
    } finally {
      if (mounted) setState(() => _aberto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.tonalIcon(
          onPressed: _aberto ? null : _editar,
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('Editar Produto'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
