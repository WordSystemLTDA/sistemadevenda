import 'package:app/src/modulos/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/modulos/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/modulos/cardapio/interactor/provedor/cardapio_provedor.dart';
import 'package:app/src/modulos/cardapio/interactor/provedor/carrinho_provedor.dart';
import 'package:app/src/modulos/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/modulos/cardapio/interactor/services/produto_service.dart';
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
    i.add<CategoriaService>(CategoriaServiceImpl.new);

    // Mesas
    i.add<MesaService>(MesaServiceImpl.new);

    // Comandas
    i.add<ProdutoProvedor>(ProdutoProvedor.new);

    // Cardapio
    i.addSingleton<CarrinhoProvedor>(CarrinhoProvedor.new);
    i.add<CardapioProvedor>(CardapioProvedor.new);

    // Autenticacao
    i.add<AutenticacaoService>(AutenticacaoServiceImpl.new);

    // Produto
    i.add<ProdutoService>(ProdutoServiceImpl.new);
  }
}
