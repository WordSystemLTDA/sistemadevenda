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

bool valorDeliverySim(Object? valor) =>
    {'sim', '1', 'true'}.contains(valor?.toString().trim().toLowerCase());

bool celularDeliveryValido(Object? celular) {
  final tamanho = celular?.toString().replaceAll(RegExp(r'\D'), '').length ?? 0;
  return tamanho >= 10 && tamanho <= 15;
}

({DateTime inicio, DateTime fim}) periodoOperacionalDelivery({
  required DateTime inicio,
  required DateTime fim,
  required String horaInicio,
  required String horaFim,
  DateTime? agora,
}) {
  DateTime horario(DateTime dia, String valor) {
    final partes = valor.split(':');
    int parte(int indice) =>
        partes.length > indice ? int.tryParse(partes[indice]) ?? 0 : 0;
    return DateTime(dia.year, dia.month, dia.day, parte(0), parte(1), parte(2));
  }

  final atual = agora ?? DateTime.now();
  final antesDoInicio = !atual.isAfter(horario(atual, horaInicio));
  return (
    inicio: horario(
        DateTime(
            inicio.year, inicio.month, inicio.day - (antesDoInicio ? 1 : 0)),
        horaInicio),
    fim: horario(
        DateTime(fim.year, fim.month, fim.day + (antesDoInicio ? 0 : 1)),
        horaFim),
  );
}

bool _pedidoOperacional(dynamic pedido) {
  if (pedido is! Map) return true;
  final status = (pedido['status'] ?? '').toString().trim().toLowerCase();
  return !{'modelo recorrente', 'rascunho aplicativo'}.contains(status);
}

class EtapaDelivery {
  final String id, nome, botao, impressao, cor;
  final bool selecionarEntregador;
  final List<PedidoDelivery> pedidos;

  EtapaDelivery._(
      {required this.id,
      required this.nome,
      required this.botao,
      required this.impressao,
      required this.cor,
      required this.selecionarEntregador,
      required this.pedidos});

  factory EtapaDelivery.comPedidos(
          EtapaDelivery etapa, List<PedidoDelivery> pedidos) =>
      EtapaDelivery._(
          id: etapa.id,
          nome: etapa.nome,
          botao: etapa.botao,
          impressao: etapa.impressao,
          cor: etapa.cor,
          selecionarEntregador: etapa.selecionarEntregador,
          pedidos: pedidos);

  EtapaDelivery.fromMap(Map<String, dynamic> map)
      : id = '${map['id']}',
        nome = '${map['nomeOpcao'] ?? ''}',
        botao = '${map['nomeBotao'] ?? 'Avançar'}',
        impressao = '${map['tipodeimpressao'] ?? '0'}',
        cor = '${map['cor'] ?? ''}',
        selecionarEntregador = valorDeliverySim(map['ativarselecaoentregador']),
        pedidos = [
          for (final p in (map['vendas'] as List? ?? []))
            if (_pedidoOperacional(p))
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
  bool get salvoNoAparelho => id.startsWith('delivery-local:');
  bool get aguardandoSincronizacao =>
      salvoNoAparelho && texto('faseLocal') == 'enfileirado';
  bool get produtosConfirmadosLocal =>
      dados['produtosConfirmadosLocal'] == true;
  bool get possuiRascunhoLocal => dados['possuiRascunhoLocal'] == true;
  String get numero =>
      texto('numeroPedido').isEmpty ? id : texto('numeroPedido');
  String get etapa => texto('idopcoescarrossel');
  String get cliente => texto('idCliente', '0');
  bool get possuiCelularCliente =>
      celularDeliveryValido(dados['celularCliente']);
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
  bool? get recorrenteVinculado {
    final valor = dados['recorrenteVinculado'] ?? dados['recorrente_vinculado'];
    if (valor == null) return null;
    if (valor is bool) return valor;
    return ['sim', 'true', '1'].contains(valor.toString().trim().toLowerCase());
  }

  bool get cancelado => texto('status') == 'Cancelado';
  // A venda pode estar paga antes de o pedido entrar em preparo.
  bool podeAvancar(EtapaDelivery origem) =>
      !cancelado && origem.impressao != '3';
  double get taxaEntrega =>
      tipoEntrega == '1' ? valorDelivery(dados['valordaentrega']) : 0;

  bool get _temEnderecoDoPedido {
    final enderecoPedido = texto('enderecoCliente').trim();
    return enderecoPedido.isNotEmpty &&
        !enderecoPedido.toLowerCase().startsWith('sem ');
  }

  String _campoEndereco(String chave, Object? alternativa) =>
      _temEnderecoDoPedido
          ? texto(chave).trim()
          : alternativa?.toString().trim() ?? '';

  PedidoDelivery comEndereco(Modeloworddadoscardapio cardapio) =>
      PedidoDelivery.fromMap({
        ...dados,
        // O pedido guarda o endereco escolhido para esta entrega. Os dados do
        // cardapio sao apenas fallback para respostas antigas da API.
        'enderecoCliente':
            _campoEndereco('enderecoCliente', cardapio.enderecoCliente),
        'numeroCliente':
            _campoEndereco('numeroCliente', cardapio.numeroCliente),
        'complementoCliente':
            _campoEndereco('complementoCliente', cardapio.complementoCliente),
        'bairroCliente':
            _campoEndereco('bairroCliente', cardapio.bairroCliente),
        'cidadeCliente':
            _campoEndereco('cidadeCliente', cardapio.cidadeCliente),
      });
  PedidoDelivery comEtapa(String etapa) =>
      PedidoDelivery.fromMap({...dados, 'idopcoescarrossel': etapa});
  PedidoDelivery comEntrega({
    required String tipo,
    required String endereco,
    required double taxa,
    Map<String, dynamic>? dadosEndereco,
  }) {
    final entrega = tipo == '1';
    final novaTaxa = entrega ? taxa : 0.0;
    final novoTotal = math.max(0.0, total - taxaEntrega + novaTaxa);
    return PedidoDelivery.fromMap({
      ...dados,
      'tipodeentrega': tipo,
      'idendereco': entrega ? endereco : '0',
      'valordaentrega': novaTaxa.toStringAsFixed(2),
      'valorentrega': novaTaxa.toStringAsFixed(2),
      'valorVenda': novoTotal.toStringAsFixed(2),
      'valorTotal': novoTotal.toStringAsFixed(2),
      if (entrega && dadosEndereco != null) ...{
        'enderecoCliente': dadosEndereco['endereco']?.toString() ?? '',
        'numeroCliente': dadosEndereco['numero']?.toString() ?? '',
        'complementoCliente': dadosEndereco['complemento']?.toString() ?? '',
        'bairroCliente': dadosEndereco['bairro']?.toString() ?? '',
        'cidadeCliente': dadosEndereco['cidade']?.toString() ?? '',
      },
    });
  }

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
  bool get possuiPagamentoRegistrado =>
      pago > 0.009 ||
      pagamentos.any((pagamento) => valorDelivery(pagamento['valor']) > 0.009);
}

class ConfigDelivery {
  final bool receberNoFinal,
      imprimirPreparo,
      imprimirPreparoNoComprovanteConsumacao,
      motivoCancelamentoObrigatorio;
  final String entregadorFixo, valorEntrega, cobrancaEntrega;
  final String numerodopedidodestaquecomprovante;
  final String numerodopedidodestaquepreparo;
  final String ativarnumerooperacionalpedido;
  final String imprimirnumerooperacionalentregador;
  final String imprimirnumerooperacionalconsumacao;
  final String imprimirnumerooperacionalpreparo;
  final String ativarCardapioDigital;
  final double diferencaEntrega;
  const ConfigDelivery(
      {this.receberNoFinal = false,
      this.imprimirPreparo = true,
      this.imprimirPreparoNoComprovanteConsumacao = false,
      this.motivoCancelamentoObrigatorio = false,
      this.entregadorFixo = '',
      this.valorEntrega = '0',
      this.cobrancaEntrega = '0',
      this.numerodopedidodestaquecomprovante = 'Não',
      this.numerodopedidodestaquepreparo = 'Não',
      this.ativarnumerooperacionalpedido = '',
      this.imprimirnumerooperacionalentregador = '',
      this.imprimirnumerooperacionalconsumacao = '',
      this.imprimirnumerooperacionalpreparo = '',
      this.ativarCardapioDigital = '',
      this.diferencaEntrega = 0});
  factory ConfigDelivery.fromMap(Map<String, dynamic> map) => ConfigDelivery(
        receberNoFinal: map['receberpedidonofinal'] == 'Sim',
        imprimirPreparo: map['imprimirpreparodelivery'] != 'Não',
        imprimirPreparoNoComprovanteConsumacao:
            map['imprimirpreparocomprovanteconsumacao'] == 'Sim' ||
                map['imprimir_preparo_comprovante_consumacao'] == 'Sim',
        motivoCancelamentoObrigatorio: map['obrigarjustifcancelarpedido']
                ?.toString()
                .trim()
                .toLowerCase() ==
            'sim',
        entregadorFixo: map['entregadorfixo']?.toString() == '1' &&
                (int.tryParse('${map['identregador']}') ?? 0) > 0
            ? '${map['identregador'] ?? ''}'
            : '',
        valorEntrega: '${map['valordaentrega'] ?? '0'}',
        cobrancaEntrega: '${map['formacobrancaentregadelivery'] ?? '0'}',
        numerodopedidodestaquecomprovante:
            '${map['numerodopedidodestaquecomprovante'] ?? 'Não'}',
        numerodopedidodestaquepreparo:
            '${map['numerodopedidodestaquepreparo'] ?? 'Não'}',
        ativarnumerooperacionalpedido:
            '${map['ativarnumerooperacionalpedido'] ?? ''}',
        imprimirnumerooperacionalentregador:
            '${map['imprimirnumerooperacionalentregador'] ?? ''}',
        imprimirnumerooperacionalconsumacao:
            '${map['imprimirnumerooperacionalconsumacao'] ?? ''}',
        imprimirnumerooperacionalpreparo:
            '${map['imprimirnumerooperacionalpreparo'] ?? ''}',
        ativarCardapioDigital:
            '${map['ativarcardapiodigital'] ?? map['ativar_cardapio_digital'] ?? ''}',
        diferencaEntrega: valorDelivery(map['valordiferenca']),
      );

  bool get cardapioDigitalAlmocoHabilitado {
    final valor = ativarCardapioDigital.trim().toLowerCase();
    return valor == 'almoço' || valor == 'almoco';
  }

  double taxaEntrega(Object? taxaBairro) => switch (cobrancaEntrega) {
        '1' => math.max(0, valorDelivery(valorEntrega) + diferencaEntrega),
        '2' => math.max(0, valorDelivery(taxaBairro) + diferencaEntrega),
        _ => 0,
      };

  bool exigePagamento(PedidoDelivery pedido, EtapaDelivery destino) =>
      pedido.restante > 0.009 && (!receberNoFinal || destino.impressao == '3');

  bool get controlaNumeroOperacionalPedido =>
      ativarnumerooperacionalpedido.trim().isNotEmpty ||
      imprimirnumerooperacionalentregador.trim().isNotEmpty ||
      imprimirnumerooperacionalconsumacao.trim().isNotEmpty ||
      imprimirnumerooperacionalpreparo.trim().isNotEmpty;

  bool get _numeroOperacionalAtivo =>
      ativarnumerooperacionalpedido.trim().isEmpty ||
      ativarnumerooperacionalpedido == 'Sim';

  bool _permiteNumeroOperacional(String valor) =>
      !controlaNumeroOperacionalPedido ||
      (_numeroOperacionalAtivo && (valor.trim().isEmpty || valor == 'Sim'));

  bool get imprimeNumeroOperacionalPreparo =>
      _permiteNumeroOperacional(imprimirnumerooperacionalpreparo);
  bool get imprimirPreparoSeparado =>
      imprimirPreparo && !imprimirPreparoNoComprovanteConsumacao;
  bool get imprimeNumeroOperacionalEntregador =>
      _permiteNumeroOperacional(imprimirnumerooperacionalentregador);
  bool get imprimeNumeroOperacionalConsumacao =>
      _permiteNumeroOperacional(imprimirnumerooperacionalconsumacao);
}
