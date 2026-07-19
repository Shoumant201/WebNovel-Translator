import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// RoyalRoad chapter pages have a stable structure:
/// - Title: <h1 class="font-white break-word"> inside the fic header, or <title>
/// - Body: <div class="chapter-content">
/// - Next: <a> with text containing "Next" inside the chapter navigation buttons.
class RoyalRoadParser implements ChapterParser {
  @override
  bool matches(String host) => host.contains('royalroad.com');

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final contentDiv =
        document.querySelector('.chapter-content') ??
        document.querySelector('.chapter-inner');
    if (contentDiv == null) {
      return ChapterFetchResult.fail(
        'Could not locate .chapter-content on RoyalRoad page',
        strategy: FetchStrategy.royalRoad,
      );
    }

    final paragraphs = contentDiv.querySelectorAll('p');
    final bodyText = paragraphs.isNotEmpty
        ? joinParagraphs(paragraphs)
        : contentDiv.text.trim();

    String? title = document.querySelector('h1')?.text.trim();
    title ??= document.querySelector('title')?.text.trim();

    String? nextUrl;
    for (final a in document.querySelectorAll('a')) {
      final text = a.text.trim().toLowerCase();
      if (text == 'next' || text.contains('next chapter')) {
        nextUrl = resolveHref(pageUrl, a.attributes['href']);
        if (nextUrl != null) break;
      }
    }

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: nextUrl,
      strategy: FetchStrategy.royalRoad,
    );
  }
}
