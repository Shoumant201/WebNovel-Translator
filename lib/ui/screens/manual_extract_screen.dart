import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:webview_flutter/webview_flutter.dart';

import '../../providers.dart';
import '../../services/scrapers/chapter_parser.dart';

/// A screen that displays a chapter URL in a WebView and allows manual
/// extraction of chapter content. This is useful when automatic fetching
/// fails due to anti-bot protections or JavaScript-rendered content.
///
/// Flow:
/// 1. User navigates to the chapter URL in the WebView (handles redirects, cookies, etc.)
/// 2. User clicks "Extract Chapter" button
/// 3. App reads the current page's HTML from the WebView
/// 4. Parses the HTML using the appropriate parser
/// 5. Returns the extracted content to the caller
class ManualExtractScreen extends ConsumerStatefulWidget {
  final String initialUrl;
  final String novelId;
  final int chapterIndex;

  const ManualExtractScreen({
    super.key,
    required this.initialUrl,
    required this.novelId,
    required this.chapterIndex,
  });

  @override
  ConsumerState<ManualExtractScreen> createState() =>
      _ManualExtractScreenState();
}

class _ManualExtractScreenState extends ConsumerState<ManualExtractScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isExtracting = false;
  String? _currentUrl;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) async {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            // Get page title
            final title = await _controller.getTitle();
            setState(() {
              _pageTitle = title ?? '';
            });
          },
          onWebResourceError: (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: ${error.description}')),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.initialUrl));
  }

  Future<void> _extractChapter() async {
    setState(() => _isExtracting = true);

    try {
      // Get the current page's HTML content
      final html =
          await _controller.runJavaScriptReturningResult(
                'document.documentElement.outerHTML',
              )
              as String;

      // Decode JSON string to get the original HTML with all escape sequences resolved
      String cleanHtml;
      try {
        final decoded = jsonDecode(html);
        if (decoded is String) {
          cleanHtml = decoded;
        } else {
          cleanHtml = html;
        }
      } catch (_) {
        // Fallback to manual replacement if jsonDecode fails
        cleanHtml = html;
        if (cleanHtml.startsWith('"') && cleanHtml.endsWith('"')) {
          cleanHtml = cleanHtml.substring(1, cleanHtml.length - 1);
        }
        cleanHtml = cleanHtml
            .replaceAll(r'\"', '"')
            .replaceAll(r"\'", "'")
            .replaceAll(r'\n', '\n')
            .replaceAll(r'\t', '\t');
      }

      // Ensure common unicode escapes are decoded if they were not handled
      if (cleanHtml.contains(r'\u003')) {
        cleanHtml = cleanHtml
            .replaceAll(r'\u003C', '<')
            .replaceAll(r'\u003c', '<')
            .replaceAll(r'\u003E', '>')
            .replaceAll(r'\u003e', '>')
            .replaceAll(r'\u0022', '"');
      }

      // Parse the HTML
      final document = html_parser.parse(cleanHtml);
      final uri = Uri.parse(_currentUrl ?? widget.initialUrl);

      // Get the fetch service and find the appropriate parser
      final fetchService = ref.read(chapterFetchServiceProvider);
      final parsers = [...fetchService.parsers, fetchService.fallback];

      ChapterParser? selectedParser;
      for (final parser in parsers) {
        if (parser.matches(uri.host.toLowerCase())) {
          selectedParser = parser;
          break;
        }
      }

      if (selectedParser == null) {
        throw Exception('No parser found for ${uri.host}');
      }

      // Parse the document
      final result = selectedParser.parse(document, uri);

      if (!result.success ||
          result.bodyText == null ||
          result.bodyText!.isEmpty) {
        throw Exception(result.error ?? 'Failed to extract chapter content');
      }

      // Return the extracted data
      if (mounted) {
        Navigator.of(context).pop({
          'title': result.title ?? _pageTitle,
          'bodyText': result.bodyText,
          'nextChapterUrl': result.nextChapterUrl,
          'url': _currentUrl ?? widget.initialUrl,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to extract chapter: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manual Extract', style: TextStyle(fontSize: 16)),
            if (_pageTitle.isNotEmpty)
              Text(
                _pageTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: () => _controller.reload(),
            ),
        ],
      ),
      body: Column(
        children: [
          // URL bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentUrl ?? widget.initialUrl,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 20),
                  tooltip: 'Copy URL',
                  onPressed: () {
                    // Copy URL to clipboard (you may want to add clipboard package)
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'URL: ${_currentUrl ?? widget.initialUrl}',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          // WebView
          Expanded(child: WebViewWidget(controller: _controller)),
          // Navigation bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Back',
                    onPressed: () async {
                      if (await _controller.canGoBack()) {
                        _controller.goBack();
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    tooltip: 'Forward',
                    onPressed: () async {
                      if (await _controller.canGoForward()) {
                        _controller.goForward();
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _isExtracting || _isLoading
                          ? null
                          : _extractChapter,
                      icon: _isExtracting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.download),
                      label: Text(
                        _isExtracting ? 'Extracting...' : 'Extract Chapter',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
