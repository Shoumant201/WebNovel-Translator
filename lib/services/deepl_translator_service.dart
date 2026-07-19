import 'dart:convert';
import 'package:http/http.dart' as http;

/// DeepL Translation API service.
/// Free tier: 500,000 characters/month
/// Supports 32 languages (focus on European languages)
/// Known for highest quality translations
class DeepLTranslatorService {
  final http.Client _client;
  final String apiKey;

  // Free tier uses api-free.deepl.com (keys end with :fx)
  static const String freeEndpoint = 'https://api-free.deepl.com/v2/translate';
  // Paid tier uses api.deepl.com
  static const String paidEndpoint = 'https://api.deepl.com/v2/translate';

  DeepLTranslatorService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// Returns the correct endpoint based on the API key suffix.
  /// Free keys end with ':fx', paid keys do not.
  String get _endpoint =>
      apiKey.trim().endsWith(':fx') ? freeEndpoint : paidEndpoint;

  /// Translates text using DeepL API v2.
  /// Returns the translated text or throws an exception.
  Future<String> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) return '';

    final body = <String, dynamic>{
      // DeepL v2 expects "text" as an array of strings.
      'text': [text],
      'target_lang': _convertLangCode(targetLang),
    };

    if (sourceLang != 'auto') {
      body['source_lang'] = _convertLangCode(sourceLang, isSource: true);
    }

    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            // Modern DeepL API authentication: Authorization header.
            // The old 'auth_key' form field is deprecated and may return 403.
            'Authorization': 'DeepL-Auth-Key ${apiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 403) {
      // Give a more actionable message, including a hint about the key suffix.
      final hint = apiKey.trim().endsWith(':fx')
          ? ' (free key detected — using api-free.deepl.com)'
          : ' (paid key detected — using api.deepl.com)';
      throw Exception(
        'DeepL authentication failed (403). '
        'Check that your API key is correct and active.$hint\n'
        'Response: ${response.body}',
      );
    }

    if (response.statusCode == 456) {
      throw Exception('DeepL quota exceeded for this month.');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'DeepL failed: HTTP ${response.statusCode} — ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final translations = decoded['translations'] as List;

    if (translations.isEmpty) {
      throw Exception('DeepL returned an empty translations list.');
    }

    return translations[0]['text'] as String;
  }

  /// Tests if the API key is valid by translating a short test phrase.
  Future<bool> testConnection() async {
    try {
      await translate(text: 'Hello', targetLang: 'ES');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Converts standard language codes to DeepL's format.
  /// DeepL requires uppercase codes.
  /// [isSource] — source lang codes omit regional variants (e.g. just 'ZH').
  String _convertLangCode(String code, {bool isSource = false}) {
    final lower = code.toLowerCase();

    // Target-language map (regional variants allowed by DeepL).
    const targetMap = {
      'en': 'EN-US',
      'en-us': 'EN-US',
      'en-gb': 'EN-GB',
      'pt': 'PT-BR',
      'pt-br': 'PT-BR',
      'pt-pt': 'PT-PT',
      'zh': 'ZH',
      'zh-cn': 'ZH',
      'zh-tw': 'ZH',
      'es': 'ES',
      'fr': 'FR',
      'de': 'DE',
      'it': 'IT',
      'ja': 'JA',
      'ko': 'KO',
      'nl': 'NL',
      'pl': 'PL',
      'ru': 'RU',
      'ar': 'AR',
      'tr': 'TR',
      'sv': 'SV',
      'da': 'DA',
      'fi': 'FI',
      'nb': 'NB',
      'cs': 'CS',
      'sk': 'SK',
      'ro': 'RO',
      'hu': 'HU',
      'bg': 'BG',
      'el': 'EL',
      'lt': 'LT',
      'lv': 'LV',
      'et': 'ET',
      'uk': 'UK',
      'id': 'ID',
    };

    // Source langs don't use regional variants.
    if (isSource) {
      final mapped = targetMap[lower] ?? lower.toUpperCase();
      // Strip the regional part for source (EN-US → EN, PT-BR → PT).
      return mapped.contains('-') ? mapped.split('-').first : mapped;
    }

    return targetMap[lower] ?? lower.toUpperCase();
  }

  void dispose() => _client.close();
}
