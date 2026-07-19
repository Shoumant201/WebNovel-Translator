import '../models/enums.dart';

/// The outcome of fetching+parsing a single chapter page.
class ChapterFetchResult {
  final bool success;
  final String? title;
  final String? bodyText; // plain text, paragraphs separated by \n\n
  final String? nextChapterUrl;
  final FetchStrategy strategy;
  final String? error;

  ChapterFetchResult.ok({
    required this.title,
    required this.bodyText,
    required this.nextChapterUrl,
    required this.strategy,
  }) : success = true,
       error = null;

  ChapterFetchResult.fail(this.error, {this.strategy = FetchStrategy.unknown})
    : success = false,
      title = null,
      bodyText = null,
      nextChapterUrl = null;
}
