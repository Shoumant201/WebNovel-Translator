import 'package:html/dom.dart';

import '../fetch_result.dart';

/// A parser knows how to pull chapter title, body text, and the "next
/// chapter" link out of a parsed HTML document for a specific site.
abstract class ChapterParser {
  /// Whether this parser should be used for the given host, e.g. "www.royalroad.com".
  bool matches(String host);

  /// Parse the document. `pageUrl` is provided so relative links can be resolved.
  ChapterFetchResult parse(Document document, Uri pageUrl);
}

/// Resolves a possibly-relative href against the page URL.
String? resolveHref(Uri pageUrl, String? href) {
  if (href == null || href.trim().isEmpty) return null;
  try {
    return pageUrl.resolve(href.trim()).toString();
  } catch (_) {
    return null;
  }
}

/// Collapses whitespace and joins paragraph-like elements into readable text.
String joinParagraphs(Iterable<Element> paragraphs) {
  final blocks = paragraphs
      .map((e) => e.text.trim())
      .where((t) => t.isNotEmpty)
      .toList();
  return blocks.join('\n\n');
}
