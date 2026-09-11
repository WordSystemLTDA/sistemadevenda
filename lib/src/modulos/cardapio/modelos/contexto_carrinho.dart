import 'dart:convert';

class ContextoCarrinho {
  final String empresa;
  final String tipo;
  final String idAtendimento;
  final String idRecurso;

  const ContextoCarrinho({
    required this.empresa,
    required this.tipo,
    required this.idAtendimento,
    this.idRecurso = '',
  });

  // Mesas e comandas usam a mesma tabela de atendimentos no servidor.
  String get chave => jsonEncode([
        empresa,
        tipo == 'mesa' || tipo == 'comanda' ? 'atendimento' : tipo,
        idAtendimento,
      ]);

  bool get valido =>
      empresa.isNotEmpty &&
      (idAtendimento.isNotEmpty && idAtendimento != '0' || tipo == 'balcao');

  Map<String, dynamic> toMap() => {
        'empresa': empresa,
        'tipo': tipo,
        'idAtendimento': idAtendimento,
        'idRecurso': idRecurso,
      };

  factory ContextoCarrinho.fromMap(Map<String, dynamic> map) =>
      ContextoCarrinho(
        empresa: map['empresa'] as String,
        tipo: map['tipo'] as String,
        idAtendimento: map['idAtendimento'] as String,
        idRecurso: map['idRecurso'] as String? ?? '',
      );
}
