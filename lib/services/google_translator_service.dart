import 'dart:convert';
import 'package:http/http.dart' as http;

/// Google Cloud Translation API service.
/// Free tier: 500,000 characters/month
/// Supports 135+ languages
class GoogleTranslatorService {
  final http.Client _client;
  final String apiKey;

  static const String endpoint =
      'https://translation.googleapis.com/language/translate/v2';

  GoogleTranslatorService({required this.apiKey, http.Client? client})
    : _client = client ?? http.Client();

  /// Translates text using Google Cloud Translation API.
  /// Returns the translated text or throws an exception.
  Future<String> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) return '';

    final uri = Uri.parse(endpoint).replace(
      queryParameters: {
        'key': apiKey,
        'q': text,
        'target': _convertLangCode(targetLang),
        if (sourceLang != 'auto') 'source': _convertLangCode(sourceLang),
        'format': 'text',
      },
    );

    final response = await _client
        .post(uri)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 400) {
      throw Exception('Invalid API key or parameters');
    }

    if (response.statusCode == 403) {
      throw Exception('API key not authorized or billing not enabled');
    }

    if (response.statusCode == 429) {
      throw Exception('Quota exceeded');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Google Translate failed: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final translations = decoded['data']['translations'] as List;

    if (translations.isEmpty) {
      throw Exception('No translations returned');
    }

    return translations[0]['translatedText'] as String;
  }

  /// Tests if the API key is valid.
  Future<bool> testConnection() async {
    try {
      await translate(text: 'Hello', targetLang: 'es');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Converts standard language codes to Google's format.
  String _convertLangCode(String code) {
    // Google uses standard ISO 639-1 codes
    // Map common variations
    final codeMap = {
      'zh-CN': 'zh-CN',
      'zh-TW': 'zh-TW',
      'zh': 'zh-CN', // Default to Simplified Chinese
    };
    return codeMap[code] ?? code;
  }

  void dispose() => _client.close();
}
