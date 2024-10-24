import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/client.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/listar_vendas/provedores/provedores_listar_vendas.dart';
import 'package:app/src/modulos/listar_vendas/servicos/servicos_listar_vendas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(DioCliente());
    i.addSingleton(UsuarioProvedor.new);
    i.addSingleton(Client.new);

    i.add(ServicoConfigBigchef.new);

    // Categorias
    i.add(ServicosCategoria.new);

    // Mesas
    i.add<ServicoMesas>(ServicoMesas.new);
    i.add<ProvedorMesas>(ProvedorMesas.new);

    i.add<ServicosItensComanda>(ServicosItensComanda.new);

    // Comandas
    i.addSingleton<ProvedorComanda>(ProvedorComanda.new);
    i.add<ServicoComandas>(ServicoComandas.new);

    // Carrinho
    i.addSingleton(ProvedorCarrinho.new);

    // Cardapio
    i.add<ServicoCardapio>(ServicoCardapio.new);
    i.addSingleton<ProvedorCardapio>(ProvedorCardapio.new);

    // Vendas
    i.addSingleton(ProvedoresListarVendas.new);
    i.add<ServicosListarVendas>(ServicosListarVendas.new);

    // Autenticacao
    i.add<ServicoAutenticacao>(ServicoAutenticacao.new);

    // Produto
    i.addSingleton<ProvedorProduto>(ProvedorProduto.new);
    i.add(ServicoProduto.new);
  }
}
