import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_cidade.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:app/src/modulos/vendas/provedores/provedores_listar_vendas.dart';
import 'package:app/src/modulos/vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(DioCliente());
    i.addSingleton(UsuarioProvedor.new);
    i.addSingleton(Server.new);
    i.addSingleton(ConfigProvider.new);

    i.add(ServicoConfigBigchef.new);
    i.add(ServicoConfig.new);

    // Categorias
    i.add(ServicosCategoria.new);

    // Mesas
    i.add<ServicoMesas>(ServicoMesas.new);
    i.addSingleton<ProvedorMesas>(ProvedorMesas.new);

    // Balcão
    i.addSingleton<ProvedorBalcao>(ProvedorBalcao.new);
    i.add<ServicoBalcao>(ServicoBalcao.new);

    // FINALIZAR
    i.addSingleton<ProvedorFinalizarPagamento>(ProvedorFinalizarPagamento.new);
    i.add<ServicoFinalizarPagamento>(ServicoFinalizarPagamento.new);

    i.add<ServicosItensComanda>(ServicosItensComanda.new);

    // Comandas
    i.addSingleton<ProvedorComanda>(ProvedorComanda.new);
    i.add<ServicoComandas>(ServicoComandas.new);

    // Carrinho
    i.addSingleton(ProvedorCarrinho.new);

    // Cardapio
    i.add<ServicoCardapio>(ServicoCardapio.new);
    i.addSingleton<ProvedorCardapio>(ProvedorCardapio.new);
    i.add<ProvedorProdutos>(ProvedorProdutos.new);

    // Vendas
    i.addSingleton(ProvedoresListarVendas.new);
    i.add<ServicosListarVendas>(ServicosListarVendas.new);

    // Autenticacao
    i.add<ServicoAutenticacao>(ServicoAutenticacao.new);

    // Produto
    i.addSingleton<ProvedorProduto>(ProvedorProduto.new);
    i.add(ServicoProduto.new);

    i.add(ServicoCidade.new);
  }
}
