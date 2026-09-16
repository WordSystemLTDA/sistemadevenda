import 'dart:math' as math;

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';

double valorDelivery(Object? valor) {
  var texto = (valor ?? '0').toString().trim();
  if (texto.contains(',') && texto.contains('.')) {
    texto = texto.lastIndexOf(',') > texto.lastIndexOf('.')
        ? texto.replaceAll('.', '').replaceAll(',', '.')
        : texto.replaceAll(',', '');
  } else {
    texto = texto.replaceAll(',', '.');
  }
  final numero = double.tryParse(texto) ?? 0;
  return numero.isFinite ? numero : 0;
}

class EtapaDelivery {
  final String id, nome, botao, impressao, cor;
  final bool selecionarEntregador;
  final List<PedidoDelivery> pedidos;

  EtapaDelivery.fromMap(Map<String, dynamic> map)
      : id = '${map['id']}',
        nome = '${map['nomeOpcao'] ?? ''}',
        botao = '${map['nomeBotao'] ?? 'Avançar'}',
        impressao = '${map['tipodeimpressao'] ?? '0'}',
        cor = '${map['cor'] ?? ''}',
        selecionarEntregador = map['ativarselecaoentregador'] == 'Sim',
        pedidos = [
          for (final p in (map['vendas'] as List? ?? []))
            PedidoDelivery.fromMap(Map<String, dynamic>.from(p as Map)),
        ];
}

class PedidoDelivery {
  final Map<String, dynamic> dados;
  PedidoDelivery.fromMap(Map<String, dynamic> map)
      : dados = Map.unmodifiable(map);

  String texto(String chave, [String padrao = '']) =>
      dados[chave]?.toString() ?? padrao;
  String get id => texto('id');
  String get numero =>
      texto('numeroPedido').isEmpty ? id : texto('numeroPedido');
  String get etapa => texto('idopcoescarrossel');
  String get cliente => texto('idCliente', '0');
  String get nome => texto('nomeCliente').trim().isEmpty
      ? (observacao.isEmpty ? 'Sem cliente' : observacao)
      : texto('nomeCliente');
  String get observacao => texto('observacaoDoPedido');
  String get tipoEntrega => texto('tipodeentrega', '1');
  String get nomeEntrega => switch (tipoEntrega) {
        '2' => 'Retirada',
        '3' => 'No local',
        _ => 'Entrega',
      };
  bool get encerrado =>
      ['Finalizado', 'Cancelado'].contains(texto('status')) ||
      (int.tryParse(texto('idVenda')) ?? 0) > 0;
  bool get cancelado => texto('status') == 'Cancelado';
  // A venda pode estar paga antes de o pedido entrar em preparo.
  bool podeAvancar(EtapaDelivery origem) =>
      !cancelado && origem.impressao != '3';
  double get taxaEntrega =>
      tipoEntrega == '1' ? valorDelivery(dados['valordaentrega']) : 0;
  PedidoDelivery comEndereco(Modeloworddadoscardapio cardapio) =>
      PedidoDelivery.fromMap({
        ...dados,
        'enderecoCliente': cardapio.enderecoCliente,
        'numeroCliente': cardapio.numeroCliente,
        'complementoCliente': cardapio.complementoCliente,
        'bairroCliente': cardapio.bairroCliente,
        'cidadeCliente': cardapio.cidadeCliente,
      });
  double get total => valorDelivery(dados['valorVenda']);
  double get pago => valorDelivery(dados['somaValorHistorico']);
  double get restante => math.max(0, total - pago);
  int get quantidade =>
      int.tryParse(texto('quantidadeprodutos')) ?? produtos.length;
  DateTime? get abertura => DateTime.tryParse(texto('dataAbertura'));
  String get endereco => [
        texto('enderecoCliente'),
        texto('numeroCliente'),
        texto('complementoCliente'),
        texto('bairroCliente'),
        texto('cidadeCliente'),
      ].where((v) => v.isNotEmpty && !v.startsWith('Sem ')).join(', ');
  List<Modelowordprodutos> get produtos => [
        for (final p in dados['produtos'] as List? ?? [])
          Modelowordprodutos.fromMap(Map<String, dynamic>.from(p as Map)),
      ];
  List<Map<String, dynamic>> get pagamentos => [
        for (final p in dados['lancamentos'] as List? ?? [])
          Map<String, dynamic>.from(p as Map),
      ];
}

class ConfigDelivery {
  final bool receberNoFinal, imprimirPreparo;
  final String entregadorFixo, valorEntrega, cobrancaEntrega;
  final double diferencaEntrega;
  const ConfigDelivery(
      {this.receberNoFinal = false,
      this.imprimirPreparo = true,
      this.entregadorFixo = '',
      this.valorEntrega = '0',
      this.cobrancaEntrega = '0',
      this.diferencaEntrega = 0});
  factory ConfigDelivery.fromMap(Map<String, dynamic> map) => ConfigDelivery(
        receberNoFinal: map['receberpedidonofinal'] == 'Sim',
        imprimirPreparo: map['imprimirpreparodelivery'] != 'Não',
        entregadorFixo: map['entregadorfixo']?.toString() == '1' &&
                (int.tryParse('${map['identregador']}') ?? 0) > 0
            ? '${map['identregador'] ?? ''}'
            : '',
        valorEntrega: '${map['valordaentrega'] ?? '0'}',
        cobrancaEntrega: '${map['formacobrancaentregadelivery'] ?? '0'}',
        diferencaEntrega: valorDelivery(map['valordiferenca']),
      );

  double taxaEntrega(Object? taxaBairro) => switch (cobrancaEntrega) {
        '1' => math.max(0, valorDelivery(valorEntrega) + diferencaEntrega),
        '2' => math.max(0, valorDelivery(taxaBairro) + diferencaEntrega),
        _ => 0,
      };

  bool exigePagamento(PedidoDelivery pedido, EtapaDelivery destino) =>
      pedido.restante > 0.009 && (!receberNoFinal || destino.impressao == '3');
}
