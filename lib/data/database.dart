import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import '../models/enums.dart';

part 'database.g.dart';

/// A novel the user is tracking. `contextSummary` is auto-generated and
/// re-generated as more chapters are translated, so the translator has
/// consistent terminology (character names, honorifics, world terms, tone).
class Novels extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get originalLanguage =>
      text().withDefault(const Constant('auto'))();
  TextColumn get targetLanguage => text().withDefault(const Constant('en'))();
  TextColumn get sourceUrl =>
      text()(); // URL of the first/most recent chapter added
  TextColumn get siteHost => text().nullable()(); // e.g. www.royalroad.com
  TextColumn get coverUrl => text().nullable()();
  TextColumn get contextSummary => text().withDefault(const Constant(''))();
  TextColumn get glossaryJson =>
      text().withDefault(const Constant('{}'))(); // name -> translation map
  BoolColumn get autoFetchNext => boolean().withDefault(const Constant(true))();
  TextColumn get preferredTranslationProvider => text()
      .nullable()(); // 'microsoft', 'google', 'deepl', 'libretranslate', or null for auto
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// A single chapter belonging to a novel.
class Chapters extends Table {
  TextColumn get id => text()();
  TextColumn get novelId =>
      text().references(Novels, #id, onDelete: KeyAction.cascade)();
  IntColumn get chapterIndex => integer()(); // order within the novel, 0-based
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get sourceUrl => text()();
  TextColumn get nextChapterUrl => text().nullable()();
  TextColumn get rawText => text().withDefault(const Constant(''))();
  TextColumn get translatedText => text().withDefault(const Constant(''))();
  TextColumn get status =>
      textEnum<ChapterStatus>().withDefault(const Constant('pending'))();
  TextColumn get errorMessage => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key-value app settings (translation endpoint, api keys if any, etc).
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Novels, Chapters, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        // Add preferredTranslationProvider column to novels table
        await migrator.addColumn(novels, novels.preferredTranslationProvider);
      }
    },
  );

  // ---- Novel queries ----

  Future<List<Novel>> allNovels() => select(novels).get();

  Stream<List<Novel>> watchAllNovels() =>
      (select(novels)..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
          .watch();

  Future<Novel?> novelById(String id) =>
      (select(novels)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertNovel(NovelsCompanion novel) =>
      into(novels).insertOnConflictUpdate(novel);

  Future<void> deleteNovel(String id) =>
      (delete(novels)..where((t) => t.id.equals(id))).go();

  // ---- Chapter queries ----

  Stream<List<Chapter>> watchChaptersForNovel(String novelId) =>
      (select(chapters)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([(t) => OrderingTerm(expression: t.chapterIndex)]))
          .watch();

  Future<List<Chapter>> chaptersForNovel(String novelId) =>
      (select(chapters)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([(t) => OrderingTerm(expression: t.chapterIndex)]))
          .get();

  Future<Chapter?> chapterById(String id) =>
      (select(chapters)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Chapter?> latestChapterForNovel(String novelId) =>
      (select(chapters)
            ..where((t) => t.novelId.equals(novelId))
            ..orderBy([
              (t) => OrderingTerm(
                expression: t.chapterIndex,
                mode: OrderingMode.desc,
              ),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<void> upsertChapter(ChaptersCompanion chapter) =>
      into(chapters).insertOnConflictUpdate(chapter);

  Future<bool> chapterExistsForUrl(String novelId, String url) async {
    final existing =
        await (select(chapters)..where(
              (t) => t.novelId.equals(novelId) & t.sourceUrl.equals(url),
            ))
            .getSingleOrNull();
    return existing != null;
  }

  // ---- Settings ----

  Future<String?> getSetting(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) => into(
    appSettings,
  ).insertOnConflictUpdate(AppSettingsCompanion.insert(key: key, value: value));
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'webnovel_translator.sqlite'));
    // Ensures the bundled sqlite3 native lib is used on all platforms.
    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }
    return NativeDatabase.createInBackground(file);
  });
}
