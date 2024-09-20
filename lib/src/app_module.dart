import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/comandas_state.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/listar_vendas/provedores/provedores_listar_vendas.dart';
import 'package:app/src/modulos/listar_vendas/servicos/servicos_listar_vendas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(DioCliente());
    i.addSingleton(UsuarioProvedor.new);

    // Categorias
    i.add(ServicosCategoria.new);

    // Mesas
    i.add<ServicoMesas>(ServicoMesas.new);
    i.add<ServicosItensComanda>(ServicosItensComanda.new);

    // Comandas
    i.add<ProvedorProduto>(ProvedorProduto.new);
    i.add<ComandasState>(ComandasState.new);
    i.add<ServicoComandas>(ServicoComandas.new);
    i.add<ServicoCardapio>(ServicoCardapio.new);

    // Cardapio
    i.addSingleton(ProvedorCarrinho.new);
    i.add<ProvedorCardapio>(ProvedorCardapio.new);

    // Vendas
    i.addSingleton(ProvedoresListarVendas.new);
    i.add<ServicosListarVendas>(ServicosListarVendas.new);

    // Autenticacao
    i.add<ServicoAutenticacao>(ServicoAutenticacao.new);

    // Produto
    i.add(ServicoProduto.new);
  }
}
