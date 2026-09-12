import 'package:app/src/modulos/balcao/paginas/pagina_nova_venda_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

class ServicoBalcaoTeste extends Fake implements ServicoBalcao {}

class ModuloNovaVendaBalcaoTeste extends Module {
  late final provedor = ProvedorBalcao(ServicoBalcaoTeste());

  @override
  void binds(Injector i) {
    i.addInstance<ProvedorBalcao>(provedor);
  }
}

void main() {
  testWidgets('tipo de entrega usa botoes selecionaveis', (tester) async {
    final modulo = ModuloNovaVendaBalcaoTeste();
    Modular.init(modulo);
    addTearDown(() {
      Modular.destroy();
      modulo.provedor.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: PaginaNovaVendaBalcao(aoSalvar: () {}),
    ));

    expect(find.text('Consumir no Local'), findsOneWidget);
    expect(find.text('Retirar no Balcão'), findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('tipo_entrega_3')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('tipo_entrega_2')),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
        findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tipo_entrega_2')));
    await tester.pumpAndSettle();

    expect(
        find.descendant(
          of: find.byKey(const ValueKey('tipo_entrega_3')),
          matching: find.byIcon(Icons.radio_button_unchecked_rounded),
        ),
        findsOneWidget);
    expect(
        find.descendant(
          of: find.byKey(const ValueKey('tipo_entrega_2')),
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget);
  });
}
