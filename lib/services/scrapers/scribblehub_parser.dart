import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// ScribbleHub chapter pages use #chp_raw for the body and a "Next Chapter"
/// button with class `.btn-next` (or text match fallback).
class ScribbleHubParser implements ChapterParser {
  @override
  bool matches(String host) => host.contains('scribblehub.com');

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final contentDiv =
        document.querySelector('#chp_raw') ??
        document.querySelector('.chp_raw') ??
        document.querySelector('.chapter-content');

    if (contentDiv == null) {
      return ChapterFetchResult.fail(
        'Could not locate #chp_raw on ScribbleHub page',
        strategy: FetchStrategy.scribbleHub,
      );
    }

    final paragraphs = contentDiv.querySelectorAll('p');
    final bodyText = paragraphs.isNotEmpty
        ? joinParagraphs(paragraphs)
        : contentDiv.text.trim();

    final title =
        document.querySelector('.chapter-title')?.text.trim() ??
        document.querySelector('title')?.text.trim();

    String? nextUrl;
    final nextAnchor =
        document.querySelector('.btn-next') ??
        document
            .querySelectorAll('a')
            .cast<Element?>()
            .firstWhere(
              (a) =>
                  (a?.text.trim().toLowerCase() ?? '').contains('next chapter'),
              orElse: () => null,
            );
    if (nextAnchor != null) {
      nextUrl = resolveHref(pageUrl, nextAnchor.attributes['href']);
    }

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: nextUrl,
      strategy: FetchStrategy.scribbleHub,
    );
  }
}
