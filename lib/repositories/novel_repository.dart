import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../models/enums.dart';
import '../services/chapter_fetch_service.dart';
import '../services/context_builder_service.dart';
import '../services/translation_service.dart';

/// High-level operations for adding novels and chapters. This is the single
/// place that orchestrates: fetch chapter HTML -> parse -> translate ->
/// update glossary/context -> optionally auto-fetch the next chapter.
///
/// Kept independent of Flutter widgets so it's easily unit-testable and so
/// a future cloud-sync layer can wrap/replace the AppDatabase calls without
/// touching this orchestration logic.
class NovelRepository {
  final AppDatabase db;
  final ChapterFetchService fetchService;
  final TranslationService translationService;
  final ContextBuilderService contextBuilder;
  final _uuid = const Uuid();

  NovelRepository({
    required this.db,
    ChapterFetchService? fetchService,
    TranslationService? translationService,
    ContextBuilderService? contextBuilder,
  }) : fetchService = fetchService ?? ChapterFetchService(),
       translationService = translationService ?? TranslationService(),
       contextBuilder = contextBuilder ?? ContextBuilderService();

  /// Adds a brand-new novel from its first chapter URL: fetches+translates
  /// chapter 0, creates the Novel row with an auto-generated title (from the
  /// page, if the user didn't supply one) and initial context.
  Future<String> addNovelFromUrl({
    required String url,
    String? titleOverride,
    String targetLang = 'en',
    bool autoFetchNext = true,
  }) async {
    final novelId = _uuid.v4();
    final host = Uri.tryParse(url)?.host;

    // Placeholder novel row so the UI can navigate immediately while the
    // first chapter fetches/translates in the background.
    await db.upsertNovel(
      NovelsCompanion.insert(
        id: novelId,
        title: titleOverride ?? 'New novel',
        sourceUrl: url,
        siteHost: Value(host),
        targetLanguage: Value(targetLang),
        autoFetchNext: Value(autoFetchNext),
      ),
    );

    await _fetchTranslateAndStore(
      novelId: novelId,
      url: url,
      chapterIndex: 0,
      targetLang: targetLang,
      isFirstChapter: true,
      titleOverrideForNovel: titleOverride,
    );

    return novelId;
  }

  /// Fetches, translates, and stores a single chapter, updates the novel's
  /// glossary/context, and — if autoFetchNext is enabled on the novel and a
  /// "next chapter" link was found — recursively continues.
  ///
  /// [maxAutoChapters] guards against runaway loops (e.g. a site whose
  /// "next" link points back to itself) by capping how many chapters a
  /// single call chain will auto-fetch.
  Future<void> fetchNextChapterFor(
    String novelId, {
    int maxAutoChapters = 50,
  }) async {
    final novel = await db.novelById(novelId);
    if (novel == null) return;
    final latest = await db.latestChapterForNovel(novelId);
    final url = latest?.nextChapterUrl;
    if (url == null || url.isEmpty) return;

    final alreadyExists = await db.chapterExistsForUrl(novelId, url);
    if (alreadyExists) return;

    await _fetchTranslateAndStore(
      novelId: novelId,
      url: url,
      chapterIndex: (latest?.chapterIndex ?? -1) + 1,
      targetLang: novel.targetLanguage,
      isFirstChapter: false,
      maxAutoChapters: maxAutoChapters,
    );
  }

  /// Manually re-fetch/retry a specific chapter (e.g. after a failure).
  Future<void> retryChapter(String chapterId) async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final novel = await db.novelById(chapter.novelId);
    if (novel == null) return;

    await _fetchTranslateAndStore(
      novelId: chapter.novelId,
      url: chapter.sourceUrl,
      chapterIndex: chapter.chapterIndex,
      targetLang: novel.targetLanguage,
      isFirstChapter: chapter.chapterIndex == 0,
      existingChapterId: chapterId,
      autoContinue: false,
    );
  }

  /// Store manually extracted chapter content (from WebView).
  /// Skips the fetch step and goes directly to translation.
  Future<void> storeManualExtract({
    required String chapterId,
    required String title,
    required String bodyText,
    String? nextChapterUrl,
    required String actualUrl,
  }) async {
    final chapter = await db.chapterById(chapterId);
    if (chapter == null) return;
    final novel = await db.novelById(chapter.novelId);
    if (novel == null) return;

    // Update chapter with extracted content and set to translating
    await db.upsertChapter(
      ChaptersCompanion(
        id: Value(chapterId),
        novelId: Value(chapter.novelId),
        chapterIndex: Value(chapter.chapterIndex),
        sourceUrl: Value(
          actualUrl,
        ), // Update to actual URL in case of redirects
        title: Value(title),
        rawText: Value(bodyText),
        nextChapterUrl: Value(nextChapterUrl),
        status: const Value(ChapterStatus.translating),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Translate the content
    final translationResult = await translationService.translate(
      text: bodyText,
      targetLang: novel.targetLanguage,
      sourceLang: novel.originalLanguage,
      preferredProvider: novel.preferredTranslationProvider,
    );

    if (!translationResult.success) {
      await db.upsertChapter(
        ChaptersCompanion(
          id: Value(chapterId),
          novelId: Value(chapter.novelId),
          chapterIndex: Value(chapter.chapterIndex),
          sourceUrl: Value(actualUrl),
          status: const Value(ChapterStatus.failed),
          errorMessage: Value('Translation failed: ${translationResult.error}'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    // Mark as translated and store the result
    await db.upsertChapter(
      ChaptersCompanion(
        id: Value(chapterId),
        novelId: Value(chapter.novelId),
        chapterIndex: Value(chapter.chapterIndex),
        sourceUrl: Value(actualUrl),
        translatedText: Value(translationResult.translatedText ?? ''),
        status: const Value(ChapterStatus.translated),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // Update novel context
    await _updateNovelContext(
      novelId: chapter.novelId,
      translatedText: translationResult.translatedText ?? '',
      isFirstChapter: chapter.chapterIndex == 0,
      fetchedTitle: title,
      titleOverrideForNovel: null,
    );
  }

  Future<void> setAutoFetch(String novelId, bool enabled) async {
    final novel = await db.novelById(novelId);
    if (novel == null) return;
    await db.upsertNovel(
      NovelsCompanion(
        id: Value(novelId),
        title: Value(novel.title),
        sourceUrl: Value(novel.sourceUrl),
        autoFetchNext: Value(enabled),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> deleteNovel(String novelId) => db.deleteNovel(novelId);

  // ---- internal orchestration ----

  Future<void> _fetchTranslateAndStore({
    required String novelId,
    required String url,
    required int chapterIndex,
    required String targetLang,
    required bool isFirstChapter,
    String? existingChapterId,
    String? titleOverrideForNovel,
    bool autoContinue = true,
    int maxAutoChapters = 50,
  }) async {
    if (maxAutoChapters <= 0) return;

    final chapterId = existingChapterId ?? _uuid.v4();

    await db.upsertChapter(
      ChaptersCompanion.insert(
        id: chapterId,
        novelId: novelId,
        chapterIndex: chapterIndex,
        sourceUrl: url,
        status: const Value(ChapterStatus.fetching),
      ),
    );

    final fetchResult = await fetchService.fetchChapter(url);

    if (!fetchResult.success) {
      await db.upsertChapter(
        ChaptersCompanion(
          id: Value(chapterId),
          novelId: Value(novelId),
          chapterIndex: Value(chapterIndex),
          sourceUrl: Value(url),
          status: const Value(ChapterStatus.failed),
          errorMessage: Value(fetchResult.error),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await db.upsertChapter(
      ChaptersCompanion(
        id: Value(chapterId),
        novelId: Value(novelId),
        chapterIndex: Value(chapterIndex),
        sourceUrl: Value(url),
        title: Value(fetchResult.title ?? ''),
        rawText: Value(fetchResult.bodyText ?? ''),
        nextChapterUrl: Value(fetchResult.nextChapterUrl),
        status: const Value(ChapterStatus.translating),
        updatedAt: Value(DateTime.now()),
      ),
    );

    final novel = await db.novelById(novelId);
    final translationResult = await translationService.translate(
      text: fetchResult.bodyText ?? '',
      targetLang: targetLang,
      sourceLang: novel?.originalLanguage ?? 'auto',
      preferredProvider: novel?.preferredTranslationProvider,
    );

    if (!translationResult.success) {
      await db.upsertChapter(
        ChaptersCompanion(
          id: Value(chapterId),
          novelId: Value(novelId),
          chapterIndex: Value(chapterIndex),
          sourceUrl: Value(url),
          status: const Value(ChapterStatus.failed),
          errorMessage: Value('Translation failed: ${translationResult.error}'),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await db.upsertChapter(
      ChaptersCompanion(
        id: Value(chapterId),
        novelId: Value(novelId),
        chapterIndex: Value(chapterIndex),
        sourceUrl: Value(url),
        translatedText: Value(translationResult.translatedText ?? ''),
        status: const Value(ChapterStatus.translated),
        updatedAt: Value(DateTime.now()),
      ),
    );

    await _updateNovelContext(
      novelId: novelId,
      translatedText: translationResult.translatedText ?? '',
      isFirstChapter: isFirstChapter,
      fetchedTitle: fetchResult.title,
      titleOverrideForNovel: titleOverrideForNovel,
    );

    if (autoContinue) {
      final refreshedNovel = await db.novelById(novelId);
      if (refreshedNovel != null &&
          refreshedNovel.autoFetchNext &&
          fetchResult.nextChapterUrl != null &&
          fetchResult.nextChapterUrl!.isNotEmpty) {
        final nextAlreadyExists = await db.chapterExistsForUrl(
          novelId,
          fetchResult.nextChapterUrl!,
        );
        if (!nextAlreadyExists) {
          await _fetchTranslateAndStore(
            novelId: novelId,
            url: fetchResult.nextChapterUrl!,
            chapterIndex: chapterIndex + 1,
            targetLang: targetLang,
            isFirstChapter: false,
            maxAutoChapters: maxAutoChapters - 1,
          );
        }
      }
    }
  }

  Future<void> _updateNovelContext({
    required String novelId,
    required String translatedText,
    required bool isFirstChapter,
    String? fetchedTitle,
    String? titleOverrideForNovel,
  }) async {
    final novel = await db.novelById(novelId);
    if (novel == null) return;

    final existingGlossary = contextBuilder.decodeGlossary(novel.glossaryJson);
    final mergedGlossary = contextBuilder.extractAndMergeGlossary(
      translatedText,
      existingGlossary,
    );

    final chapters = await db.chaptersForNovel(novelId);
    final translatedCount = chapters
        .where((c) => c.status == ChapterStatus.translated)
        .length;

    // Auto-derive a title the first time, if the user didn't provide one.
    String newTitle = novel.title;
    if (isFirstChapter &&
        (titleOverrideForNovel == null ||
            titleOverrideForNovel.trim().isEmpty) &&
        fetchedTitle != null &&
        fetchedTitle.trim().isNotEmpty) {
      newTitle = _cleanTitle(fetchedTitle);
    }

    final summary = contextBuilder.buildSummary(
      novelTitle: newTitle,
      chapterCount: translatedCount,
      glossary: mergedGlossary,
    );

    await db.upsertNovel(
      NovelsCompanion(
        id: Value(novelId),
        title: Value(newTitle),
        sourceUrl: Value(novel.sourceUrl),
        glossaryJson: Value(contextBuilder.encodeGlossary(mergedGlossary)),
        contextSummary: Value(summary),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  String _cleanTitle(String rawTitle) {
    // Strip common site suffixes like " - Chapter 1 | RoyalRoad" etc.
    var t = rawTitle;
    for (final sep in [' | ', ' - Chapter', ' Chapter ', ' — ']) {
      final idx = t.indexOf(sep);
      if (idx > 0) t = t.substring(0, idx);
    }
    return t.trim();
  }

  void dispose() {
    fetchService.dispose();
    translationService.dispose();
  }
}
