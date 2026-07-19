import 'package:flutter/material.dart';

/// Collects a chapter URL, optional title override, and target language
/// from the user. Returns a map with the values, or null if cancelled.
class AddNovelDialog extends StatefulWidget {
  const AddNovelDialog({super.key});

  @override
  State<AddNovelDialog> createState() => _AddNovelDialogState();

  static Future<Map<String, dynamic>?> show(BuildContext context) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const AddNovelDialog(),
    );
  }
}

class _AddNovelDialogState extends State<AddNovelDialog> {
  final _urlController = TextEditingController();
  final _titleController = TextEditingController();
  String _targetLang = 'en';
  bool _autoFetch = true;

  static const _languages = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'hi': 'Hindi',
  };

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add novel from chapter link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Chapter URL',
                hintText: 'https://www.royalroad.com/fiction/.../chapter-1',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Novel title (optional — auto-detected if blank)',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _targetLang,
              decoration: const InputDecoration(labelText: 'Translate to'),
              items: _languages.entries
                  .map(
                    (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _targetLang = v ?? 'en'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-fetch next chapter'),
              subtitle: const Text(
                'Keep translating new chapters as they\'re found',
              ),
              value: _autoFetch,
              onChanged: (v) => setState(() => _autoFetch = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final url = _urlController.text.trim();
            if (url.isEmpty) return;
            Navigator.of(context).pop({
              'url': url,
              'title': _titleController.text.trim(),
              'targetLang': _targetLang,
              'autoFetch': _autoFetch,
            });
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
