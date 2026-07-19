import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers.dart';
import 'manual_extract_screen.dart';
import 'reader_screen.dart';

class NovelDetailScreen extends ConsumerWidget {
  final String novelId;
  const NovelDetailScreen({super.key, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelAsync = ref.watch(databaseProvider).novelById(novelId);
    final chaptersAsync = ref.watch(chaptersForNovelProvider(novelId));

    return FutureBuilder<Novel?>(
      future: novelAsync,
      builder: (context, novelSnapshot) {
        final novel = novelSnapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(novel?.title ?? 'Loading…'),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete novel',
                onPressed: () => _confirmDelete(context, ref),
              ),
            ],
          ),
          body: chaptersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Error: $e')),
            data: (chapters) {
              return CustomScrollView(
                slivers: [
                  if (novel != null)
                    SliverToBoxAdapter(child: _NovelHeader(novel: novel)),
                  if (chapters.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('Fetching first chapter…')),
                    )
                  else
                    SliverList.builder(
                      itemCount: chapters.length,
                      itemBuilder: (context, index) {
                        final chapter = chapters[index];
                        return _ChapterTile(
                          chapter: chapter,
                          novelId: novelId,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReaderScreen(
                                  novelId: novelId,
                                  initialChapterId: chapter.id,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete this novel?'),
        content: const Text(
          'All fetched and translated chapters will be removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(novelRepositoryProvider).deleteNovel(novelId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class _NovelHeader extends ConsumerWidget {
  final Novel novel;
  const _NovelHeader({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (novel.contextSummary.isNotEmpty) ...[
            Text('Context', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                novel.contextSummary,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 12),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-fetch next chapter'),
            subtitle: const Text(
              'New chapters are translated automatically as they\'re published',
            ),
            value: novel.autoFetchNext,
            onChanged: (enabled) => ref
                .read(novelRepositoryProvider)
                .setAutoFetch(novel.id, enabled),
          ),
          const SizedBox(height: 12),
          _TranslationProviderSelector(novel: novel),
        ],
      ),
    );
  }
}

class _TranslationProviderSelector extends ConsumerWidget {
  final Novel novel;
  const _TranslationProviderSelector({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currentProvider = novel.preferredTranslationProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Translation Provider', style: theme.textTheme.labelLarge),
        const SizedBox(height: 4),
        Text(
          'Choose which translation service to use for this novel',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String?>(
          initialValue: currentProvider,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.auto_mode, size: 20),
                  SizedBox(width: 8),
                  Text('Auto (Smart Fallback)'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'microsoft',
              child: Row(
                children: [
                  Icon(Icons.translate, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Microsoft Translator'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'google',
              child: Row(
                children: [
                  Icon(Icons.g_translate, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Google Translate'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'deepl',
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 20, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('DeepL (Best Quality)'),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'libretranslate',
              child: Row(
                children: [
                  Icon(Icons.public, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text('LibreTranslate'),
                ],
              ),
            ),
          ],
          onChanged: (newProvider) => _updateProvider(ref, newProvider),
        ),
      ],
    );
  }

  Future<void> _updateProvider(WidgetRef ref, String? newProvider) async {
    final db = ref.read(databaseProvider);
    await db.upsertNovel(
      NovelsCompanion(
        id: Value(novel.id),
        title: Value(novel.title),
        sourceUrl: Value(novel.sourceUrl),
        preferredTranslationProvider: Value(newProvider),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}

class _ChapterTile extends ConsumerWidget {
  final Chapter chapter;
  final String novelId;
  final VoidCallback onTap;
  const _ChapterTile({
    required this.chapter,
    required this.novelId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (icon, color) = switch (chapter.status) {
      ChapterStatus.translated => (Icons.check_circle, Colors.green),
      ChapterStatus.failed => (Icons.error_outline, Colors.red),
      ChapterStatus.fetching ||
      ChapterStatus.translating => (Icons.hourglass_top, Colors.orange),
      _ => (Icons.circle_outlined, Colors.grey),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        chapter.title.isNotEmpty
            ? chapter.title
            : 'Chapter ${chapter.chapterIndex + 1}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle:
          chapter.status == ChapterStatus.failed && chapter.errorMessage != null
          ? Text(
              chapter.errorMessage!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: chapter.status == ChapterStatus.failed
          ? IconButton(
              icon: const Icon(Icons.web),
              tooltip: 'Manual Extract',
              onPressed: () => _openManualExtract(context, ref),
            )
          : null,
      onTap: chapter.status == ChapterStatus.translated ? onTap : null,
      enabled:
          chapter.status == ChapterStatus.translated ||
          chapter.status == ChapterStatus.failed,
    );
  }

  Future<void> _openManualExtract(BuildContext context, WidgetRef ref) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ManualExtractScreen(
          initialUrl: chapter.sourceUrl,
          novelId: novelId,
          chapterIndex: chapter.chapterIndex,
        ),
      ),
    );

    if (result != null && context.mounted) {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Processing extracted chapter...')),
      );

      // Store the manually extracted content
      await ref
          .read(novelRepositoryProvider)
          .storeManualExtract(
            chapterId: chapter.id,
            title: result['title'] as String? ?? '',
            bodyText: result['bodyText'] as String,
            nextChapterUrl: result['nextChapterUrl'] as String?,
            actualUrl: result['url'] as String,
          );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter extracted and translated successfully!'),
          ),
        );
      }
    }
  }
}
