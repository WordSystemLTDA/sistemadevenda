import 'dart:convert';

/// Limites compartilhados pelo gravador, transporte e exportador.
class SanitizadorDiagnostico {
  static final sensivel = RegExp(
    r'senha|password|passwd|pwd|token|authorization|cookie|secret|api[_-]?key|licenca|certificado|xml|base64|arquivo_conteudo|cartao|cvv|cpf|cnpj|email|telefone|celular|endereco|logradouro|complemento|nome_cliente|nome_usuario',
    caseSensitive: false,
  );

  static Object? limpar(Object? valor, [int nivel = 0, List<int>? limite]) {
    limite ??= [1200];
    if (--limite[0] <= 0 || nivel > 7) return '[conteudo limitado]';
    if (valor == null || valor is num || valor is bool) return valor;
    if (valor is Map) {
      final entradas = valor.entries.take(60);
      return <String, Object?>{
        for (final e in entradas.take(limite[0].clamp(0, 60))) e.key.toString(): sensivel.hasMatch(e.key.toString()) ? '[oculto]' : limpar(e.value, nivel + 1, limite),
        if (valor.length > 60) '_campos_omitidos': valor.length - 60,
      };
    }
    if (valor is Iterable) {
      return valor.take(limite[0].clamp(0, 40)).map((v) => limpar(v, nivel + 1, limite)).toList();
    }
    var texto = valor.toString();
    // JSON serializado tambem precisa de redacao recursiva.
    if (texto.length <= 65536 && (texto.startsWith('{') || texto.startsWith('['))) {
      try {
        return limpar(jsonDecode(texto), nivel + 1, limite);
      } on FormatException {
        // Respostas PHP/HTML incompletas continuam disponiveis como texto.
      }
    }
    texto = texto.length > 20000 ? '${texto.substring(0, 20000)} [truncado]' : texto;
    texto = texto.replaceAllMapped(RegExp(r'''https?://[^\s<>"']+'''), (m) {
      final uri = Uri.tryParse(m[0]!);
      return uri == null ? '[url]' : uri.replace(userInfo: '', query: '', fragment: '').toString();
    });
    texto = texto.replaceAll(RegExp(r'\b(Bearer|Basic)\s+[^\s,;"}]+', caseSensitive: false), '[credencial oculta]');
    texto = texto.replaceAll(
        RegExp(
          r'''["']?(?:[\w-]*token|[\w-]*licenca[\w-]*|senha|password|passwd|pwd|authorization|cookie|secret|api[_-]?key|cpf|cnpj|email|telefone|celular)["']?\s*[:=]\s*(?:"[^"]*"|'[^']*'|[^\s&,;}]+)''',
          caseSensitive: false,
        ),
        '[dado oculto]');
    texto = texto.replaceAll(RegExp(r'[\w.+-]+@[\w.-]+\.[a-zA-Z]{2,}'), '[email oculto]');
    return texto;
  }

  static Map<String, Object?> mapa(Map valor) => Map<String, Object?>.from(limpar(valor) as Map);
}
