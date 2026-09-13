import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/modal_digitar_codigo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montagem_pizza_test.dart' as fixture;

class ConfigCodigoTeste extends fixture.ConfiguracoesTeste {
  ConfigCodigoTeste() : super('media');
  @override
  String get modaladdmesa => '3';
  @override
  String get modaladdcomanda => '3';
}

class ServicoCodigoTeste extends Fake implements ServicoCardapio {
  @override
  Future<
      ({
        String id,
        String codigo,
        String nome,
        String idComandaPedido,
        bool ocupado,
        bool sucesso,
        String idCliente,
        bool fechamento
      })> listarIdCodigoQrcode(
          TipoCardapio tipo, String? codigoQrcode) async =>
      (
        id: '701',
        codigo: '7',
        nome: '${tipo.nome}: 7',
        idComandaPedido: '10999',
        ocupado: true,
        sucesso: true,
        idCliente: '0',
        fechamento: false,
      );
}

class ModuloCodigoTeste extends fixture.ModuloTeste {
  ModuloCodigoTeste(super.cardapio, super.usuario, super.produtos);
  @override
  void binds(Injector i) {
    super.binds(i);
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<ServicoCardapio>(ServicoCodigoTeste());
  }
}

void main() {
  for (final tipo in [TipoCardapio.mesa, TipoCardapio.comanda]) {
    testWidgets(
        'codigo de ${tipo.nome} preserva recurso e atendimento distintos',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final usuarios = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(
            id: '1', empresa: '32', configuracoes: ConfigCodigoTeste()));
      final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuarios);
      Modular.init(
          ModuloCodigoTeste(cardapio, usuarios, fixture.ProdutosTeste()));
      addTearDown(() {
        Modular.destroy();
        cardapio.dispose();
        usuarios.dispose();
      });
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                    body: TextButton(
                      onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ModalDigitarCodigo(tipo: tipo)),
                      child: const Text('Código'),
                    ),
                  ))));
      await tester.tap(find.text('Código'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '7');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Abrir'));
      await tester.pumpAndSettle();
      final pagina = tester.widget<PaginaCardapio>(find.byType(PaginaCardapio));
      expect(pagina.tipo, tipo);
      expect(pagina.id, '10999');
      expect(pagina.nomeAtendimento, '${tipo.nome}: 7');
      expect(pagina.idMesa, tipo == TipoCardapio.mesa ? '701' : '0');
      expect(pagina.idComanda, tipo == TipoCardapio.comanda ? '701' : '0');
      final contexto = Modular.get<ProvedorCarrinho>().contexto!;
      expect(contexto.tipo, tipo.name);
      expect(contexto.idRecurso, '701');
      expect(contexto.idAtendimento, '10999');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
