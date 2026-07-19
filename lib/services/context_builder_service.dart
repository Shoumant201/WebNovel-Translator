import 'dart:convert';

/// Builds and maintains a per-novel "context" — a running glossary of
/// proper nouns (character/place names) and a short auto-generated summary
/// — purely from heuristics over translated text. No paid LLM call is
/// required, keeping the whole pipeline free-tier.
///
/// The glossary matters most in practice: LibreTranslate has no memory
/// between requests, so without this, the same character's name can be
/// transliterated differently chapter to chapter. We detect repeated
/// capitalized tokens and stabilize them across chapters.
class ContextBuilderService {
  /// Common English stop-words/pronouns that are capitalized at sentence
  /// starts and should not be treated as proper nouns.
  static const _stopWords = {
    'The',
    'A',
    'An',
    'He',
    'She',
    'It',
    'They',
    'We',
    'You',
    'I',
    'His',
    'Her',
    'Its',
    'Their',
    'Our',
    'Your',
    'This',
    'That',
    'These',
    'Those',
    'But',
    'And',
    'Or',
    'So',
    'Then',
    'When',
    'Where',
    'What',
    'Who',
    'Why',
    'How',
    'If',
    'As',
    'At',
    'In',
    'On',
    'For',
    'With',
    'Chapter',
  };

  /// Scans [translatedText] for repeated capitalized words/phrases (likely
  /// proper nouns) and merges them into the existing glossary map, keeping
  /// the most frequently seen spelling stable.
  Map<String, String> extractAndMergeGlossary(
    String translatedText,
    Map<String, String> existingGlossary,
  ) {
    final glossary = Map<String, String>.from(existingGlossary);
    final counts = <String, int>{};

    // Match sequences of 1-3 capitalized words (e.g. "Elara", "Elara Voss").
    final pattern = RegExp(r'\b([A-Z][a-z]+(?:\s[A-Z][a-z]+){0,2})\b');
    for (final match in pattern.allMatches(translatedText)) {
      final phrase = match.group(1)!;
      final firstWord = phrase.split(' ').first;
      if (_stopWords.contains(firstWord)) continue;
      if (phrase.length < 3) continue;
      counts[phrase] = (counts[phrase] ?? 0) + 1;
    }

    // Keep names that appear at least twice in this chapter (reduces noise
    // from incidental capitalization) or that are already in the glossary.
    for (final entry in counts.entries) {
      if (entry.value >= 2 || glossary.containsKey(entry.key)) {
        glossary.putIfAbsent(entry.key, () => entry.key);
      }
    }

    return glossary;
  }

  /// Produces a short human-readable summary string from the glossary and
  /// chapter count, used as `contextSummary` on the novel and shown to the
  /// user, and optionally prepended as a translation hint.
  String buildSummary({
    required String novelTitle,
    required int chapterCount,
    required Map<String, String> glossary,
  }) {
    final topNames = glossary.keys.take(12).join(', ');
    final buffer = StringBuffer();
    buffer.writeln('$novelTitle — $chapterCount chapter(s) tracked.');
    if (topNames.isNotEmpty) {
      buffer.writeln('Recurring names/terms: $topNames.');
    }
    return buffer.toString().trim();
  }

  String encodeGlossary(Map<String, String> glossary) => jsonEncode(glossary);

  Map<String, String> decodeGlossary(String json) {
    if (json.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }
}
