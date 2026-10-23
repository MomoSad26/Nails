/// Normalizes text for accent-insensitive, case-insensitive substring search.
String normalizeSearch(String value) {
  final lower = value.toLowerCase().trim();
  // This explicit map avoids depending on platform-specific locale behavior.
  const replacements = <String, String>{
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };
  final output = StringBuffer();
  for (final character in lower.split('')) {
    output.write(replacements[character] ?? character);
  }
  return output.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}
