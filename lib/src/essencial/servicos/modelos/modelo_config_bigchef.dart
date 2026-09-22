// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

String _texto(Map<String, dynamic> map, String chave, [String padrao = '']) =>
    map[chave]?.toString() ?? padrao;

String _textoConfig(Map<String, dynamic> map, String chave, String coluna) =>
    (map[chave] ?? map[coluna])?.toString() ?? 'Não';

bool _sim(String valor) => valor.trim().toLowerCase() == 'sim';

class ModeloConfigBigchef {
  final String clientecompedidosdecorrentes;
  final String tempoparaenviodecorrente;
  bool get recorrentesHabilitados =>
      clientecompedidosdecorrentes.trim().toLowerCase() == 'sim';
  final String balcaorapido;
  bool get balcaoRapidoHabilitado => _sim(balcaorapido);
  final String abrircomandadireto;
  final String abrirmesadireto;
  final String agrupamentodeitenscomanda;
  final String agrupamentodeitensmesa;
  final String agrupamentodeitensbalcao;
  final String agrupamentodeitensdelivery;
  final String obrigarjustifcancelarpedido;
  final String mostrarnomeempresapreparo;
  final String mostrarnomeclientepreparo;
  final String tamanhofontepreparoaltura;
  final String tamanhofontepreparolargura;
  final String formacobrancaentregadelivery;
  final String valordaentrega;
  final String valorembalagemseparada;
  final String agrupamentodeitenscomprovconsumo;
  final String agrupamentodeitenscomproventregador;
  final String valordiferenca;
  final String saborlimitedeborda;
  final String autenticarcomtag;
  final String numerodopedidodestaquecomprovante;
  final String numerodopedidodestaquepreparo;
  final String ativarnumerooperacionalpedido;
  final String imprimirnumerooperacionalentregador;
  final String imprimirnumerooperacionalconsumacao;
  final String imprimirnumerooperacionalpreparo;
  final String imprimirpreparocomprovanteconsumacao;
  final String? modeloValorAdicionalPizza;
  final String permitireditarquantidadeappaposfinalizar;
  final String permitireditarobservacaoappaposfinalizar;
  final String permitireditarsaborpizzaappaposfinalizar;
  final String permitireditarbordaappaposfinalizar;
  final String permitireditaradicionalappaposfinalizar;
  final String permitirfinalizarmesa;
  final String permitirfinalizarcomanda;

  ModeloConfigBigchef({
    this.clientecompedidosdecorrentes = 'Não',
    this.tempoparaenviodecorrente = '20',
    this.balcaorapido = 'Não',
    required this.abrircomandadireto,
    required this.abrirmesadireto,
    required this.agrupamentodeitenscomanda,
    required this.agrupamentodeitensmesa,
    required this.agrupamentodeitensbalcao,
    required this.agrupamentodeitensdelivery,
    required this.obrigarjustifcancelarpedido,
    required this.mostrarnomeempresapreparo,
    required this.mostrarnomeclientepreparo,
    required this.tamanhofontepreparoaltura,
    required this.tamanhofontepreparolargura,
    required this.formacobrancaentregadelivery,
    required this.valordaentrega,
    this.valorembalagemseparada = '0.00',
    required this.agrupamentodeitenscomprovconsumo,
    required this.agrupamentodeitenscomproventregador,
    required this.valordiferenca,
    required this.saborlimitedeborda,
    required this.autenticarcomtag,
    this.numerodopedidodestaquecomprovante = 'Não',
    this.numerodopedidodestaquepreparo = 'Não',
    this.ativarnumerooperacionalpedido = '',
    this.imprimirnumerooperacionalentregador = '',
    this.imprimirnumerooperacionalconsumacao = '',
    this.imprimirnumerooperacionalpreparo = '',
    this.imprimirpreparocomprovanteconsumacao = 'Não',
    this.modeloValorAdicionalPizza,
    this.permitireditarquantidadeappaposfinalizar = 'Não',
    this.permitireditarobservacaoappaposfinalizar = 'Não',
    this.permitireditarsaborpizzaappaposfinalizar = 'Não',
    this.permitireditarbordaappaposfinalizar = 'Não',
    this.permitireditaradicionalappaposfinalizar = 'Não',
    this.permitirfinalizarmesa = 'Não',
    this.permitirfinalizarcomanda = 'Não',
  });

  bool get permiteEditarQuantidadeAposFinalizar =>
      _sim(permitireditarquantidadeappaposfinalizar);
  bool get permiteEditarObservacaoAposFinalizar =>
      _sim(permitireditarobservacaoappaposfinalizar);
  bool get permiteEditarSaborPizzaAposFinalizar =>
      _sim(permitireditarsaborpizzaappaposfinalizar);
  bool get permiteEditarBordaAposFinalizar =>
      _sim(permitireditarbordaappaposfinalizar);
  bool get permiteEditarAdicionalAposFinalizar =>
      _sim(permitireditaradicionalappaposfinalizar);
  bool get permiteFinalizarMesa => _sim(permitirfinalizarmesa);
  bool get permiteFinalizarComanda => _sim(permitirfinalizarcomanda);
  bool get controlaNumeroOperacionalPedido =>
      ativarnumerooperacionalpedido.trim().isNotEmpty ||
      imprimirnumerooperacionalentregador.trim().isNotEmpty ||
      imprimirnumerooperacionalconsumacao.trim().isNotEmpty ||
      imprimirnumerooperacionalpreparo.trim().isNotEmpty;
  bool get _numeroOperacionalAtivo =>
      ativarnumerooperacionalpedido.trim().isEmpty ||
      _sim(ativarnumerooperacionalpedido);
  bool _permiteNumeroOperacional(String valor) =>
      !controlaNumeroOperacionalPedido ||
      (_numeroOperacionalAtivo && (valor.trim().isEmpty || _sim(valor)));
  bool get imprimeNumeroOperacionalEntregador =>
      _permiteNumeroOperacional(imprimirnumerooperacionalentregador);
  bool get imprimeNumeroOperacionalConsumacao =>
      _permiteNumeroOperacional(imprimirnumerooperacionalconsumacao);
  bool get imprimeNumeroOperacionalPreparo =>
      _permiteNumeroOperacional(imprimirnumerooperacionalpreparo);
  bool get imprimePreparoNoComprovanteConsumacao =>
      _sim(imprimirpreparocomprovanteconsumacao);

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'clientecompedidosdecorrentes': clientecompedidosdecorrentes,
      'tempoparaenviodecorrente': tempoparaenviodecorrente,
      'balcaorapido': balcaorapido,
      'abrircomandadireto': abrircomandadireto,
      'abrirmesadireto': abrirmesadireto,
      'agrupamentodeitenscomanda': agrupamentodeitenscomanda,
      'agrupamentodeitensmesa': agrupamentodeitensmesa,
      'agrupamentodeitensbalcao': agrupamentodeitensbalcao,
      'agrupamentodeitensdelivery': agrupamentodeitensdelivery,
      'obrigarjustifcancelarpedido': obrigarjustifcancelarpedido,
      'mostrarnomeempresapreparo': mostrarnomeempresapreparo,
      'mostrarnomeclientepreparo': mostrarnomeclientepreparo,
      'tamanhofontepreparoaltura': tamanhofontepreparoaltura,
      'tamanhofontepreparolargura': tamanhofontepreparolargura,
      'formacobrancaentregadelivery': formacobrancaentregadelivery,
      'valordaentrega': valordaentrega,
      'valorembalagemseparada': valorembalagemseparada,
      'agrupamentodeitenscomprovconsumo': agrupamentodeitenscomprovconsumo,
      'agrupamentodeitenscomproventregador':
          agrupamentodeitenscomproventregador,
      'valordiferenca': valordiferenca,
      'saborlimitedeborda': saborlimitedeborda,
      'autenticarcomtag': autenticarcomtag,
      'numerodopedidodestaquecomprovante': numerodopedidodestaquecomprovante,
      'numerodopedidodestaquepreparo': numerodopedidodestaquepreparo,
      'ativarnumerooperacionalpedido': ativarnumerooperacionalpedido,
      'imprimirnumerooperacionalentregador':
          imprimirnumerooperacionalentregador,
      'imprimirnumerooperacionalconsumacao':
          imprimirnumerooperacionalconsumacao,
      'imprimirnumerooperacionalpreparo': imprimirnumerooperacionalpreparo,
      'imprimirpreparocomprovanteconsumacao':
          imprimirpreparocomprovanteconsumacao,
      'modelo_valor_adicional_pizza': modeloValorAdicionalPizza,
      'permitireditarquantidadeappaposfinalizar':
          permitireditarquantidadeappaposfinalizar,
      'permitireditarobservacaoappaposfinalizar':
          permitireditarobservacaoappaposfinalizar,
      'permitireditarsaborpizzaappaposfinalizar':
          permitireditarsaborpizzaappaposfinalizar,
      'permitireditarbordaappaposfinalizar':
          permitireditarbordaappaposfinalizar,
      'permitireditaradicionalappaposfinalizar':
          permitireditaradicionalappaposfinalizar,
      'permitirfinalizarmesa': permitirfinalizarmesa,
      'permitirfinalizarcomanda': permitirfinalizarcomanda,
    };
  }

  factory ModeloConfigBigchef.fromMap(Map<String, dynamic> map) {
    return ModeloConfigBigchef(
      clientecompedidosdecorrentes: (map['clientecompedidosdecorrentes'] ??
              map['cliente_com_pedidos_decorrentes'] ??
              'Não')
          .toString(),
      tempoparaenviodecorrente: (map['tempoparaenviodecorrente'] ??
              map['tempo_para_envio_decorrente'] ??
              '20')
          .toString(),
      balcaorapido:
          (map['balcaorapido'] ?? map['balcao_rapido'] ?? 'Não').toString(),
      abrircomandadireto: _texto(map, 'abrircomandadireto'),
      abrirmesadireto: _texto(map, 'abrirmesadireto'),
      agrupamentodeitenscomanda: _texto(map, 'agrupamentodeitenscomanda'),
      agrupamentodeitensmesa: _texto(map, 'agrupamentodeitensmesa'),
      agrupamentodeitensbalcao: _texto(map, 'agrupamentodeitensbalcao'),
      agrupamentodeitensdelivery: _texto(map, 'agrupamentodeitensdelivery'),
      obrigarjustifcancelarpedido: _texto(map, 'obrigarjustifcancelarpedido'),
      mostrarnomeempresapreparo: _texto(map, 'mostrarnomeempresapreparo'),
      mostrarnomeclientepreparo: _texto(map, 'mostrarnomeclientepreparo'),
      tamanhofontepreparoaltura: _texto(map, 'tamanhofontepreparoaltura'),
      tamanhofontepreparolargura: _texto(map, 'tamanhofontepreparolargura'),
      formacobrancaentregadelivery: _texto(map, 'formacobrancaentregadelivery'),
      valordaentrega: _texto(map, 'valordaentrega'),
      valorembalagemseparada: (map['valorembalagemseparada'] ??
              map['valor_embalagem_separada'] ??
              '0.00')
          .toString(),
      agrupamentodeitenscomprovconsumo:
          _texto(map, 'agrupamentodeitenscomprovconsumo'),
      agrupamentodeitenscomproventregador:
          _texto(map, 'agrupamentodeitenscomproventregador'),
      valordiferenca: _texto(map, 'valordiferenca', '0'),
      saborlimitedeborda: _texto(map, 'saborlimitedeborda', '0'),
      autenticarcomtag: _texto(map, 'autenticarcomtag'),
      numerodopedidodestaquecomprovante:
          _texto(map, 'numerodopedidodestaquecomprovante', 'Não'),
      numerodopedidodestaquepreparo:
          _texto(map, 'numerodopedidodestaquepreparo', 'Não'),
      ativarnumerooperacionalpedido:
          _texto(map, 'ativarnumerooperacionalpedido'),
      imprimirnumerooperacionalentregador:
          _texto(map, 'imprimirnumerooperacionalentregador'),
      imprimirnumerooperacionalconsumacao:
          _texto(map, 'imprimirnumerooperacionalconsumacao'),
      imprimirnumerooperacionalpreparo:
          _texto(map, 'imprimirnumerooperacionalpreparo'),
      imprimirpreparocomprovanteconsumacao: _textoConfig(
          map,
          'imprimirpreparocomprovanteconsumacao',
          'imprimir_preparo_comprovante_consumacao'),
      modeloValorAdicionalPizza: (map['modelo_valor_adicional_pizza'] ??
              map['modelovaloradicionalpizza'])
          ?.toString(),
      permitireditarquantidadeappaposfinalizar: _textoConfig(
          map,
          'permitireditarquantidadeappaposfinalizar',
          'permitir_editar_quantidade_app_apos_finalizar'),
      permitireditarobservacaoappaposfinalizar: _textoConfig(
          map,
          'permitireditarobservacaoappaposfinalizar',
          'permitir_editar_observacao_app_apos_finalizar'),
      permitireditarsaborpizzaappaposfinalizar: _textoConfig(
          map,
          'permitireditarsaborpizzaappaposfinalizar',
          'permitir_editar_sabor_pizza_app_apos_finalizar'),
      permitireditarbordaappaposfinalizar: _textoConfig(
          map,
          'permitireditarbordaappaposfinalizar',
          'permitir_editar_borda_app_apos_finalizar'),
      permitireditaradicionalappaposfinalizar: _textoConfig(
          map,
          'permitireditaradicionalappaposfinalizar',
          'permitir_editar_adicional_app_apos_finalizar'),
      permitirfinalizarmesa:
          _textoConfig(map, 'permitirfinalizarmesa', 'permitir_finalizar_mesa'),
      permitirfinalizarcomanda: _textoConfig(
          map, 'permitirfinalizarcomanda', 'permitir_finalizar_comanda'),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloConfigBigchef.fromJson(String source) =>
      ModeloConfigBigchef.fromMap(json.decode(source) as Map<String, dynamic>);
}
