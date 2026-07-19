import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import '../../models/enums.dart';
import '../../providers.dart';
import 'manual_extract_screen.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  final String novelId;
  final String initialChapterId;

  const ReaderScreen({
    super.key,
    required this.novelId,
    required this.initialChapterId,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late String _currentChapterId;
  double _fontSize = 17;
  bool _isLoadingNext = false;

  @override
  void initState() {
    super.initState();
    _currentChapterId = widget.initialChapterId;
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersForNovelProvider(widget.novelId));

    return chaptersAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, st) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (chapters) {
        if (chapters.isEmpty) {
          return const Scaffold(body: Center(child: Text('No chapters yet')));
        }
        final currentIndex = chapters.indexWhere(
          (c) => c.id == _currentChapterId,
        );
        final chapter = currentIndex >= 0
            ? chapters[currentIndex]
            : chapters.first;
        final hasPrev = currentIndex > 0;
        final hasNextInDb =
            currentIndex >= 0 && currentIndex < chapters.length - 1;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              chapter.title.isNotEmpty
                  ? chapter.title
                  : 'Chapter ${chapter.chapterIndex + 1}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.text_decrease),
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize - 1).clamp(12, 28)),
              ),
              IconButton(
                icon: const Icon(Icons.text_increase),
                onPressed: () =>
                    setState(() => _fontSize = (_fontSize + 1).clamp(12, 28)),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(child: _buildBody(chapter)),
                _NavigationBar(
                  hasPrev: hasPrev,
                  hasNext: hasNextInDb || chapter.nextChapterUrl != null,
                  isLoadingNext: _isLoadingNext,
                  onPrev: hasPrev
                      ? () => setState(
                          () =>
                              _currentChapterId = chapters[currentIndex - 1].id,
                        )
                      : null,
                  onNext: () => _goToNext(chapters, currentIndex),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(Chapter chapter) {
    switch (chapter.status) {
      case ChapterStatus.translated:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: SelectableText(
            chapter.translatedText,
            style: TextStyle(fontSize: _fontSize, height: 1.6),
          ),
        );
      case ChapterStatus.fetching:
      case ChapterStatus.translating:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Translating chapter…'),
            ],
          ),
        );
      case ChapterStatus.failed:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40, color: Colors.red),
                const SizedBox(height: 12),
                Text(
                  chapter.errorMessage ?? 'Failed to load chapter',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(novelRepositoryProvider)
                          .retryChapter(chapter.id),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => _openManualExtract(chapter),
                      icon: const Icon(Icons.web),
                      label: const Text('Manual Extract'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      default:
        return const Center(child: Text('Waiting to fetch…'));
    }
  }

  Future<void> _goToNext(List<Chapter> chapters, int currentIndex) async {
    if (currentIndex >= 0 && currentIndex < chapters.length - 1) {
      setState(() => _currentChapterId = chapters[currentIndex + 1].id);
      return;
    }

    // No next chapter stored yet: trigger a fetch of the next chapter via
    // the repository, then jump to it once it appears in the stream.
    setState(() => _isLoadingNext = true);
    try {
      await ref
          .read(novelRepositoryProvider)
          .fetchNextChapterFor(widget.novelId);
      final updated = await ref
          .read(databaseProvider)
          .chaptersForNovel(widget.novelId);
      if (updated.length > chapters.length) {
        setState(() => _currentChapterId = updated.last.id);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No next chapter found yet')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingNext = false);
    }
  }

  Future<void> _openManualExtract(Chapter chapter) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => ManualExtractScreen(
          initialUrl: chapter.sourceUrl,
          novelId: widget.novelId,
          chapterIndex: chapter.chapterIndex,
        ),
      ),
    );

    if (result != null && mounted) {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chapter extracted and translated successfully!'),
          ),
        );
      }
    }
  }
}

class _NavigationBar extends StatelessWidget {
  final bool hasPrev;
  final bool hasNext;
  final bool isLoadingNext;
  final VoidCallback? onPrev;
  final VoidCallback onNext;

  const _NavigationBar({
    required this.hasPrev,
    required this.hasNext,
    required this.isLoadingNext,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: hasNext && !isLoadingNext ? onNext : null,
              icon: isLoadingNext
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.chevron_right),
              label: Text(isLoadingNext ? 'Loading…' : 'Next'),
            ),
          ),
        ],
      ),
    );
  }
}
