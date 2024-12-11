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
  final String? tipoImpressao;
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
  final String? valorentrega;
  final String? tipodeentrega;
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

  ModeloRetornoSocket({
    required this.tipo,
    this.enviarDeVolta,
    this.nomedopc,
    this.nomeConexao,
    this.idUsuario,
    this.tipoImpressao,
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
    this.valorentrega,
    this.tipodeentrega,
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
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tipo': tipo,
      'enviarDeVolta': enviarDeVolta,
      'nomedopc': nomedopc,
      'nomeConexao': nomeConexao,
      'idUsuario': idUsuario,
      'tipoImpressao': tipoImpressao,
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
      'valorentrega': valorentrega,
      'tipodeentrega': tipodeentrega,
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
    };
  }

  factory ModeloRetornoSocket.fromMap(Map<String, dynamic> map) {
    return ModeloRetornoSocket(
      tipo: map['tipo'] as String,
      enviarDeVolta: map['enviarDeVolta'] != null ? map['enviarDeVolta'] as bool : null,
      nomedopc: map['nomedopc'] != null ? map['nomedopc'] as String : null,
      nomeConexao: map['nomeConexao'] != null ? map['nomeConexao'] as String : null,
      idUsuario: map['idUsuario'] != null ? map['idUsuario'] as String : null,
      tipoImpressao: map['tipoImpressao'] != null ? map['tipoImpressao'] as String : null,
      ocupado: map['ocupado'] != null ? map['ocupado'] as bool : null,
      numeroPedido: map['numeroPedido'] != null ? map['numeroPedido'] as String : null,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      nomeEmpresa: map['nomeEmpresa'] != null ? map['nomeEmpresa'] as String : null,
      comanda: map['comanda'] != null ? map['comanda'] as String : null,
      permanencia: map['permanencia'] != null ? map['permanencia'] as String : null,
      somaValorHistorico: map['somaValorHistorico'] != null ? map['somaValorHistorico'] as String : null,
      celularEmpresa: map['celularEmpresa'] != null ? map['celularEmpresa'] as String : null,
      cnpjEmpresa: map['cnpjEmpresa'] != null ? map['cnpjEmpresa'] as String : null,
      enderecoEmpresa: map['enderecoEmpresa'] != null ? map['enderecoEmpresa'] as String : null,
      total: map['total'] != null ? map['total'] as String : null,
      local: map['local'] != null ? map['local'] as String : null,
      valorentrega: map['valorentrega'] != null ? map['valorentrega'] as String : null,
      tipodeentrega: map['tipodeentrega'] != null ? map['tipodeentrega'] as String : null,
      celularCliente: map['celularCliente'] != null ? map['celularCliente'] as String : null,
      enderecoCliente: map['enderecoCliente'] != null ? map['enderecoCliente'] as String : null,
      valortroco: map['valortroco'] != null ? map['valortroco'] as String : null,
      numeroCliente: map['numeroCliente'] != null ? map['numeroCliente'] as String : null,
      bairroCliente: map['bairroCliente'] != null ? map['bairroCliente'] as String : null,
      complementoCliente: map['complementoCliente'] != null ? map['complementoCliente'] as String : null,
      cidadeCliente: map['cidadeCliente'] != null ? map['cidadeCliente'] as String : null,
      nomelancamento: map['nomelancamento'] != null
          ? List<ModeloNomeLancamento>.from(
              (map['nomelancamento'] as List<dynamic>).map<ModeloNomeLancamento?>(
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
      idComandaPedido: map['idComandaPedido'] != null ? map['idComandaPedido'] as String : null,
      nome: map['nome'] != null ? map['nome'] as String : null,
      codigo: map['codigo'] != null ? map['codigo'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloRetornoSocket.fromJson(String source) => ModeloRetornoSocket.fromMap(json.decode(source) as Map<String, dynamic>);
}
