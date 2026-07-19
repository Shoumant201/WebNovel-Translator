import 'dart:convert';
import 'package:http/http.dart' as http;

/// Microsoft Azure Translator Text API service.
/// Free tier: 2 million characters/month
/// Supports 130+ languages
class MicrosoftTranslatorService {
  final http.Client _client;
  final String apiKey;
  final String region;

  static const String endpoint =
      'https://api.cognitive.microsofttranslator.com';

  MicrosoftTranslatorService({
    required this.apiKey,
    required this.region,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Translates text using Microsoft Azure Translator.
  /// Returns the translated text or throws an exception.
  Future<String> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
  }) async {
    if (text.trim().isEmpty) return '';

    final uri = Uri.parse('$endpoint/translate').replace(
      queryParameters: {
        'api-version': '3.0',
        'to': _convertLangCode(targetLang),
        if (sourceLang != 'auto') 'from': _convertLangCode(sourceLang),
      },
    );

    final response = await _client
        .post(
          uri,
          headers: {
            'Ocp-Apim-Subscription-Key': apiKey,
            'Ocp-Apim-Subscription-Region': region,
            'Content-Type': 'application/json',
          },
          body: jsonEncode([
            {'text': text},
          ]),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 401) {
      throw Exception('Invalid API key or region');
    }

    if (response.statusCode == 429) {
      throw Exception('Rate limit exceeded');
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Microsoft Translator failed: ${response.statusCode} - ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as List;
    if (decoded.isEmpty) {
      throw Exception('Empty response from Microsoft Translator');
    }

    final translations = decoded[0]['translations'] as List;
    if (translations.isEmpty) {
      throw Exception('No translations returned');
    }

    return translations[0]['text'] as String;
  }

  /// Tests if the API key and region are valid.
  Future<bool> testConnection() async {
    try {
      await translate(text: 'Hello', targetLang: 'es');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Converts standard language codes to Microsoft's format.
  String _convertLangCode(String code) {
    // Microsoft uses standard ISO 639-1 codes
    // Map common variations
    final codeMap = {
      'zh': 'zh-Hans', // Simplified Chinese
      'zh-CN': 'zh-Hans',
      'zh-TW': 'zh-Hant',
      'pt': 'pt-BR',
    };
    return codeMap[code] ?? code;
  }

  void dispose() => _client.close();
}
