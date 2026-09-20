import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CardapioDetalhesTeste extends Fake implements ServicoCardapio {
  bool falhar = false;
  int leituras = 0;
  int fechamentos = 0;
  final List<String> consultasItens = [];
  @override
  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode}) async {
    leituras++;
    consultasItens.add(mostraritens);
    if (falhar) throw Exception('Queda de conexao');
    return Modeloworddadoscardapio(
        id: '104',
        idComanda: tipo == TipoCardapio.comanda ? '4' : '0',
        idMesa: tipo == TipoCardapio.mesa ? '4' : '0',
        status: 'Andamento',
        nome: '${tipo.nome}: 4',
        nomeCliente: 'Cliente teste',
        nomeEmpresa: 'Restaurante teste',
        dataAbertura: '2026-09-12T16:00:00',
        numeroPedido: '30',
        valorTotal: '85.00',
        produtos: mostraritens == 'Sim'
            ? [
                Modelowordprodutos(
                  id: '8',
                  nome: 'Produto teste',
                  codigo: '8',
                  estoque: '0',
                  tamanho: '',
                  foto: '',
                  ativo: 'Sim',
                  descricao: '',
                  valorVenda: '85.00',
                  categoria: '1',
                  nomeCategoria: 'Cozinha',
                  habilTipo: '',
                  ingredientes: const [],
                  quantidade: 1,
                  observacao: 'Sem cebola',
                  destinoDeImpressao: ModeloDestinoImpressao(
                    nome: '1',
                    nomeDaImpressora: 'Cozinha',
                    tamanhoDoPapel: '80',
                    nomedopc: 'computador-cozinha',
                  ),
                ),
              ]
            : null);
  }

  @override
  Future<({bool sucesso, String mensagem})> fecharAbrirComanda(
      String id, String status) async {
    fechamentos++;
    return (sucesso: false, mensagem: 'Fechamento recusado');
  }
}

class ComandasDetalhesTeste extends Fake implements ProvedorComanda {}

class MesasDetalhesTeste extends Fake implements ProvedorMesas {}

class ServidorDetalhesTeste extends Server {
  final List<String> mensagens = [];

  @override
  Future<void> enviarImpressoes(List<String> novasMensagens) async {
    mensagens.addAll(novasMensagens);
  }
}

class ModuloDetalhesTeste extends Module {
  final servico = CardapioDetalhesTeste();
  final servidor = ServidorDetalhesTeste();
  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(servico);
    i.addInstance<Server>(servidor);
    i.addInstance<ProvedorComanda>(ComandasDetalhesTeste());
    i.addInstance<ProvedorMesas>(MesasDetalhesTeste());
    i.addInstance<UsuarioProvedor>(UsuarioProvedor());
  }
}

void main() {
  late ModuloDetalhesTeste modulo;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    modulo = ModuloDetalhesTeste();
    Modular.init(modulo);
  });
  tearDown(() {
    modulo.servidor.dispose();
    Modular.destroy();
  });

  Future<void> abrir(WidgetTester tester,
      {bool fecharDireto = false,
      TipoCardapio tipo = TipoCardapio.comanda}) async {
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: PaginaDetalhesPedido(
            idComandaPedido: '104',
            tipo: tipo,
            abrirModalFecharDireto: fecharDireto)));
    await tester.pumpAndSettle();
  }

  testWidgets('falha inicial termina carregamento e permite tentar novamente',
      (tester) async {
    modulo.servico.falhar = true;
    await abrir(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Tentar novamente'), findsWidgets);
    modulo.servico.falhar = false;
    await tester.tap(find.widgetWithText(OutlinedButton, 'Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Comanda: 4'), findsOneWidget);
    expect(tester.widget<TempoAberto>(find.byType(TempoAberto)).dataAbertura,
        '2026-09-12T16:00:00');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'fechamento recusado nao tenta imprimir nem acessar dados incompletos',
      (tester) async {
    await abrir(tester, fecharDireto: true);
    await tester.tap(find.widgetWithText(FilledButton, 'Fechar'));
    await tester.pumpAndSettle();
    expect(modulo.servico.fechamentos, 1);
    expect(find.text('Fechamento recusado'), findsOneWidget);
    expect(modulo.servidor.filaImpressao.itens, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('atualizacao nao reabre confirmacao direta cancelada',
      (tester) async {
    await abrir(tester, fecharDireto: true);
    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(modulo.servico.leituras, 2);
    expect(find.byType(Dialog), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final tipo in [TipoCardapio.comanda, TipoCardapio.mesa]) {
    testWidgets(
        '${tipo.name} confirma e reimprime os itens completos do preparo',
        (tester) async {
      await abrir(tester, tipo: tipo);

      final acao = find.text('Reimprimir comprovante de preparo');
      await tester.ensureVisible(acao);
      await tester.tap(acao);
      await tester.pumpAndSettle();

      expect(
          find.text('Todos os itens atuais da ${tipo.nome.toLowerCase()} '
              'serão enviados novamente para preparo. Deseja continuar?'),
          findsOneWidget);
      expect(modulo.servidor.filaImpressao.itens, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, 'Reimprimir'));
      await tester.pumpAndSettle();

      expect(modulo.servico.consultasItens, ['Não', 'Sim']);
      expect(find.text('Reimpressão do comprovante de preparo solicitada.'),
          findsOneWidget);
      expect(modulo.servidor.mensagens, hasLength(1));
      final impressao =
          ImpressaoPendente(modulo.servidor.mensagens.single).dados;
      expect(impressao['tipo'], tipo.nome);
      expect(impressao['tipoImpressao'], '1');
      expect(impressao['comanda'], 'REIMPRESSÃO - ${tipo.nome}: 4');
      expect(impressao['numeroPedido'], '30');
      expect(impressao['nomedopc'], 'computador-cozinha');
      expect(
          (impressao['produtos'] as List).single['observacao'], 'Sem cebola');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
