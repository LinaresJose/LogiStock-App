class StringExtensions {
  /// Convierte el texto a minúsculas y pone en mayúscula la primera letra de cada oración.
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    final lower = trimmed.toLowerCase();
    final sentences = lower.split(RegExp(r'(?<=\.)\s*'));
    
    final capitalizedSentences = sentences.map((s) {
      if (s.isEmpty) return s;
      final firstLetterMatch = RegExp(r'[a-z]').firstMatch(s);
      if (firstLetterMatch == null) return s;
      
      final index = firstLetterMatch.start;
      return s.substring(0, index) + 
             s[index].toUpperCase() + 
             s.substring(index + 1);
    });

    return capitalizedSentences.join(' ');
  }

  /// Convierte el texto a Title Case (la primera letra de CADA palabra en mayúscula).
  static String titleCase(String text) {
    if (text.isEmpty) return text;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;

    final words = trimmed.toLowerCase().split(RegExp(r'\s+'));
    final capitalizedWords = words.map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    });

    return capitalizedWords.join(' ');
  }
}
