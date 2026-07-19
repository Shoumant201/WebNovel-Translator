import 'package:html/dom.dart';

import '../../models/enums.dart';
import '../fetch_result.dart';
import 'chapter_parser.dart';

/// Parser for 69shuba.com (69书吧) - a popular Chinese web novel site.
///
/// Page structure (from live HTML inspection):
///
///   <div class="txtnav">
///     <h1 class="hide720">第1章 标题</h1>
///     <div class="txtinfo hide720">…</div>   ← date / author
///     <div id="txtright">…</div>             ← right-side ad
///     第1章 标题                              ← plain-text repeat of title
///     <br><br>
///     paragraph text...                       ← actual chapter body
///     <br><br>
///     <div class="contentadv">…</div>         ← mid-content ad
///     more text...
///     <br><br>
///     <div class="bottom-ad">…</div>
///   </div>
///
/// Strategy:
///  1. Remove all known noise elements (ads, nav, scripts) from the DOM.
///  2. Walk the remaining child nodes of .txtnav, converting <br> → '\n'
///     and collecting text nodes, to faithfully preserve paragraph breaks.
///  3. Clean up the result (strip chapter-title repeat, extra whitespace, etc.)
class Shuba69Parser implements ChapterParser {
  @override
  bool matches(String host) {
    return host.contains('69shuba') ||
        host.contains('69shu') ||
        host.contains('www.69shu.com') ||
        host.contains('m.69shu.com');
  }

  @override
  ChapterFetchResult parse(Document document, Uri pageUrl) {
    final title = _extractTitle(document);
    final bodyText = _extractContent(document, title);

    if (bodyText == null || bodyText.length < 100) {
      return ChapterFetchResult.fail(
        '69shuba parser could not find chapter content',
        strategy: FetchStrategy.shuba69,
      );
    }

    final nextChapterUrl = _findNextChapterLink(document, pageUrl);

    return ChapterFetchResult.ok(
      title: title,
      bodyText: bodyText,
      nextChapterUrl: nextChapterUrl,
      strategy: FetchStrategy.shuba69,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Title extraction
  // ─────────────────────────────────────────────────────────────────────────

  String? _extractTitle(Document document) {
    // Prefer the <h1> inside .txtnav (most specific).
    final txtnav = document.querySelector('.txtnav');
    if (txtnav != null) {
      final h1 = txtnav.querySelector('h1');
      if (h1 != null) {
        final t = h1.text.trim();
        if (t.isNotEmpty) return t;
      }
    }

    for (final sel in ['.title h1', 'h1', '.reader-title', '#content h1']) {
      final el = document.querySelector(sel);
      if (el != null) {
        final t = el.text.trim();
        if (t.isNotEmpty) return t;
      }
    }

    // Fallback: strip site suffix from <title> tag.
    final pageTitle = document.querySelector('title')?.text.trim() ?? '';
    // Typical format: "书名-第N章 章标题-69书吧"
    final parts = pageTitle.split('-');
    if (parts.length >= 2) {
      return parts[parts.length - 2].trim();
    }
    return pageTitle.isNotEmpty ? pageTitle : null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Content extraction
  // ─────────────────────────────────────────────────────────────────────────

  String? _extractContent(Document document, String? title) {
    final txtnav = document.querySelector('.txtnav');
    if (txtnav != null) {
      final result = _extractFromTxtnav(txtnav);
      if (result != null && result.length > 100) {
        return _cleanContent(result, title);
      }
    }

    // Fallback: try other common containers.
    for (final sel in [
      '#content',
      '.content',
      '#chapter_content',
      '.chapter-content',
      '#txt',
      '.txt',
    ]) {
      final el = document.querySelector(sel);
      if (el != null) {
        _removeNoise(el);
        final text = _brAwareText(el);
        if (text.length > 100) {
          return _cleanContent(text, title);
        }
      }
    }

    return _findLargestTextBlock(document, title);
  }

  /// Extracts text from .txtnav using a structure-aware walk that converts
  /// <br> tags to newlines — critical because 69shuba uses <br><br> for
  /// paragraph breaks rather than <p> tags.
  String? _extractFromTxtnav(Element txtnav) {
    // 1. Remove all known noise child elements in-place before walking.
    _removeNoise(txtnav);

    // 2. Get the inner HTML and manually parse it to extract only text content
    final html = txtnav.innerHtml;

    // Split by <br><br> or <br> <br> to get paragraphs
    var content = html
        .replaceAll(RegExp(r'<br\s*/?>\s*<br\s*/?>'), '\n\n')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Remove all remaining HTML tags
    content = content.replaceAll(RegExp(r'<[^>]+>'), '');

    // Decode HTML entities
    content = _decodeHtmlEntities(content);

    return content.trim().isEmpty ? null : content.trim();
  }

  /// Recursively walks DOM nodes, converting <br> to '\n' and collecting
  /// text node content. Skips structural/UI elements entirely.
  void _walkNodes(Node node, StringBuffer buffer) {
    if (node is Element) {
      final tag = node.localName?.toLowerCase() ?? '';

      // Skip elements that are purely UI / non-content.
      if (_isNoiseElement(node)) return;

      if (tag == 'br') {
        buffer.write('\n');
        return;
      }

      // For container elements, recurse into children.
      for (final child in node.nodes) {
        _walkNodes(child, buffer);
      }
    } else if (node is Text) {
      final text = node.text;
      // Skip pure-whitespace text nodes.
      if (text.trim().isNotEmpty) {
        buffer.write(text);
      }
    }
  }

  /// Remove known noise elements from [el] before text extraction.
  void _removeNoise(Element el) {
    const noiseSelectors = [
      'script',
      'style',
      'noscript',
      '.contentadv',
      '.bottom-ad',
      '.bottom-ad2',
      '#txtright', // Right-side ad slot
      '.tools', // Toolbar: 书页/收藏/目录/设置
      '.txtinfo', // Date / author line (extracted separately as title)
      '.bread', // Breadcrumb navigation
      '.page1', // Prev/Next chapter navigation buttons
      '.yueduad1',
      '#ad-3-2-container',
      '#ad-first-slot-pc',
      '#ad-second-slot-pc',
      '#ad-third-slot-pc',
      '#bg-ssp-pre-10878',
      '#bg-ssp-10878-580739652242',
      '#bg-ssp-pre-11534',
      '#bg-ssp-11534-142996992063',
      'h1', // Title already extracted; exclude from body
      'ins', // Ad tags
      'iframe', // Ad iframes
      'div[id^="bg-ssp"]', // Background SSP ads
      'div[id^="ad-"]', // Any ad divs
    ];
    for (final sel in noiseSelectors) {
      for (final node in el.querySelectorAll(sel)) {
        node.remove();
      }
    }
  }

  /// Returns true if [el] should be skipped during node walking (noise/UI).
  bool _isNoiseElement(Element el) {
    final tag = el.localName?.toLowerCase() ?? '';
    if (['script', 'style', 'noscript', 'ins'].contains(tag)) return true;

    final cls = el.attributes['class'] ?? '';
    final id = el.attributes['id'] ?? '';

    const noiseClasses = [
      'contentadv',
      'bottom-ad',
      'bottom-ad2',
      'tools',
      'txtinfo',
      'bread',
      'page1',
      'yueduad1',
      'setbox',
      'top_Scroll',
      'modelbg',
      'modbg',
      'md-modal',
      'md-overlay',
    ];
    const noiseIds = ['txtright', 'ad-3-2-container', 'baocuo', 'tuijian'];

    for (final c in noiseClasses) {
      if (cls.contains(c)) return true;
    }
    for (final i in noiseIds) {
      if (id == i) return true;
    }
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fallback: <br>-aware text from any element
  // ─────────────────────────────────────────────────────────────────────────

  String _brAwareText(Element el) {
    final buffer = StringBuffer();
    _walkNodes(el, buffer);
    return buffer.toString().trim();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fallback: largest text block heuristic
  // ─────────────────────────────────────────────────────────────────────────

  String? _findLargestTextBlock(Document document, String? title) {
    String? largest;
    int maxLength = 0;

    for (final div in document.querySelectorAll('div, article, section')) {
      _removeNoise(div);
      final text = _brAwareText(div);
      if (text.length > maxLength && text.length > 200) {
        final linkText = div
            .querySelectorAll('a')
            .map((a) => a.text)
            .join()
            .length;
        final linkDensity = linkText / (text.length + 1);
        if (linkDensity < 0.3) {
          largest = text;
          maxLength = text.length;
        }
      }
    }

    return largest != null ? _cleanContent(largest, title) : null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Post-processing
  // ─────────────────────────────────────────────────────────────────────────

  String _cleanContent(String text, String? title) {
    String cleaned = text;

    // 0. Decode HTML entities first (handles \u003C style escaping)
    cleaned = _decodeHtmlEntities(cleaned);

    // 1. Strip the plain-text chapter-title repeat that 69shuba inlines
    //    at the start of .txtnav (e.g. "第1章 1：伦敦孤儿" on its own line).
    if (title != null && title.isNotEmpty) {
      // Remove it whether it appears at the start or mid-content.
      cleaned = cleaned.replaceAll(title, '');
    }

    // 2. Strip common site watermarks and noise strings.
    final patterns = [
      RegExp(r'69书吧.*?最快更新', multiLine: true, dotAll: true),
      RegExp(r'www\.69shu(?:ba)?\.com'),
      RegExp(r'章节错误.*?点此报送', multiLine: true, dotAll: true),
      RegExp(r'加入书签.*?方便阅读', multiLine: true, dotAll: true),
      RegExp(r'手机用户请.*?阅读', multiLine: true, dotAll: true),
      RegExp(r'小贴士：.*', multiLine: true),
      RegExp(r'Copyright\s*\d{4}.*', multiLine: true),
      RegExp(r'\(本章完\)'),
      RegExp(r'请记住.*?地址'),
      // Remove JavaScript variable declarations
      RegExp(r'var\s+\w+\s*=\s*\{[^}]*\}', multiLine: true),
      // Remove chapter number lines that appear as standalone noise.
      RegExp(r'^\s*第\d+章\s*$', multiLine: true),
      // Remove date/time stamps
      RegExp(r'\d{4}-\d{2}-\d{2}'),
      // Remove "作者：" lines
      RegExp(r'作者：[^\n]*'),
    ];

    for (final p in patterns) {
      cleaned = cleaned.replaceAll(p, '');
    }

    // 3. Normalise line endings: collapse 3+ consecutive newlines to 2.
    cleaned = cleaned.replaceAll(RegExp(r'\r\n'), '\n');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    // Collapse spaces within a line (but don't collapse across newlines).
    cleaned = cleaned
        .split('\n')
        .map((l) {
          return l.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
        })
        .where((l) => l.isNotEmpty)
        .join('\n');
    // After per-line trimming, collapse blank lines again.
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  /// Decodes common HTML entities and escaped characters
  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ')
        // Handle unicode escape sequences like \u003C
        .replaceAll(RegExp(r'\\u003[Cc]'), '<')
        .replaceAll(RegExp(r'\\u003[Ee]'), '>')
        .replaceAll(RegExp(r'\\u0022'), '"');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Next-chapter link
  // ─────────────────────────────────────────────────────────────────────────

  String? _findNextChapterLink(Document document, Uri pageUrl) {
    // 69shuba navigation is inside .page1 — look there first.
    final page1 = document.querySelector('.page1');
    if (page1 != null) {
      for (final a in page1.querySelectorAll('a')) {
        final text = a.text.trim();
        if (text.contains('下一章') || text.contains('下一页')) {
          final resolved = resolveHref(pageUrl, a.attributes['href']);
          if (resolved != null && resolved != pageUrl.toString()) {
            return resolved;
          }
        }
      }
    }

    // Also check the bookinfo JS object which has next_page pre-baked.
    // Pattern: next_page: "https://www.69shuba.com/txt/90442/40755364"
    final scripts = document.querySelectorAll('script');
    for (final script in scripts) {
      final src = script.text;
      final match = RegExp(
        r'''next_page\s*:\s*["']([^"']+)["']''',
      ).firstMatch(src);
      if (match != null) {
        final url = match.group(1)!.trim();
        if (url.isNotEmpty && url != pageUrl.toString()) return url;
      }
    }

    // Fallback: scan all links for Chinese "next chapter" text.
    for (final a in document.querySelectorAll('a')) {
      final text = a.text.trim();
      if (text.contains('下一章') || text.contains('下一页')) {
        final resolved = resolveHref(pageUrl, a.attributes['href']);
        if (resolved != null && resolved != pageUrl.toString()) {
          return resolved;
        }
      }
    }

    return null;
  }
}
