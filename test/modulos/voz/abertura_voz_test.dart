import 'dart:async';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/voz/abertura_falada.dart';
import 'package:app/src/modulos/voz/pedido_falado.dart';
import 'package:app/src/modulos/voz/servico_abertura_voz.dart';
import 'package:app/src/modulos/voz/servico_pedido_voz.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> comandoAbertura(
        {String tipo = 'comanda',
        String numero = '3',
        String mesa = '',
        String cliente = '',
        String obs = 'Bruno Masson'}) =>
    {
      'acao': 'abrir',
      'tipo': tipo,
      'numero': numero,
      'mesa_vinculada': mesa,
      'observacao': obs,
      'cliente_cadastrado': cliente,
      'esclarecimento': '',
    };

class ComandasAberturaTeste extends Fake implements ServicoComandas {
  final itens = [
    ModeloComanda(
        id: '903',
        nome: 'Comanda: 3',
        codigo: 'outra-tag',
        ativo: 'Sim',
        comandaOcupada: false)
  ];
  Completer<void>? aguardar;
  @override
  Future<List<ModeloComandas>> listar(String pesquisa) async {
    await aguardar?.future;
    return [ModeloComandas(titulo: 'Livres', comandas: itens)];
  }
}

class MesasAberturaTeste extends Fake implements ServicoMesas {
  final itens = [
    for (final n in [2, 3])
      MesaModelo(
          id: '80$n',
          nome: 'Mesa: $n',
          codigo: 'tag$n',
          ativo: 'Sim',
          mesaOcupada: false,
          nomeCliente: null,
          dataAbertura: null,
          horaAbertura: null)
  ];
  @override
  Future<List<MesasModel>> listar(String pesquisa) async => [
        MesasModel(titulo: 'Livres', mesas: itens),
      ];
}

class ClientesVozTeste extends Fake implements ServicoPedidoVoz {
  final nomes = <String>[];
  bool ambiguo = false;
  @override
  Future<String> localizarClienteCadastrado(String nome) async {
    nomes.add(nome);
    if (ambiguo) throw const FalhaPedidoVoz('Clientes com o mesmo nome.');
    return '700';
  }
}

class SyncAberturaVozTeste extends Fake implements Sincronizador {
  bool habilitado = true;
  bool conflito = false;
  final aberturas = <Map<String, String>>[];
  @override
  Future<bool> prepararAberturasOffline() async => habilitado;
  @override
  Future<String> abrirAtendimento(
      {required String tipo,
      String idMesa = '0',
      String idComanda = '0',
      String idCliente = '0',
      String obs = ''}) async {
    if (conflito) throw StateError('Atendimento reutilizado.');
    aberturas.add({
      'tipo': tipo,
      'mesa': idMesa,
      'comanda': idComanda,
      'cliente': idCliente,
      'obs': obs
    });
    return 'local:abertura-teste';
  }
}

void main() {
  final falha = throwsA(isA<FalhaPedidoVoz>());
  late ComandasAberturaTeste comandas;
  late MesasAberturaTeste mesas;
  late ClientesVozTeste clientes;
  late SyncAberturaVozTeste sync;
  late ServicoAberturaVoz servico;
  bool sessaoValida = true;
  setUp(() {
    comandas = ComandasAberturaTeste();
    mesas = MesasAberturaTeste();
    clientes = ClientesVozTeste();
    sync = SyncAberturaVozTeste();
    sessaoValida = true;
    servico = ServicoAberturaVoz(
        comandas: comandas,
        mesas: mesas,
        sincronizador: sync,
        voz: clientes,
        validarSessao: () async {
          if (!sessaoValida) throw const FalhaPedidoVoz('A conta mudou.');
        });
  });

  for (final tipo in TipoAberturaVoz.values) {
    test('abrir ${tipo.name} 3 com nome salva observacao, sem buscar cliente',
        () async {
      final abertura =
          AberturaFalada.fromMap(comandoAbertura(tipo: tipo.name), tipo);
      expect(await servico.abrir(abertura), 'local:abertura-teste');
      expect(sync.aberturas.single, {
        'tipo': tipo.name,
        'mesa': tipo == TipoAberturaVoz.mesa ? '803' : '0',
        'comanda': tipo == TipoAberturaVoz.comanda ? '903' : '0',
        'cliente': '0',
        'obs': 'Bruno Masson'
      });
      expect(clientes.nomes, isEmpty);
    });
    test('selecionar cliente explicitamente em ${tipo.name}', () async {
      final abertura = AberturaFalada.fromMap(
          comandoAbertura(tipo: tipo.name, cliente: 'Bruno Masson', obs: ''),
          tipo);
      await servico.abrir(abertura);
      expect(clientes.nomes, ['Bruno Masson']);
      expect(sync.aberturas.single['cliente'], '700');
      expect(sync.aberturas.single['obs'], '');
    });
  }
  test('comanda 3 vincula mesa 2 pelos numeros exibidos, nao pelos IDs',
      () async {
    await servico.abrir(AberturaFalada.fromMap(
        comandoAbertura(mesa: '2'), TipoAberturaVoz.comanda));
    expect(sync.aberturas.single['mesa'], '802');
    expect(sync.aberturas.single['comanda'], '903');
    expect(sync.aberturas.single['obs'], 'Bruno Masson');
  });
  for (final nome in ['3', '003', 'Comanda 3', 'COMANDA: 03']) {
    test('numero exato $nome nao confunde 3 e 30', () {
      expect(
          encontrarNumeroAtendimento(
              ['Comanda 30', nome], '3', TipoAberturaVoz.comanda, (s) => s),
          nome);
    });
  }
  test('numero inexistente ou duplicado nao escolhe o primeiro', () {
    expect(
        () => encontrarNumeroAtendimento(
            ['30'], '3', TipoAberturaVoz.comanda, (s) => s),
        falha);
    expect(
        () => encontrarNumeroAtendimento(
            ['3', '03'], '3', TipoAberturaVoz.comanda, (s) => s),
        falha);
  });
  for (final alteracao in <Map<String, dynamic>>[
    {'numero': ''},
    {'numero': '-1'},
    {'numero': '3 e 4'},
    {'numero': '3.5'},
    {'numero': 3},
    {'acao': 'fechar'},
    {'tipo': 'mesa'},
    {'observacao': null},
    {'esclarecimento': 'Informe o numero.'},
    {'mesa_vinculada': 'zero'},
  ]) {
    test('rejeita comando incompleto ou incorreto $alteracao', () {
      expect(
          () => AberturaFalada.fromMap(
              {...comandoAbertura(), ...alteracao}, TipoAberturaVoz.comanda),
          falha);
    });
  }
  test('mesa nunca vincula outra mesa', () {
    expect(
        () => AberturaFalada.fromMap(
            comandoAbertura(tipo: 'mesa', mesa: '2'), TipoAberturaVoz.mesa),
        falha);
  });
  for (final situacao in ['ocupada', 'inativa', 'fechamento']) {
    test('comanda $situacao nao recebe abertura', () async {
      if (situacao == 'ocupada') comandas.itens.single.comandaOcupada = true;
      if (situacao == 'inativa') comandas.itens.single.ativo = 'Nao';
      if (situacao == 'fechamento') comandas.itens.single.fechamento = true;
      await expectLater(
          servico.abrir(AberturaFalada.fromMap(
              comandoAbertura(), TipoAberturaVoz.comanda)),
          falha);
      expect(sync.aberturas, isEmpty);
    });
  }
  test('mesa vinculada indisponivel nao abre comanda parcialmente', () async {
    mesas.itens.first.ativo = 'Nao';
    await expectLater(
        servico.abrir(AberturaFalada.fromMap(
            comandoAbertura(mesa: '2'), TipoAberturaVoz.comanda)),
        falha);
    expect(sync.aberturas, isEmpty);
  });
  test('cliente ambiguo nao vira observacao nem abre sem cliente', () async {
    clientes.ambiguo = true;
    await expectLater(
        servico.abrir(AberturaFalada.fromMap(
            comandoAbertura(cliente: 'Bruno Masson', obs: ''),
            TipoAberturaVoz.comanda)),
        falha);
    expect(sync.aberturas, isEmpty);
  });
  test('servidor antigo bloqueia abertura automatica sem fallback legado',
      () async {
    sync.habilitado = false;
    await expectLater(
        servico.abrir(
            AberturaFalada.fromMap(comandoAbertura(), TipoAberturaVoz.comanda)),
        falha);
    expect(sync.aberturas, isEmpty);
  });
  test('troca de conta durante consulta nao gera abertura', () async {
    comandas.aguardar = Completer<void>();
    final envio = servico.abrir(
        AberturaFalada.fromMap(comandoAbertura(), TipoAberturaVoz.comanda));
    final expectativa = expectLater(envio, falha);
    await Future<void>.delayed(Duration.zero);
    sessaoValida = false;
    comandas.aguardar!.complete();
    await expectativa;
    expect(sync.aberturas, isEmpty);
  });
  test('conflito de versao nao edita nem tenta abrir de outra maneira',
      () async {
    sync.conflito = true;
    await expectLater(
        servico.abrir(
            AberturaFalada.fromMap(comandoAbertura(), TipoAberturaVoz.comanda)),
        throwsStateError);
    expect(sync.aberturas, isEmpty);
  });
  test('duas conclusoes do mesmo comando abrem apenas uma vez', () async {
    final abertura =
        AberturaFalada.fromMap(comandoAbertura(), TipoAberturaVoz.comanda);
    final envio = servico.abrir(abertura);
    await expectLater(servico.abrir(abertura), falha);
    await envio;
    expect(sync.aberturas, hasLength(1));
  });
}
