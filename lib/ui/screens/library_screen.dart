import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers.dart';
import '../widgets/add_novel_dialog.dart';
import '../widgets/novel_card.dart';
import 'novel_detail_screen.dart';
import 'settings_screen.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  Future<void> _addNovel(BuildContext context, WidgetRef ref) async {
    final result = await AddNovelDialog.show(context);
    if (result == null) return;

    final repo = ref.read(novelRepositoryProvider);
    final activeFetches = ref.read(activeFetchesProvider.notifier);

    // Kick off the add flow without blocking the UI thread; the library
    // list updates live via the stream provider as chapters come in.
    final tempId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    activeFetches.update((s) => {...s, tempId});

    try {
      await repo.addNovelFromUrl(
        url: result['url'] as String,
        titleOverride: (result['title'] as String).isEmpty
            ? null
            : result['title'] as String,
        targetLang: result['targetLang'] as String,
        autoFetchNext: result['autoFetch'] as bool,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add novel: $e')));
      }
    } finally {
      activeFetches.update((s) => {...s}..remove(tempId));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Novels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Translation Settings',
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: novelsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error loading library: $err')),
        data: (novels) {
          if (novels.isEmpty) {
            return _EmptyState(onAdd: () => _addNovel(context, ref));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 340,
              mainAxisExtent: 168,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: novels.length,
            itemBuilder: (context, index) {
              final novel = novels[index];
              return _NovelCardWithChapters(novel: novel);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addNovel(context, ref),
        icon: const Icon(Icons.add_link),
        label: const Text('Add novel'),
      ),
    );
  }
}

class _NovelCardWithChapters extends ConsumerWidget {
  final Novel novel;
  const _NovelCardWithChapters({required this.novel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersForNovelProvider(novel.id));
    final activeFetches = ref.watch(activeFetchesProvider);

    final chapterCount = chaptersAsync.value?.length ?? 0;
    final translatedCount =
        chaptersAsync.value
            ?.where((c) => c.status == ChapterStatus.translated)
            .length ??
        0;
    final isFetching =
        chaptersAsync.value?.any(
          (c) =>
              c.status == ChapterStatus.fetching ||
              c.status == ChapterStatus.translating,
        ) ??
        false;

    return NovelCard(
      novel: novel,
      chapterCount: chapterCount,
      translatedCount: translatedCount,
      isFetching: isFetching || activeFetches.isNotEmpty && chapterCount == 0,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NovelDetailScreen(novelId: novel.id),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text('No novels yet', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Paste a link to any chapter and it will be fetched, translated, '
              'and kept up to date automatically.',
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_link),
            label: const Text('Add your first novel'),
          ),
        ],
      ),
    );
  }
}
