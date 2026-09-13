String normalizarBusca(String texto) {
  const grupos = {
    'a': 'áàâãäå',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
    'n': 'ñ',
    'y': 'ýÿ',
  };
  var resultado = texto.toLowerCase().trim();
  for (final grupo in grupos.entries) {
    for (final acento in grupo.value.split('')) {
      resultado = resultado.replaceAll(acento, grupo.key);
    }
  }
  return resultado
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}
