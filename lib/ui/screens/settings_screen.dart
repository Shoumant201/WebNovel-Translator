import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers.dart';
import '../../services/deepl_translator_service.dart';
import '../../services/google_translator_service.dart';
import '../../services/microsoft_translator_service.dart';
import '../../services/translation_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Microsoft
  final _msKeyController = TextEditingController();
  final _msRegionController = TextEditingController();
  bool _msConfigured = false;

  // Google
  final _googleKeyController = TextEditingController();
  bool _googleConfigured = false;

  // DeepL
  final _deeplKeyController = TextEditingController();
  bool _deeplConfigured = false;

  // LibreTranslate
  final _libreEndpointController = TextEditingController();
  final _libreKeyController = TextEditingController();

  // Track which providers are currently being tested.
  // Using a Set avoids the risk of one flag accidentally affecting another.
  final Set<TranslationProvider> _testingProviders = {};

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _msKeyController.dispose();
    _msRegionController.dispose();
    _googleKeyController.dispose();
    _deeplKeyController.dispose();
    _libreEndpointController.dispose();
    _libreKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;
    setState(() {
      // Microsoft
      _msKeyController.text = prefs.getString('microsoft_api_key') ?? '';
      _msRegionController.text = prefs.getString('microsoft_region') ?? '';
      // 'Configured' only if the last Save & Test actually succeeded.
      _msConfigured = prefs.getBool('microsoft_test_passed') ?? false;

      // Google
      _googleKeyController.text = prefs.getString('google_api_key') ?? '';
      _googleConfigured = prefs.getBool('google_test_passed') ?? false;

      // DeepL
      _deeplKeyController.text = prefs.getString('deepl_api_key') ?? '';
      _deeplConfigured = prefs.getBool('deepl_test_passed') ?? false;

      // LibreTranslate
      _libreEndpointController.text =
          prefs.getString('libretranslate_endpoint') ?? '';
      _libreKeyController.text =
          prefs.getString('libretranslate_api_key') ?? '';

      _isLoading = false;
    });
  }

  bool _isTesting(TranslationProvider p) => _testingProviders.contains(p);

  Future<void> _saveAndTest(TranslationProvider provider) async {
    // Guard: don't allow re-entry while this provider is already testing.
    if (_isTesting(provider)) return;

    setState(() => _testingProviders.add(provider));

    final prefs = await SharedPreferences.getInstance();
    bool success = false;
    String? errorMessage;

    try {
      switch (provider) {
        case TranslationProvider.microsoft:
          final key = _msKeyController.text.trim();
          final region = _msRegionController.text.trim();
          await prefs.setString('microsoft_api_key', key);
          await prefs.setString('microsoft_region', region);

          if (key.isEmpty || region.isEmpty) {
            errorMessage = 'Please enter both API key and region.';
            await prefs.setBool('microsoft_test_passed', false);
            _msConfigured = false;
            break;
          }
          try {
            final service = MicrosoftTranslatorService(
              apiKey: key,
              region: region,
            );
            try {
              await service.translate(text: 'Hello', targetLang: 'es');
              success = true;
              _msConfigured = true;
            } finally {
              service.dispose();
            }
          } catch (e) {
            errorMessage = _cleanError(e);
            _msConfigured = false;
          }
          await prefs.setBool('microsoft_test_passed', success);

        case TranslationProvider.google:
          final key = _googleKeyController.text.trim();
          await prefs.setString('google_api_key', key);

          if (key.isEmpty) {
            errorMessage = 'Please enter your Google API key.';
            await prefs.setBool('google_test_passed', false);
            _googleConfigured = false;
            break;
          }
          try {
            final service = GoogleTranslatorService(apiKey: key);
            try {
              await service.translate(text: 'Hello', targetLang: 'es');
              success = true;
              _googleConfigured = true;
            } finally {
              service.dispose();
            }
          } catch (e) {
            errorMessage = _cleanError(e);
            _googleConfigured = false;
          }
          await prefs.setBool('google_test_passed', success);

        case TranslationProvider.deepl:
          final key = _deeplKeyController.text.trim();
          await prefs.setString('deepl_api_key', key);

          if (key.isEmpty) {
            errorMessage = 'Please enter your DeepL API key.';
            await prefs.setBool('deepl_test_passed', false);
            _deeplConfigured = false;
            break;
          }
          try {
            final service = DeepLTranslatorService(apiKey: key);
            try {
              await service.translate(text: 'Hello', targetLang: 'ES');
              success = true;
              _deeplConfigured = true;
            } finally {
              service.dispose();
            }
          } catch (e) {
            errorMessage = _cleanError(e);
            _deeplConfigured = false;
          }
          await prefs.setBool('deepl_test_passed', success);

        case TranslationProvider.libretranslate:
          await prefs.setString(
            'libretranslate_endpoint',
            _libreEndpointController.text.trim(),
          );
          await prefs.setString(
            'libretranslate_api_key',
            _libreKeyController.text.trim(),
          );
          // LibreTranslate saved; no live test needed (public instances vary).
          success = true;
      }

      // Notify the repository's translation service to pick up the new config.
      try {
        await ref
            .read(novelRepositoryProvider)
            .translationService
            .reloadConfigs();
      } catch (_) {
        // Non-fatal — the settings were saved; the reload will happen next use.
      }

      if (mounted) {
        final msg = success
            ? '${provider.displayName} configured successfully! ✓'
            : errorMessage != null
            ? '${provider.displayName}: $errorMessage'
            : '${provider.displayName}: Connection test failed. Check your API key and try again.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: success ? Colors.green[700] : Colors.red[700],
            duration: Duration(seconds: success ? 3 : 6),
            action: success
                ? null
                : SnackBarAction(
                    label: 'Setup Help',
                    textColor: Colors.white,
                    onPressed: () => _showHelpDialog(provider),
                  ),
          ),
        );
      }
    } catch (e) {
      // Unexpected error (e.g., SharedPreferences failure).
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error: ${_cleanError(e)}'),
            backgroundColor: Colors.red[800],
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      // Always clear the loading state for this specific provider only.
      if (mounted) {
        setState(() => _testingProviders.remove(provider));
      }
    }
  }

  /// Strips the leading "Exception: " prefix that Dart appends to thrown
  /// Exception objects, so the snackbar text is more readable.
  String _cleanError(Object e) {
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.substring('Exception: '.length);
    return s;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Translation Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Translation Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Configure translation providers to improve reliability and speed. '
            'Providers are tried in order: Microsoft → Google → DeepL → LibreTranslate.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Microsoft Translator
          _buildProviderCard(
            provider: TranslationProvider.microsoft,
            icon: Icons.translate,
            color: Colors.blue,
            configured: _msConfigured,
            children: [
              TextField(
                controller: _msKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter Microsoft Translator API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _msRegionController,
                decoration: const InputDecoration(
                  labelText: 'Region',
                  hintText: 'e.g., eastus, westus2, global',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showHelpDialog(TranslationProvider.microsoft),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('How to get API key'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Google Translate
          _buildProviderCard(
            provider: TranslationProvider.google,
            icon: Icons.g_translate,
            color: Colors.red,
            configured: _googleConfigured,
            children: [
              TextField(
                controller: _googleKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter Google Cloud Translation API key',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showHelpDialog(TranslationProvider.google),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('How to get API key'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // DeepL
          _buildProviderCard(
            provider: TranslationProvider.deepl,
            icon: Icons.auto_awesome,
            color: Colors.purple,
            configured: _deeplConfigured,
            children: [
              TextField(
                controller: _deeplKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Enter DeepL API key',
                  border: OutlineInputBorder(),
                  helperText: 'Free keys end with :fx',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _showHelpDialog(TranslationProvider.deepl),
                icon: const Icon(Icons.help_outline, size: 18),
                label: const Text('How to get API key'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // LibreTranslate (Custom)
          _buildProviderCard(
            provider: TranslationProvider.libretranslate,
            icon: Icons.public,
            color: Colors.green,
            configured: true, // Always available via public instances
            children: [
              TextField(
                controller: _libreEndpointController,
                decoration: const InputDecoration(
                  labelText: 'Custom Endpoint (Optional)',
                  hintText: 'e.g., http://localhost:5000',
                  border: OutlineInputBorder(),
                  helperText: 'Leave empty to use public instances',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _libreKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key (Optional)',
                  hintText: 'If your instance requires it',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard({
    required TranslationProvider provider,
    required IconData icon,
    required Color color,
    required bool configured,
    required List<Widget> children,
  }) {
    // Read the testing state ONCE per build so the button and icon are in sync.
    final isTesting = _isTesting(provider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        provider.freeQuota,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                if (configured)
                  const Chip(
                    label: Text('Configured', style: TextStyle(fontSize: 11)),
                    backgroundColor: Colors.green,
                    labelStyle: TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                // Disable only THIS button while it is testing; others remain active.
                onPressed: isTesting ? null : () => _saveAndTest(provider),
                icon: isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(isTesting ? 'Testing...' : 'Save & Test'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(TranslationProvider provider) {
    final helpTexts = {
      TranslationProvider.microsoft: '''
**Microsoft Azure Translator** (RECOMMENDED)

1. Go to https://portal.azure.com
2. Create free account (no credit card)
3. Click "Create a resource"
4. Search "Translator"
5. Choose Free F0 tier (2M chars/month)
6. Copy API key and region from "Keys and Endpoint"

Free: 2M chars/month forever
~400-650 chapters/month
''',
      TranslationProvider.google: '''
**Google Cloud Translation**

1. Go to https://cloud.google.com
2. Enable "Cloud Translation API"
3. Create API key in "Credentials"

Note: Requires credit card (won't charge for free tier)
Free: 500K chars/month forever
~100-165 chapters/month
''',
      TranslationProvider.deepl: '''
**DeepL API** (Best Quality)

1. Go to https://www.deepl.com/pro-api
2. Sign up for free account
3. Copy API key from account settings

Free keys end with :fx
Free: 500K chars/month
~100-165 chapters/month
Best quality for European languages
''',
      TranslationProvider.libretranslate: '''
**LibreTranslate**

Self-host for best performance:

```bash
docker run -ti -p 5000:5000 libretranslate/libretranslate
```

Then enter: http://localhost:5000

Or leave empty to use public instances (may be slow/rate-limited).
''',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setup ${provider.displayName}'),
        content: SingleChildScrollView(child: Text(helpTexts[provider] ?? '')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
