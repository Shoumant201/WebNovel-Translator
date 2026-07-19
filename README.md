# Webnovel Translator

A Flutter app for reading translated webnovels: paste a chapter link, it
fetches the raw text, translates it with your choice of translation providers, and can keep
auto-fetching subsequent chapters as they're published. Each novel builds
up its own "context" (a lightweight name/terminology glossary) automatically
as chapters are translated.

## Features

- 📚 **Multi-site support**: Works with RoyalRoad, ScribbleHub, WuxiaWorld, WebNovel.com, 69shuba, and more
- 🔄 **Auto-fetch**: Automatically fetches subsequent chapters as they're published
- 🌐 **Multiple translation providers**: Microsoft Translator, Google Translate, DeepL, and LibreTranslate with smart fallback
- 📝 **Context building**: Maintains character names and terminology across chapters
- 🔧 **Manual extraction**: WebView-based fallback for sites with anti-bot protection
- 💾 **Offline reading**: All chapters stored locally in SQLite
- ⚙️ **Easy configuration**: Simple settings UI to manage translation API keys

## Translation Providers

The app supports multiple translation services with automatic fallback:

| Provider | Free Tier | Setup Time | Best For |
|----------|-----------|------------|----------|
| **Microsoft Translator** | 2M chars/month | 10 min | Most generous (recommended) |
| **Google Translate** | 500K chars/month | 15 min | Wide language support |
| **DeepL** | 500K chars/month | 5 min | Highest quality |
| **LibreTranslate** | Unlimited* | 0 min | No configuration needed |

*Public instances may have rate limits

**Total potential**: 3M+ characters/month = 600-1000 chapters/month!

Configure providers in Settings (gear icon) for best results. See [MULTI_PROVIDER_TRANSLATION_SETUP.md](docs/MULTI_PROVIDER_TRANSLATION_SETUP.md) for detailed setup.

## Manual Extraction Feature

When automatic fetching fails (e.g., HTTP 403 errors, JavaScript-rendered content, CAPTCHA), use the **Manual Extract** feature:

1. Click the web icon on failed chapters
2. Navigate to the chapter in the built-in browser
3. Click "Extract Chapter" button
4. Content is automatically parsed and translated

Perfect for sites like 69shuba with strong anti-bot protection. See [MANUAL_EXTRACT_FEATURE.md](docs/MANUAL_EXTRACT_FEATURE.md) for details.

## Architecture

```
lib/
  models/enums.dart              ChapterStatus, FetchStrategy
  data/database.dart             Drift schema: Novels, Chapters, AppSettings
  services/
    chapter_fetch_service.dart   HTTP fetch + delegates to a parser
    scrapers/                    One parser per site + generic fallback
    translation_service.dart     LibreTranslate client (multi-endpoint fallback, chunking)
    context_builder_service.dart Heuristic glossary/context builder
  repositories/novel_repository.dart   Orchestrates fetch -> translate -> context -> auto-next
  providers.dart                 Riverpod wiring
  ui/screens, ui/widgets         Library, novel detail, reader
```

The repository layer (`NovelRepository`) is the only place that knows about
the full pipeline; everything else is a narrow, swappable piece. That's
deliberate — you can add a new site parser, swap LibreTranslate for another
engine, or later add cloud sync, without touching the others.

## First-time setup

This project uses [Drift](https://drift.simonbinder.eu/) for local storage,
which needs a one-time code-generation step.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

That generates `lib/data/database.g.dart` (not checked in). Re-run
`build_runner` any time you change `database.dart`.

## Translation backend (LibreTranslate)

By default the app tries, in order:
1. A custom endpoint you configure (e.g. your own self-hosted instance)
2. `https://libretranslate.de`
3. `https://translate.terraprint.co`
4. `https://libretranslate.com`

Public instances are free but rate-limited and occasionally down. For
serious/sustained use, self-host LibreTranslate (a single Docker command)
and set it as the custom endpoint:

```bash
docker run -ti -p 5000:5000 libretranslate/libretranslate
```

Then point the app at `http://<your-host>:5000` — wire this through
`TranslationService.customEndpoint` (a Settings screen to edit this from the
UI is a natural next addition; the field already exists on the service).

## Adding support for another site

Implement `ChapterParser` (see `lib/services/scrapers/royalroad_parser.dart`
for a template), then register it in `ChapterFetchService._parsers`. Put more
specific parsers before the generic fallback — order matters.

## Known limitations / next steps

- Sites that render chapter text via client-side JS (rather than in the
  initial HTML) won't work with the current HTTP-based fetcher — a headless
  browser/webview fetch would be needed for those.
- The "context" glossary is heuristic (repeated capitalized phrases), not
  LLM-based, to keep the whole pipeline on free APIs. It's meant to keep
  naming visibly consistent chapter-to-chapter, not to be a literary summary.
- Local-only storage now (SQLite via Drift); the repository/database split
  was kept clean specifically so a cloud-sync layer can be added later
  without reworking the fetch/translate pipeline.
- No authentication/paywall handling — works only for chapters that are
  freely readable without login.
