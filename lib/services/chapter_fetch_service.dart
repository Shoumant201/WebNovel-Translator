import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'fetch_result.dart';
import 'scrapers/chapter_parser.dart';
import 'scrapers/generic_parser.dart';
import 'scrapers/royalroad_parser.dart';
import 'scrapers/scribblehub_parser.dart';
import 'scrapers/shuba69_parser.dart';
import 'scrapers/webnovel_com_parser.dart';
import 'scrapers/wuxiaworld_parser.dart';

/// Fetches a chapter page over HTTP and parses it with the best-matching
/// site-specific parser, falling back to the generic heuristic parser.
class ChapterFetchService {
  final http.Client _client;

  // Order matters: more specific parsers are checked before the generic one.
  final List<ChapterParser> _parsers = [
    RoyalRoadParser(),
    WebNovelComParser(),
    ScribbleHubParser(),
    WuxiaWorldParser(),
    Shuba69Parser(),
  ];
  final GenericParser _fallback = GenericParser();

  // Public getters for manual extraction
  List<ChapterParser> get parsers => _parsers;
  GenericParser get fallback => _fallback;

  ChapterFetchService({http.Client? client})
    : _client = client ?? http.Client();

  static const _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36';

  Future<ChapterFetchResult> fetchChapter(String url) async {
    final Uri uri;
    try {
      uri = Uri.parse(url.trim());
    } catch (_) {
      return ChapterFetchResult.fail('Invalid URL: $url');
    }

    http.Response response;
    try {
      // Build headers with additional anti-bot protection for certain sites
      final headers = _buildHeaders(uri.host);

      response = await _client
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 25));
    } catch (e) {
      return ChapterFetchResult.fail('Network error fetching chapter: $e');
    }

    if (response.statusCode != 200) {
      return ChapterFetchResult.fail(
        'Server returned HTTP ${response.statusCode} for $url',
      );
    }

    final document = html_parser.parse(response.body);
    final host = uri.host.toLowerCase();

    for (final parser in _parsers) {
      if (parser.matches(host)) {
        final result = parser.parse(document, uri);
        if (result.success && (result.bodyText?.isNotEmpty ?? false)) {
          return result;
        }
        // If the specific parser matched the host but failed to extract
        // content, fall through to generic as a best-effort recovery.
        break;
      }
    }

    return _fallback.parse(document, uri);
  }

  /// Build headers appropriate for the target site.
  /// Some sites like 69shuba require additional headers to bypass anti-bot protection.
  Map<String, String> _buildHeaders(String host) {
    final baseHeaders = {
      'User-Agent': _userAgent,
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7',
      'Accept-Encoding': 'gzip, deflate, br',
      'Connection': 'keep-alive',
      'Upgrade-Insecure-Requests': '1',
      'Sec-Fetch-Dest': 'document',
      'Sec-Fetch-Mode': 'navigate',
      'Sec-Fetch-Site': 'none',
      'Cache-Control': 'max-age=0',
    };

    // Additional headers for Chinese novel sites like 69shuba
    if (host.contains('69shu') || host.contains('shuba')) {
      baseHeaders['Referer'] = 'https://www.69shu.com/';
      baseHeaders['Origin'] = 'https://www.69shu.com';
    }

    return baseHeaders;
  }

  void dispose() => _client.close();
}
