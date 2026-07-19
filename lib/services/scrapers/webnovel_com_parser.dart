import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// webnovel.com (Qidian's English site) frequently paywalls/gates chapters
/// behind JS-rendered content, so this parser is best-effort: it grabs
/// whatever paragraph text is present in the initial HTML (works for
/// free/unlocked chapters) and falls back gracefully otherwise.
class WebNovelComParser implements ChapterParser {
  @override
  bool matches(String host) => host.contains('webnovel.com');

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final contentDiv =
        document.querySelector('.cha-content') ??
        document.querySelector('.cha-words') ??
        document.querySelector('.chapter-content');

    if (contentDiv == null) {
      return ChapterFetchResult.fail(
        'Could not locate chapter content on webnovel.com page '
        '(chapter may be locked/premium or requires JS rendering)',
        strategy: FetchStrategy.webnovelCom,
      );
    }

    final paragraphs = contentDiv.querySelectorAll('p');
    final bodyText = paragraphs.isNotEmpty
        ? joinParagraphs(paragraphs)
        : contentDiv.text.trim();

    if (bodyText.length < 40) {
      return ChapterFetchResult.fail(
        'Chapter text too short — likely locked behind login/JS on webnovel.com',
        strategy: FetchStrategy.webnovelCom,
      );
    }

    final title =
        document.querySelector('.chapter-name')?.text.trim() ??
        document.querySelector('h1')?.text.trim() ??
        document.querySelector('title')?.text.trim();

    String? nextUrl;
    final nextAnchor =
        document.querySelector('a.next_chapter') ??
        document
            .querySelectorAll('a')
            .cast<Element?>()
            .firstWhere(
              (a) => (a?.text.trim().toLowerCase() ?? '').contains('next'),
              orElse: () => null,
            );
    if (nextAnchor != null) {
      nextUrl = resolveHref(pageUrl, nextAnchor.attributes['href']);
    }

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: nextUrl,
      strategy: FetchStrategy.webnovelCom,
    );
  }
}
