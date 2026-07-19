import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// Fallback parser for sites we don't have a specific scraper for.
///
/// Strategy:
/// 1. Find every candidate container (div/article/section) that holds
///    multiple <p> tags, and score each by total paragraph text length
///    minus a penalty for link density (nav/ads tend to be link-heavy).
/// 2. Pick the highest-scoring container as the chapter body.
/// 3. Look for a "next chapter" link anywhere on the page by matching
///    common phrases in anchor text.
class GenericParser implements ChapterParser {
  static const _navWords = [
    'next chapter',
    'next episode',
    'next »',
    'next>',
    'next ›',
    'continue reading',
    '下一章', // "next chapter" in Chinese, common on raw sites
    '次の章',
  ];

  @override
  bool matches(String host) => true; // always applicable as last resort

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final candidates = <Element, double>{};

    // Try to find content by common patterns first
    for (final el in document.querySelectorAll('div, article, section, main')) {
      // Check for content-indicating class/id names
      final className = el.attributes['class'] ?? '';
      final id = el.attributes['id'] ?? '';
      final contentKeywords = [
        'content',
        'chapter',
        'text',
        'txt',
        'article',
        'story',
        'body',
      ];

      var hasContentIndicator = contentKeywords.any(
        (kw) =>
            className.toLowerCase().contains(kw) ||
            id.toLowerCase().contains(kw),
      );

      // Get text content
      final text = el.text.trim();
      if (text.length < 200) continue;

      // Calculate link density
      final linkText = el
          .querySelectorAll('a')
          .map((a) => a.text)
          .join()
          .length;
      final density = linkText / (text.length + 1);
      final clampedDensity = density.clamp(0.0, 0.9).toDouble();

      // Score: length * (1 - link_density) with bonus for content indicators
      var score = text.length * (1 - clampedDensity);
      if (hasContentIndicator) {
        score *= 1.5; // 50% bonus for having content-related class/id
      }

      // Check for paragraphs
      final paragraphs = el.children.where((c) => c.localName == 'p').toList();
      if (paragraphs.length >= 2) {
        score *= 1.2; // 20% bonus for having multiple paragraphs
      }

      candidates[el] = score;
    }

    if (candidates.isEmpty) {
      // Fallback: try to find any large text blocks
      for (final el in document.querySelectorAll('*')) {
        final tagName = el.localName?.toLowerCase() ?? '';
        if (['script', 'style', 'nav', 'header', 'footer'].contains(tagName))
          continue;

        final text = el.text.trim();
        if (text.length < 500) continue;

        final linkText = el
            .querySelectorAll('a')
            .map((a) => a.text)
            .join()
            .length;
        final density = linkText / (text.length + 1);

        if (density < 0.3) {
          candidates[el] = text.length.toDouble();
        }
      }
    }

    if (candidates.isEmpty) {
      // Last-ditch effort: just grab all <p> tags on the page.
      final allParagraphs = document.querySelectorAll('p');
      final text = joinParagraphs(allParagraphs);
      if (text.length < 200) {
        return ChapterFetchResult.fail(
          'Generic parser could not find a chapter-sized text block on this page',
          strategy: FetchStrategy.generic,
        );
      }
      return ChapterFetchResult.ok(
        title: document.querySelector('title')?.text.trim(),
        bodyText: text,
        nextChapterUrl: _findNextLink(document, pageUrl),
        strategy: FetchStrategy.generic,
      );
    }

    final best = candidates.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;

    // Try to get paragraphs first, if available
    final paragraphs = best.children.where((c) => c.localName == 'p').toList();
    final bodyText = paragraphs.isNotEmpty
        ? joinParagraphs(paragraphs)
        : best.text.trim();

    final title =
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim();

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: _findNextLink(document, pageUrl),
      strategy: FetchStrategy.generic,
    );
  }

  String? _findNextLink(Document document, Uri pageUrl) {
    for (final a in document.querySelectorAll('a')) {
      final text = a.text.trim().toLowerCase();
      final rel = a.attributes['rel']?.toLowerCase() ?? '';
      if (rel == 'next' || _navWords.any((w) => text.contains(w))) {
        final url = resolveHref(pageUrl, a.attributes['href']);
        if (url != null) return url;
      }
    }
    return null;
  }
}
