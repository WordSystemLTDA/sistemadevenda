import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/conferencia_produto_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'card_carrinho_test.dart' show produtoCarrinho, DioClienteTeste;

class _ModuloConferencia extends Module {
  final ProvedorCarrinho carrinho;
  final ProvedorItensRecorrentes recorrentes;
  _ModuloConferencia(this.carrinho, this.recorrentes);

  @override
  void binds(Injector i) {
    i.addInstance<ProvedorCarrinho>(carrinho);
    i.addInstance<ProvedorItensRecorrentes>(recorrentes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);

  for (final recorrente in [false, true]) {
    group(recorrente ? 'Carrinho recorrente' : 'Carrinho do cardapio', () {
      late ProvedorCarrinho carrinho;
      late ProvedorItensRecorrentes recorrentes;
      late UsuarioProvedor usuario;
      final armazenamento = ArmazenamentoCarrinhos.instancia;

      Future<void> abrir([String atendimento = '104']) async {
        await carrinho.selecionarAtendimento(
            tipo: 'comanda', idAtendimento: atendimento, idRecurso: '4');
        recorrentes.selecionarAtendimento(
            idAtendimento: atendimento, tipo: 'comanda', idRecurso: '4');
        await recorrentes.listarComandasPedidos(atendimento);
      }

      List<Modelowordprodutos> itens() => recorrente
          ? recorrentes.itensCarrinho
          : carrinho.itensCarrinho.listaComandosPedidos;

      Future<void> atualizar() => recorrente
          ? recorrentes.listarComandasPedidos('104')
          : carrinho.listarComandasPedidos();

      Future<bool> conferir(int index, bool valor) => recorrente
          ? recorrentes.definirConferencia(itens()[index], index, valor)
          : carrinho.definirConferencia(itens()[index], index, valor);

      Future<void> adicionar() async {
        final produto = produtoCarrinho();
        if (recorrente) {
          await recorrentes.inserir('104', produto);
        } else {
          await carrinho.inserir(produto, 'Comanda', '0', '4', '10', '',
              produto.id, produto.nome, produto.quantidade, '');
        }
        await atualizar();
      }

      Future<void> alterarQuantidade() async {
        if (recorrente) {
          await recorrentes.setarItemCarrinho('104', 0, 2);
        } else {
          final item = Modelowordprodutos.fromMap(itens().first.toMap())
            ..quantidade = 2;
          await carrinho.editar(item, 0);
        }
        await atualizar();
      }

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        usuario = UsuarioProvedor()
          ..setUsuario(UsuarioModelo(empresa: '32', id: '1'));
        final servico = ServicosItensComanda(DioClienteTeste(), usuario);
        carrinho = ProvedorCarrinho(servico);
        recorrentes = ProvedorItensRecorrentes(servico);
        Modular.init(_ModuloConferencia(carrinho, recorrentes));
        await abrir();
        await adicionar();
      });

      tearDown(() {
        Modular.destroy();
        carrinho.dispose();
        recorrentes.dispose();
        usuario.dispose();
      });

      test('conferencia individual persiste ao voltar e reler armazenamento',
          () async {
        await adicionar();
        expect(await conferir(0, true), isTrue);
        expect(itens().map((i) => i.conferidoNoCarrinho), [true, false]);
        await abrir('106');
        expect(itens(), isEmpty);
        await abrir();
        final restaurados = await ArmazenamentoCarrinhos()
            .listar(carrinho.contexto!, recorrentes: recorrente);
        expect(restaurados.map((i) => i.conferidoNoCarrinho), [true, false]);
        expect(restaurados.first.valorVenda, '10');
        expect(restaurados.first.quantidade, 1);
        expect(await conferir(0, false), isTrue);
        expect(itens().every((i) => !i.conferidoNoCarrinho), isTrue);
      });

      test('alterar quantidade e observacao exige nova conferencia', () async {
        await conferir(0, true);
        await alterarQuantidade();
        expect(itens().first.conferidoNoCarrinho, isFalse);
        expect(itens().first.quantidade, 2);
        await conferir(0, true);
        final editado = Modelowordprodutos.fromMap(itens().first.toMap())
          ..observacao = 'Sem gelo';
        if (recorrente) {
          await recorrentes.editar('104', editado, 0);
        } else {
          await carrinho.editar(editado, 0);
        }
        await atualizar();
        expect(itens().first.conferidoNoCarrinho, isFalse);
        expect(itens().first.observacao, 'Sem gelo');
      });

      test('salvar montagem editada retira conferencia somente do item editado',
          () async {
        await adicionar();
        await conferir(0, true);
        await conferir(1, true);
        final original = itens().first;
        final editado = Modelowordprodutos.fromMap(original.toMap())
          ..tamanho = 'P'
          ..opcoesPacotesListaFinal = [
            ModeloOpcoesPacotes(
              id: 10,
              titulo: 'Sabores Pizza',
              obrigatorio: false,
              dados: [ModeloDadosOpcoesPacotes(id: '3', nome: 'Dois Queijos')],
            ),
          ];
        final salvo = recorrente
            ? await recorrentes.editar('104', editado, 0, original: original)
            : await carrinho.editar(editado, 0, original: original);
        expect(salvo, isTrue);
        await atualizar();
        expect(itens().map((i) => i.conferidoNoCarrinho), [false, true]);
      });

      test('nao confere versao antiga nem muda o outro carrinho', () async {
        final original = itens().first;
        await alterarQuantidade();
        await expectLater(
          armazenamento.definirConferencia(
              carrinho.contexto!, 0, original, true,
              recorrentes: recorrente),
          throwsStateError,
        );
        await armazenamento.alterar(
            carrinho.contexto!, (itens) => itens.add(produtoCarrinho()),
            recorrentes: !recorrente);
        await conferir(0, true);
        final outro = await armazenamento.listar(carrinho.contexto!,
            recorrentes: !recorrente);
        expect(outro.single.conferidoNoCarrinho, isFalse);
      });

      for (final (largura, escala) in [
        (390.0, 1.0),
        (320.0, 1.0),
        (800.0, 1.0),
        (320.0, 2.0),
      ]) {
        testWidgets(
            'confere e desmarca sem overflow em $largura escala $escala',
            (tester) async {
          tester.view.physicalSize = Size(largura, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('captura'),
              child: Scaffold(
                appBar: AppBar(title: const Text('Carrinho')),
                body: AnimatedBuilder(
                  animation: recorrente ? recorrentes : carrinho,
                  builder: (context, _) => ListView(
                    padding: const EdgeInsets.all(10),
                    children: [
                      if (recorrente)
                        CardCarrinhoItensRecorrentes(
                          item: itens().first,
                          index: 0,
                          idComanda: '4',
                          idComandaPedido: '104',
                          idMesa: '0',
                          value: '',
                          setarQuantidade: (_) async {},
                        )
                      else
                        CardCarrinho(
                          item: itens().first,
                          index: 0,
                          idComanda: '4',
                          idMesa: '0',
                          value: '',
                          setarQuantidade: (_) async => true,
                          aoExcluirItem: () {},
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ));
          await tester.pumpAndSettle();
          final corInicial = tester.widget<Card>(find.byType(Card).first).color;
          await tester.ensureVisible(find.text('Conferir'));
          await tester.tap(find.text('Conferir'));
          await tester.pumpAndSettle();
          expect(find.text('Conferido'), findsOneWidget);
          expect(itens().first.conferidoNoCarrinho, isTrue);
          expect(tester.widget<Card>(find.byType(Card).first).color,
              isNot(corInicial));
          await capturarTela(
              tester, 'conferencia_${recorrente}_${largura}_$escala');
          await tester.tap(find.text('Conferido'));
          await tester.pumpAndSettle();
          expect(itens().first.conferidoNoCarrinho, isFalse);
          expect(
              tester.widget<Card>(find.byType(Card).first).color, corInicial);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    });
  }

  testWidgets('falha ao salvar permite tentar conferir novamente',
      (tester) async {
    var tentativas = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AcoesProdutoCarrinho(
          item: produtoCarrinho(),
          index: 0,
          aoConferir: (_) async {
            tentativas++;
            return false;
          },
        ),
      ),
    ));
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    expect(find.text('Conferido'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    expect(tentativas, 2);
  });
}
