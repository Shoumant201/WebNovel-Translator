import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// wuxiaworld.com (the .com site, not the older self-hosted one) uses a
/// `.chapter-content` / `.chapter-entity` wrapper with `article p` paragraphs.
class WuxiaWorldParser implements ChapterParser {
  @override
  bool matches(String host) => host.contains('wuxiaworld.com');

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final contentDiv =
        document.querySelector('.chapter-content') ??
        document.querySelector('.chapter-entity') ??
        document.querySelector('article');

    if (contentDiv == null) {
      return ChapterFetchResult.fail(
        'Could not locate chapter content on wuxiaworld.com page',
        strategy: FetchStrategy.wuxiaWorld,
      );
    }

    final paragraphs = contentDiv.querySelectorAll('p');
    final bodyText = paragraphs.isNotEmpty
        ? joinParagraphs(paragraphs)
        : contentDiv.text.trim();

    final title =
        document.querySelector('h4')?.text.trim() ??
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim();

    String? nextUrl;
    for (final a in document.querySelectorAll('a')) {
      final text = a.text.trim().toLowerCase();
      if (text.contains('next chapter') || text == 'next') {
        nextUrl = resolveHref(pageUrl, a.attributes['href']);
        if (nextUrl != null) break;
      }
    }

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: nextUrl,
      strategy: FetchStrategy.wuxiaWorld,
    );
  }
}
