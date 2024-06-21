import 'package:app/src/modulos/cardapio/provedor/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedor/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_produto.dart';
import 'package:app/src/modulos/listar_vendas/provedores/provedores_listar_vendas.dart';
import 'package:app/src/modulos/listar_vendas/servicos/servicos_listar_vendas.dart';
import 'package:app/src/modulos/login/data/services/autenticacao_service_impl.dart';
import 'package:app/src/modulos/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/modulos/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/modulos/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/modulos/produto/interactor/provedor/produto_provedor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(Dio());

    // Categorias
    i.add(ServicosCategoria.new);

    // Mesas
    i.add<MesaService>(MesaServiceImpl.new);

    // Comandas
    i.add<ProdutoProvedor>(ProdutoProvedor.new);

    // Cardapio
    i.addSingleton(ProvedorCarrinho.new);
    i.add<CardapioProvedor>(CardapioProvedor.new);

    // Vendas
    i.addSingleton(ProvedoresListarVendas.new);
    i.add<ServicosListarVendas>(ServicosListarVendas.new);

    // Autenticacao
    i.add<AutenticacaoService>(AutenticacaoServiceImpl.new);

    // Produto
    i.add(ServicosProduto.new);
  }
}
