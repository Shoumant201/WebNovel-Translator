import 'package:flutter/material.dart';

import '../../data/database.dart';

class NovelCard extends StatelessWidget {
  final Novel novel;
  final int chapterCount;
  final int translatedCount;
  final bool isFetching;
  final VoidCallback onTap;

  const NovelCard({
    super.key,
    required this.novel,
    required this.chapterCount,
    required this.translatedCount,
    required this.isFetching,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      novel.title,
                      style: theme.textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isFetching)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (novel.autoFetchNext)
                    Icon(
                      Icons.autorenew,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (novel.siteHost != null)
                Text(
                  novel.siteHost!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                '$translatedCount / $chapterCount chapters translated',
                style: theme.textTheme.bodySmall,
              ),
              if (novel.contextSummary.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  novel.contextSummary,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
