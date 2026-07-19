import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'deepl_translator_service.dart';
import 'google_translator_service.dart';
import 'microsoft_translator_service.dart';

/// Result of a translation attempt.
class TranslationResult {
  final bool success;
  final String? translatedText;
  final String? error;
  final String? endpointUsed;

  TranslationResult.ok(this.translatedText, this.endpointUsed)
    : success = true,
      error = null;

  TranslationResult.fail(this.error)
    : success = false,
      translatedText = null,
      endpointUsed = null;
}

/// Enum for translation provider types
enum TranslationProvider { microsoft, google, deepl, libretranslate }

extension TranslationProviderExt on TranslationProvider {
  String get displayName {
    switch (this) {
      case TranslationProvider.microsoft:
        return 'Microsoft Translator';
      case TranslationProvider.google:
        return 'Google Translate';
      case TranslationProvider.deepl:
        return 'DeepL';
      case TranslationProvider.libretranslate:
        return 'LibreTranslate';
    }
  }

  String get freeQuota {
    switch (this) {
      case TranslationProvider.microsoft:
        return '2M chars/month';
      case TranslationProvider.google:
        return '500K chars/month';
      case TranslationProvider.deepl:
        return '500K chars/month';
      case TranslationProvider.libretranslate:
        return 'Unlimited*';
    }
  }
}

/// Multi-provider translation service with smart fallback.
/// Supports Microsoft Translator, Google Translate, DeepL, and LibreTranslate.
/// Tries providers in order of preference until one succeeds.
class TranslationService {
  final http.Client _client;

  /// Known public LibreTranslate instances, tried as last resort.
  static const List<String> defaultPublicEndpoints = [
    'https://libretranslate.de',
    'https://translate.terraprint.co',
    'https://libretranslate.com',
  ];

  /// Max characters sent per request; LibreTranslate instances often cap
  /// request body size, and very long chapters translate more reliably
  /// in chunks anyway.
  static const int chunkSize = 3500;

  // Configured providers
  MicrosoftTranslatorService? _microsoftService;
  GoogleTranslatorService? _googleService;
  DeepLTranslatorService? _deeplService;

  String? customLibreTranslateEndpoint;
  String? libreTranslateApiKey;

  TranslationService({http.Client? client})
    : _client = client ?? http.Client() {
    _loadProviderConfigs();
  }

  /// Load provider configurations from SharedPreferences
  Future<void> _loadProviderConfigs() async {
    final prefs = await SharedPreferences.getInstance();

    // Microsoft
    final msKey = prefs.getString('microsoft_api_key');
    final msRegion = prefs.getString('microsoft_region');
    if (msKey != null &&
        msKey.isNotEmpty &&
        msRegion != null &&
        msRegion.isNotEmpty) {
      _microsoftService = MicrosoftTranslatorService(
        apiKey: msKey,
        region: msRegion,
        client: _client,
      );
    }

    // Google
    final googleKey = prefs.getString('google_api_key');
    if (googleKey != null && googleKey.isNotEmpty) {
      _googleService = GoogleTranslatorService(
        apiKey: googleKey,
        client: _client,
      );
    }

    // DeepL
    final deeplKey = prefs.getString('deepl_api_key');
    if (deeplKey != null && deeplKey.isNotEmpty) {
      _deeplService = DeepLTranslatorService(apiKey: deeplKey, client: _client);
    }

    // LibreTranslate
    customLibreTranslateEndpoint = prefs.getString('libretranslate_endpoint');
    libreTranslateApiKey = prefs.getString('libretranslate_api_key');
  }

  /// Reload provider configurations (call after settings change)
  Future<void> reloadConfigs() => _loadProviderConfigs();

  List<String> get _libreTranslateEndpoints => [
    if (customLibreTranslateEndpoint != null &&
        customLibreTranslateEndpoint!.trim().isNotEmpty)
      customLibreTranslateEndpoint!.trim(),
    ...defaultPublicEndpoints,
  ];

  /// Translates [text] from [sourceLang] ("auto" allowed) to [targetLang].
  /// Tries providers in order: Microsoft -> Google -> DeepL -> LibreTranslate.
  /// Splits long text into paragraph-respecting chunks and rejoins them.
  ///
  /// If [preferredProvider] is specified, tries that provider first before fallback.
  Future<TranslationResult> translate({
    required String text,
    required String targetLang,
    String sourceLang = 'auto',
    String? preferredProvider,
  }) async {
    if (text.trim().isEmpty) {
      return TranslationResult.ok('', null);
    }

    final chunks = _splitIntoChunks(text, chunkSize);
    final providers = <String>[];

    // If user specified a preferred provider, try it first
    if (preferredProvider != null) {
      final result = await _tryProvider(
        preferredProvider,
        chunks,
        targetLang,
        sourceLang,
        providers,
      );
      if (result != null) return result;
    }

    // Try Microsoft Translator first (2M chars/month free)
    if (_microsoftService != null && preferredProvider != 'microsoft') {
      final result = await _tryProvider(
        'microsoft',
        chunks,
        targetLang,
        sourceLang,
        providers,
      );
      if (result != null) return result;
    }

    // Try Google Translate (500K chars/month free)
    if (_googleService != null && preferredProvider != 'google') {
      final result = await _tryProvider(
        'google',
        chunks,
        targetLang,
        sourceLang,
        providers,
      );
      if (result != null) return result;
    }

    // Try DeepL (500K chars/month free, best quality)
    if (_deeplService != null && preferredProvider != 'deepl') {
      final result = await _tryProvider(
        'deepl',
        chunks,
        targetLang,
        sourceLang,
        providers,
      );
      if (result != null) return result;
    }

    // Try LibreTranslate endpoints as last resort
    if (preferredProvider != 'libretranslate') {
      final result = await _tryLibreTranslate(
        chunks,
        targetLang,
        sourceLang,
        providers,
      );
      if (result != null) return result;
    }

    // All providers failed
    return TranslationResult.fail(
      'All translation providers failed.\n'
      'Tried: ${providers.join(', ')}\n\n'
      'Tips:\n'
      '• Configure API keys in Settings for Microsoft/Google/DeepL\n'
      '• Public LibreTranslate instances may be rate-limited or down\n'
      '• Check your internet connection',
    );
  }

  Future<TranslationResult?> _tryProvider(
    String providerName,
    List<String> chunks,
    String targetLang,
    String sourceLang,
    List<String> providers,
  ) async {
    try {
      final translatedChunks = <String>[];

      for (final chunk in chunks) {
        String translated;

        switch (providerName) {
          case 'microsoft':
            if (_microsoftService == null) return null;
            translated = await _microsoftService!.translate(
              text: chunk,
              targetLang: targetLang,
              sourceLang: sourceLang,
            );
            break;
          case 'google':
            if (_googleService == null) return null;
            translated = await _googleService!.translate(
              text: chunk,
              targetLang: targetLang,
              sourceLang: sourceLang,
            );
            break;
          case 'deepl':
            if (_deeplService == null) return null;
            translated = await _deeplService!.translate(
              text: chunk,
              targetLang: targetLang,
              sourceLang: sourceLang,
            );
            break;
          default:
            return null;
        }

        translatedChunks.add(translated);
      }

      final providerDisplayName = providerName == 'microsoft'
          ? 'Microsoft Translator'
          : providerName == 'google'
          ? 'Google Translate'
          : 'DeepL';

      return TranslationResult.ok(
        translatedChunks.join('\n\n'),
        providerDisplayName,
      );
    } catch (e) {
      providers.add('$providerName (failed: $e)');
      return null;
    }
  }

  Future<TranslationResult?> _tryLibreTranslate(
    List<String> chunks,
    String targetLang,
    String sourceLang,
    List<String> providers,
  ) async {
    final endpoints = _libreTranslateEndpoints;

    for (final endpoint in endpoints) {
      try {
        final translatedChunks = <String>[];
        for (final chunk in chunks) {
          final translated = await _translateChunkLibreTranslate(
            endpoint: endpoint,
            text: chunk,
            source: sourceLang,
            target: targetLang,
          );
          translatedChunks.add(translated);
        }
        return TranslationResult.ok(
          translatedChunks.join('\n\n'),
          'LibreTranslate ($endpoint)',
        );
      } catch (e) {
        providers.add('LibreTranslate ($endpoint): $e');
        continue;
      }
    }

    return null;
  }

  Future<String> _translateChunkLibreTranslate({
    required String endpoint,
    required String text,
    required String source,
    required String target,
  }) async {
    final uri = Uri.parse('$endpoint/translate');
    final body = {
      'q': text,
      'source': source,
      'target': target,
      'format': 'text',
      if (libreTranslateApiKey != null && libreTranslateApiKey!.isNotEmpty)
        'api_key': libreTranslateApiKey,
    };

    final response = await _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'HTTP ${response.statusCode} from $endpoint: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body);
    final translated = decoded['translatedText'];
    if (translated is! String) {
      throw Exception('Unexpected response shape from $endpoint');
    }
    return translated;
  }

  /// Splits text into chunks no larger than [maxLen], breaking on paragraph
  /// boundaries (\n\n) where possible so sentences aren't cut mid-way.
  List<String> _splitIntoChunks(String text, int maxLen) {
    if (text.length <= maxLen) return [text];

    final paragraphs = text.split('\n\n');
    final chunks = <String>[];
    var current = StringBuffer();

    for (final para in paragraphs) {
      if (current.length + para.length + 2 > maxLen && current.isNotEmpty) {
        chunks.add(current.toString());
        current = StringBuffer();
      }
      if (para.length > maxLen) {
        // Single paragraph longer than maxLen: hard-split it.
        var remaining = para;
        while (remaining.length > maxLen) {
          chunks.add(remaining.substring(0, maxLen));
          remaining = remaining.substring(maxLen);
        }
        current.write(remaining);
      } else {
        if (current.isNotEmpty) current.write('\n\n');
        current.write(para);
      }
    }
    if (current.isNotEmpty) chunks.add(current.toString());
    return chunks;
  }

  void dispose() => _client.close();
}
