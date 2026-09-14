import 'dart:convert';

String _texto(Object? valor, [String padrao = '']) =>
    valor?.toString() ?? padrao;

bool? _boolOpcional(Object? valor) {
  if (valor == null) return null;
  if (valor is bool) return valor;
  final texto = valor.toString().toLowerCase();
  if (texto == 'true' || texto == '1' || texto == 'sim') return true;
  if (texto == 'false' || texto == '0' || texto == 'nao' || texto == 'não') {
    return false;
  }
  return null;
}

int? _inteiroOpcional(Object? valor) {
  if (valor is num) return valor.toInt();
  return int.tryParse((valor ?? '').toString());
}

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ModeloDadosOpcoesPacotes {
  final String id;
  final String nome;
  final String? codigo;
  final String imprimirCodigoProdutoPreparo;
  final String? valor;
  final String? valorOriginal;
  final String? foto;
  final String? quantimaximaselecao;
  final String? habilsepardelivery;
  bool? estaSelecionado;
  bool? excluir;
  int? quantidade;
  bool somenteMetadeBorda;

  ModeloDadosOpcoesPacotes({
    required this.id,
    required this.nome,
    this.codigo,
    this.imprimirCodigoProdutoPreparo = 'Não',
    this.valor,
    this.valorOriginal,
    this.foto,
    this.quantimaximaselecao,
    this.habilsepardelivery,
    this.estaSelecionado,
    this.excluir,
    this.quantidade,
    this.somenteMetadeBorda = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'codigo': codigo,
      'imprimirCodigoProdutoPreparo': imprimirCodigoProdutoPreparo,
      'valor': valor,
      if (valorOriginal != null) 'valorOriginal': valorOriginal,
      'foto': foto,
      'quantimaximaselecao': quantimaximaselecao,
      'habilsepardelivery': habilsepardelivery,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
      'quantidade': quantidade,
      if (somenteMetadeBorda) 'somenteMetadeBorda': somenteMetadeBorda,
    };
  }

  factory ModeloDadosOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    return ModeloDadosOpcoesPacotes(
      id: _texto(map['id']),
      nome: _texto(map['nome']),
      codigo: map['codigo']?.toString(),
      valor: map['valor']?.toString(),
      valorOriginal: map['valorOriginal']?.toString(),
      foto: map['foto']?.toString(),
      quantimaximaselecao: map['quantimaximaselecao']?.toString(),
      habilsepardelivery: map['habilsepardelivery']?.toString(),
      estaSelecionado: _boolOpcional(map['estaSelecionado']),
      excluir: _boolOpcional(map['excluir']),
      quantidade: _inteiroOpcional(map['quantidade']),
      somenteMetadeBorda: _boolOpcional(map['somenteMetadeBorda']) == true ||
          _boolOpcional(map['bordaSomenteMetade']) == true ||
          _boolOpcional(map['somente_metade_borda']) == true,
      imprimirCodigoProdutoPreparo: (map['imprimirCodigoProdutoPreparo'] ??
                  map['imprimir_codigo_produto_preparo'])
              ?.toString() ??
          'Não',
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDadosOpcoesPacotes.fromJson(String source) =>
      ModeloDadosOpcoesPacotes.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
