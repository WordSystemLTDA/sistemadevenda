// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ModeloRetornoSocket {
  final String tipo;
  final bool? enviarDeVolta;
  final String? nomedopc;
  final String? nomeConexao;
  final String? idUsuario;
  final String? nomeUsuario;
  final String? idEmpresa;
  final String? tipoImpressao;
  final int? protocoloImpressao;
  final String? tipoResposta;
  final String? statusResposta;
  final String? mensagemErro;
  final String? referenciaImpressaoOrigem;
  final String? idRequisicao;
  final bool? ocupado;

  final String? numeroPedido;
  final String? nomeCliente;
  final String? nomeEmpresa;
  final String? comanda;
  final String? permanencia;
  final String? somaValorHistorico;
  final String? celularEmpresa;
  final String? cnpjEmpresa;
  final String? enderecoEmpresa;
  final String? total;
  final String? local;
  final String? valortaxadeservico;
  final String? valorentrega;
  final String? valordesconto;
  final String? valoracrescimo;
  final String? tipodeentrega;
  final String? numerodopedidodestaquecomprovante;
  final String? numerodopedidodestaquepreparo;
  final String? ativarnumerooperacionalpedido;
  final String? imprimirnumerooperacionalentregador;
  final String? imprimirnumerooperacionalconsumacao;
  final String? imprimirnumerooperacionalpreparo;
  final String? celularCliente;
  final String? enderecoCliente;
  final String? valortroco;
  final String? numeroCliente;
  final String? bairroCliente;
  final String? complementoCliente;
  final String? cidadeCliente;
  final List<ModeloNomeLancamento>? nomelancamento;
  final List<Modelowordprodutos>? produtos;
  // MESA | COMANDA
  final String? id;
  final String? idComandaPedido;
  final String? nome;
  final String? codigo;
  final String? observacaoDoPedido;

  ModeloRetornoSocket({
    required this.tipo,
    this.enviarDeVolta,
    this.nomedopc,
    this.nomeConexao,
    this.idUsuario,
    this.nomeUsuario,
    this.idEmpresa,
    this.tipoImpressao,
    this.protocoloImpressao,
    this.tipoResposta,
    this.statusResposta,
    this.mensagemErro,
    this.referenciaImpressaoOrigem,
    this.idRequisicao,
    this.ocupado,
    this.numeroPedido,
    this.nomeCliente,
    this.nomeEmpresa,
    this.comanda,
    this.permanencia,
    this.somaValorHistorico,
    this.celularEmpresa,
    this.cnpjEmpresa,
    this.enderecoEmpresa,
    this.total,
    this.local,
    this.valortaxadeservico,
    this.valorentrega,
    this.valordesconto,
    this.valoracrescimo,
    this.tipodeentrega,
    this.numerodopedidodestaquecomprovante,
    this.numerodopedidodestaquepreparo,
    this.ativarnumerooperacionalpedido,
    this.imprimirnumerooperacionalentregador,
    this.imprimirnumerooperacionalconsumacao,
    this.imprimirnumerooperacionalpreparo,
    this.celularCliente,
    this.enderecoCliente,
    this.valortroco,
    this.numeroCliente,
    this.bairroCliente,
    this.complementoCliente,
    this.cidadeCliente,
    this.nomelancamento,
    this.produtos,
    this.id,
    this.idComandaPedido,
    this.nome,
    this.codigo,
    this.observacaoDoPedido,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tipo': tipo,
      'enviarDeVolta': enviarDeVolta,
      'nomedopc': nomedopc,
      'nomeConexao': nomeConexao,
      'idUsuario': idUsuario,
      'nomeUsuario': nomeUsuario,
      'idEmpresa': idEmpresa,
      'tipoImpressao': tipoImpressao,
      'protocoloImpressao': protocoloImpressao,
      'tipoResposta': tipoResposta,
      'statusResposta': statusResposta,
      'mensagemErro': mensagemErro,
      'referenciaImpressaoOrigem': referenciaImpressaoOrigem,
      'idRequisicao': idRequisicao,
      'ocupado': ocupado,
      'numeroPedido': numeroPedido,
      'nomeCliente': nomeCliente,
      'nomeEmpresa': nomeEmpresa,
      'comanda': comanda,
      'permanencia': permanencia,
      'somaValorHistorico': somaValorHistorico,
      'celularEmpresa': celularEmpresa,
      'cnpjEmpresa': cnpjEmpresa,
      'enderecoEmpresa': enderecoEmpresa,
      'total': total,
      'local': local,
      'valortaxadeservico': valortaxadeservico,
      'valorentrega': valorentrega,
      'valordesconto': valordesconto,
      'valoracrescimo': valoracrescimo,
      'tipodeentrega': tipodeentrega,
      'numerodopedidodestaquecomprovante': numerodopedidodestaquecomprovante,
      'numerodopedidodestaquepreparo': numerodopedidodestaquepreparo,
      'ativarnumerooperacionalpedido': ativarnumerooperacionalpedido,
      'imprimirnumerooperacionalentregador':
          imprimirnumerooperacionalentregador,
      'imprimirnumerooperacionalconsumacao':
          imprimirnumerooperacionalconsumacao,
      'imprimirnumerooperacionalpreparo': imprimirnumerooperacionalpreparo,
      'celularCliente': celularCliente,
      'enderecoCliente': enderecoCliente,
      'valortroco': valortroco,
      'numeroCliente': numeroCliente,
      'bairroCliente': bairroCliente,
      'complementoCliente': complementoCliente,
      'cidadeCliente': cidadeCliente,
      'nomelancamento': nomelancamento?.map((x) => x.toMap()).toList(),
      'produtos': produtos?.map((x) => x.toMap()).toList(),
      'id': id,
      'idComandaPedido': idComandaPedido,
      'nome': nome,
      'codigo': codigo,
      'observacaoDoPedido': observacaoDoPedido,
    };
  }

  factory ModeloRetornoSocket.fromMap(Map<String, dynamic> map) {
    return ModeloRetornoSocket(
      tipo: map['tipo'] as String,
      enviarDeVolta:
          map['enviarDeVolta'] != null ? map['enviarDeVolta'] as bool : null,
      nomedopc: map['nomedopc'] != null ? map['nomedopc'] as String : null,
      nomeConexao:
          map['nomeConexao'] != null ? map['nomeConexao'] as String : null,
      idUsuario: map['idUsuario'] != null ? map['idUsuario'] as String : null,
      nomeUsuario: map['nomeUsuario']?.toString(),
      idEmpresa: map['idEmpresa']?.toString(),
      tipoImpressao:
          map['tipoImpressao'] != null ? map['tipoImpressao'] as String : null,
      protocoloImpressao: map['protocoloImpressao'] is int
          ? map['protocoloImpressao'] as int
          : int.tryParse(map['protocoloImpressao']?.toString() ?? ''),
      tipoResposta:
          map['tipoResposta'] != null ? map['tipoResposta'] as String : null,
      statusResposta: map['statusResposta'] != null
          ? map['statusResposta'] as String
          : null,
      mensagemErro:
          map['mensagemErro'] != null ? map['mensagemErro'] as String : null,
      referenciaImpressaoOrigem: map['referenciaImpressaoOrigem'] != null
          ? map['referenciaImpressaoOrigem'] as String
          : null,
      idRequisicao:
          map['idRequisicao'] != null ? map['idRequisicao'] as String : null,
      ocupado: map['ocupado'] != null ? map['ocupado'] as bool : null,
      numeroPedido:
          map['numeroPedido'] != null ? map['numeroPedido'] as String : null,
      nomeCliente:
          map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      nomeEmpresa:
          map['nomeEmpresa'] != null ? map['nomeEmpresa'] as String : null,
      comanda: map['comanda'] != null ? map['comanda'] as String : null,
      permanencia:
          map['permanencia'] != null ? map['permanencia'] as String : null,
      somaValorHistorico: map['somaValorHistorico'] != null
          ? map['somaValorHistorico'] as String
          : null,
      celularEmpresa: map['celularEmpresa'] != null
          ? map['celularEmpresa'] as String
          : null,
      cnpjEmpresa:
          map['cnpjEmpresa'] != null ? map['cnpjEmpresa'] as String : null,
      enderecoEmpresa: map['enderecoEmpresa'] != null
          ? map['enderecoEmpresa'] as String
          : null,
      total: map['total'] != null ? map['total'] as String : null,
      local: map['local'] != null ? map['local'] as String : null,
      valortaxadeservico: map['valortaxadeservico']?.toString(),
      valorentrega:
          map['valorentrega'] != null ? map['valorentrega'] as String : null,
      valordesconto: map['valordesconto']?.toString(),
      valoracrescimo: map['valoracrescimo']?.toString(),
      tipodeentrega:
          map['tipodeentrega'] != null ? map['tipodeentrega'] as String : null,
      numerodopedidodestaquecomprovante:
          map['numerodopedidodestaquecomprovante']?.toString(),
      numerodopedidodestaquepreparo:
          map['numerodopedidodestaquepreparo']?.toString(),
      ativarnumerooperacionalpedido:
          map['ativarnumerooperacionalpedido']?.toString(),
      imprimirnumerooperacionalentregador:
          map['imprimirnumerooperacionalentregador']?.toString(),
      imprimirnumerooperacionalconsumacao:
          map['imprimirnumerooperacionalconsumacao']?.toString(),
      imprimirnumerooperacionalpreparo:
          map['imprimirnumerooperacionalpreparo']?.toString(),
      celularCliente: map['celularCliente'] != null
          ? map['celularCliente'] as String
          : null,
      enderecoCliente: map['enderecoCliente'] != null
          ? map['enderecoCliente'] as String
          : null,
      valortroco:
          map['valortroco'] != null ? map['valortroco'] as String : null,
      numeroCliente:
          map['numeroCliente'] != null ? map['numeroCliente'] as String : null,
      bairroCliente:
          map['bairroCliente'] != null ? map['bairroCliente'] as String : null,
      complementoCliente: map['complementoCliente'] != null
          ? map['complementoCliente'] as String
          : null,
      cidadeCliente:
          map['cidadeCliente'] != null ? map['cidadeCliente'] as String : null,
      nomelancamento: map['nomelancamento'] != null
          ? List<ModeloNomeLancamento>.from(
              (map['nomelancamento'] as List<dynamic>)
                  .map<ModeloNomeLancamento?>(
                (x) => ModeloNomeLancamento.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      produtos: map['produtos'] != null
          ? List<Modelowordprodutos>.from(
              (map['produtos'] as List<dynamic>).map<Modelowordprodutos?>(
                (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      id: map['id'] != null ? map['id'] as String : null,
      idComandaPedido: map['idComandaPedido'] != null
          ? map['idComandaPedido'] as String
          : null,
      nome: map['nome'] != null ? map['nome'] as String : null,
      codigo: map['codigo'] != null ? map['codigo'] as String : null,
      observacaoDoPedido: map['observacaoDoPedido'] != null
          ? map['observacaoDoPedido'] as String
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloRetornoSocket.fromJson(String source) =>
      ModeloRetornoSocket.fromMap(json.decode(source) as Map<String, dynamic>);
}
