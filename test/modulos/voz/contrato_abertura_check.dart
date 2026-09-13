import 'dart:io';
import 'package:app/src/modulos/voz/abertura_falada.dart';
import 'package:app/src/modulos/voz/falha_pedido_voz.dart';

// Pode rodar sem Flutter/SDK de plataforma; as entradas simulam a resposta da IA.
void main() {
  int verificacoes = 0;
  void conferir(bool condicao, String nome) {
    if (!condicao) throw StateError(nome);
    verificacoes++;
  }

  void rejeitar(void Function() acao, String nome) {
    try {
      acao();
    } on FalhaPedidoVoz {
      verificacoes++;
      return;
    }
    throw StateError('Nao rejeitou: $nome');
  }

  final base = <String, dynamic>{
    'acao': 'abrir',
    'tipo': 'comanda',
    'numero': '3',
    'mesa_vinculada': '',
    'observacao': 'Bruno Masson',
    'cliente_cadastrado': '',
    'esclarecimento': '',
  };
  for (final tipo in TipoAberturaVoz.values) {
    final abertura = AberturaFalada.fromMap({...base, 'tipo': tipo.name}, tipo);
    conferir(abertura.tipo == tipo && abertura.numero == '3', 'numero e tipo');
    conferir(abertura.observacao == 'Bruno Masson', 'nome na observacao');
    conferir(abertura.clienteCadastrado.isEmpty, 'nome nao e ID de cliente');
    conferir(abertura.mesaVinculada.isEmpty, 'nao inventar vinculo');
  }
  final vinculada = AberturaFalada.fromMap(
      {...base, 'mesa_vinculada': '2'}, TipoAberturaVoz.comanda);
  conferir(
      vinculada.mesaVinculada == '2' && vinculada.observacao == 'Bruno Masson',
      'comanda com mesa');
  final cliente = AberturaFalada.fromMap(
      {...base, 'observacao': '', 'cliente_cadastrado': 'Bruno Masson'},
      TipoAberturaVoz.comanda);
  conferir(
      cliente.clienteCadastrado == 'Bruno Masson' && cliente.observacao.isEmpty,
      'cadastro explicito');
  for (final alteracao in <Map<String, dynamic>>[
    {'numero': ''},
    {'numero': 3},
    {'numero': '-3'},
    {'numero': '0'},
    {'numero': '3.5'},
    {'numero': '3 e 4'},
    {'numero': '1234567890'},
    {'acao': 'fechar'},
    {'tipo': 'mesa'},
    {'observacao': null},
    {'cliente_cadastrado': null},
    {'mesa_vinculada': '-2'},
    {'esclarecimento': 'Qual numero?'},
    {'observacao': 'a' * 101},
  ]) {
    rejeitar(
        () => AberturaFalada.fromMap(
            {...base, ...alteracao}, TipoAberturaVoz.comanda),
        '$alteracao');
  }
  rejeitar(
      () => AberturaFalada.fromMap(
          {...base, 'tipo': 'mesa', 'mesa_vinculada': '2'},
          TipoAberturaVoz.mesa),
      'mesa vinculada a outra mesa');
  for (final nome in ['3', '003', 'Comanda 3', 'COMANDA: 03']) {
    conferir(
        encontrarNumeroAtendimento(
                ['Comanda 30', nome], '3', TipoAberturaVoz.comanda, (s) => s) ==
            nome,
        'numero visivel $nome');
  }
  rejeitar(
      () => encontrarNumeroAtendimento<String>(
          ['Comanda 30'], '3', TipoAberturaVoz.comanda, (s) => s),
      'sem correspondencia parcial');
  rejeitar(
      () => encontrarNumeroAtendimento<String>(
          ['3', 'Comanda 03'], '3', TipoAberturaVoz.comanda, (s) => s),
      'numeros duplicados');
  rejeitar(
      () => encontrarNumeroAtendimento<String>(
          ['Mesa 3'], '3', TipoAberturaVoz.comanda, (s) => s),
      'tipo diferente');
  stdout.writeln(
      '$verificacoes verificacoes Dart passaram; sem microfone, IA ou aberturas reais.');
}
