import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/database.dart';
import 'repositories/novel_repository.dart';
import 'services/chapter_fetch_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final chapterFetchServiceProvider = Provider<ChapterFetchService>((ref) {
  final service = ChapterFetchService();
  ref.onDispose(service.dispose);
  return service;
});

final novelRepositoryProvider = Provider<NovelRepository>((ref) {
  final db = ref.watch(databaseProvider);
  final repo = NovelRepository(db: db);
  ref.onDispose(repo.dispose);
  return repo;
});

/// Live list of all novels, most recently updated first.
final novelsStreamProvider = StreamProvider((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllNovels();
});

/// Live list of chapters for a given novel id.
final chaptersForNovelProvider = StreamProvider.family((ref, String novelId) {
  final db = ref.watch(databaseProvider);
  return db.watchChaptersForNovel(novelId);
});

/// Tracks which novel ids currently have an add/fetch operation in flight,
/// so the UI can show per-novel loading state without a global spinner.
final activeFetchesProvider = StateProvider<Set<String>>((ref) => {});
