import 'dart:convert';
import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cardapio/finalizacao_carrinhos_test.dart'
    show ModuloFinalizacaoTeste;

class FilaVozTeste extends Fake implements Sincronizador {
  int envios = 0;
  String? atendimento;
  List<String> comprovantes = [];
  List<Modelowordprodutos> produtos = [];
  @override
  Future<void> guardarPedido(
      {required ContextoCarrinho contexto,
      required List<Modelowordprodutos> itens,
      required String idMesa,
      required String idComanda,
      required String idCliente,
      required List<String> impressoes,
      bool recorrentes = false}) async {
    envios++;
    atendimento = contexto.idAtendimento;
    comprovantes = impressoes;
    produtos = itens;
    await ArmazenamentoCarrinhos.instancia.limpar(contexto);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModuloFinalizacaoTeste m;
  late FilaVozTeste fila;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    m = ModuloFinalizacaoTeste();
    app.usuarioProvedor = m.usuario;
    Modular.init(m);
    fila = FilaVozTeste();
    Sincronizador.instancia = fila;
  });
  tearDown(() {
    Sincronizador.instancia = null;
    m.servidor.dispose();
    m.carrinho.dispose();
    m.recorrentes.dispose();
    m.cardapio.dispose();
    m.usuario.dispose();
    m.api.cliente.close();
    Modular.destroy();
  });

  for (final cenario in ['normal', 'outro rascunho', 'outro atendimento']) {
    testWidgets('envio automatico: $cenario', (tester) async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await m.selecionar('4');
      await m.adicionar('Coca Cola 2L', '1010');
      final esperado = m.carrinho.contexto!;
      final assinatura = jsonEncode(m
          .carrinho.itensCarrinho.listaComandosPedidos
          .map((i) => i.toMap())
          .toList());
      final servidor = (await Apis().getConexao()).servidor;
      if (cenario == 'outro rascunho') await m.adicionar('Agua', '1012');
      if (cenario == 'outro atendimento') {
        await m.selecionar('6');
        await m.adicionar('Agua', '1012');
      }
      await tester
          .pumpWidget(MaterialApp(initialRoute: 'PaginaComandas', routes: {
        '/': (_) => const SizedBox(),
        'PaginaComandas': (context) => Scaffold(
                body: TextButton(
              child: const Text('Enviar voz'),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => PaginaCarrinho(
                          contextoVoz: esperado,
                          assinaturaVoz: assinatura,
                          servidorVoz: servidor,
                          usuarioVoz: '1'))),
            )),
      }));
      await tester.tap(find.text('Enviar voz'));
      await tester.pumpAndSettle();
      if (cenario == 'normal') {
        expect(fila.envios, 1);
        expect(fila.atendimento, '104');
        expect(fila.produtos.single.id, '1010');
        expect(fila.comprovantes, isNotEmpty);
        final dados = jsonDecode(fila.comprovantes.single);
        expect(dados['comanda'], 'Comanda: 4');
        expect(dados['produtos'].single['id'], '1010');
        expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
        await tester.pump(const Duration(seconds: 1));
        expect(fila.envios, 1);
      } else {
        expect(fila.envios, 0);
        expect(find.textContaining('pedido mudou'), findsOneWidget);
        expect(m.carrinho.itensCarrinho.listaComandosPedidos, isNotEmpty);
      }
      expect(m.api.pedidos, isEmpty); // Nao contornar a fila duravel.
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
