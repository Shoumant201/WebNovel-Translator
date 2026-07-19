# WebNovel Translator 📖 🌐

[![Flutter CI](https://github.com/Shoumant/webnovel_translator/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/Shoumant/webnovel_translator/actions/workflows/flutter_ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Flutter Version](https://img.shields.io/badge/Flutter-Stable-blue.svg)](https://flutter.dev)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

Translate web novels from popular Chinese and English websites directly into your native language while preserving all original HTML layouts and chapter formatting. 

WebNovel Translator is a cross-platform (Android, iOS, desktop) app built with Flutter. It utilizes multiple AI translation providers with automatic failover, local SQLite storage for offline reading, a WebView-based manual extractor to bypass anti-bot protections, and a smart, localized glossary context builder.

---

## ⚡ Key Features

- **🌍 Smart Formatting Preservation**: Automatically translates chapter content paragraph by paragraph, keeping the original HTML styling (like colors, bolding, line breaks) intact.
- **🔄 Multi-Provider Translation**: Connects to **Microsoft Translator**, **Google Translate**, **DeepL API**, and **LibreTranslate** with smart automatic fallback if one fails or hits a rate limit.
- **📝 Automated Context Builder**: Automatically identifies repeated terminology and character names across chapters to build a local dictionary. It then applies these consistent mappings during future translations.
- **🔧 Manual WebView Extractor**: Built-in browser interface that allows you to bypass strict Cloudflare/anti-bot protection by loading chapters via browser engine, then extracting and parsing content instantly.
- **💾 Offline Reading**: Fully offline-first design. All translated chapters, novel lists, and glossary data are cached locally using Drift (SQLite).
- **🚀 Cross-Platform Support**: Ready to compile for Linux, macOS, Windows, Android, and iOS.

---

## 📸 Main Interface

| Novels Library | Chapter Reader | Setup Settings |
|:---:|:---:|:---:|
| _[Add Novel card screenshot]_ | _[Translated HTML layout screenshot]_ | _[API Key configurations screenshot]_ |

*Note: Pinned screenshots will be updated soon. Add a screenshot or demo GIF here in your repository settings!*

---

## 🚀 Quick Start (Under 2 Minutes)

To run the application locally in development mode:

### 1. Prerequisites
Make sure you have [Flutter SDK](https://flutter.dev/docs/get-started/install) installed on your system.

### 2. Setup & Install
Clone the repository and install the dependencies:
```bash
git clone https://github.com/Shoumant/webnovel_translator.git
cd webnovel_translator
flutter pub get
```

### 3. Generate Database Classes
Generate local SQLite mapping schemas using `build_runner`:
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Run the App
Launch the app on your connected device or desktop emulator:
```bash
flutter run
```

---

## ⚙️ Supported Sites

The app features modular parsing strategies. It automatically detects and processes the page layouts of:
*   **RoyalRoad** (`royalroad.com`)
*   **ScribbleHub** (`scribblehub.com`)
*   **WuxiaWorld** (`wuxiaworld.com`)
*   **WebNovel.com** (`webnovel.com`)
*   **69shuba** (`69shuba.com` / `69shu.com`) - *Requires WebView manual extraction*
*   **Generic Fallback**: High-performance link density heuristic parses novel contents on unsupported/new websites automatically.

For custom scraping setups, see [Adding support for another site](docs/PARSER_IMPROVEMENTS.md).

---

## 🤖 Translation Providers

Configure the API keys for the services you want to use in the settings gear icon. If one fails, the pipeline fails-over to the next active provider:

| Provider | Free Monthly Tier | Best For | Setup Guide |
|---|---|---|---|
| **Microsoft Translator** | 2,000,000 chars | High volume / Great default | [Setup Guide](docs/MULTI_PROVIDER_TRANSLATION_SETUP.md) |
| **Google Translate** | 500,000 chars | Wide language coverage | [Setup Guide](docs/MULTI_PROVIDER_TRANSLATION_SETUP.md) |
| **DeepL Translate** | 500,000 chars | Highest semantic quality | [Setup Guide](docs/MULTI_PROVIDER_TRANSLATION_SETUP.md) |
| **LibreTranslate** | Unlimited (Self-hosted) | No API key / Free self-hosting | [Setup Guide](docs/MULTI_PROVIDER_TRANSLATION_SETUP.md) |

---

## 🗺️ Project Roadmap

- [ ] **EPUB & PDF Export**: Export translated novels directly to readable ebook formats.
- [ ] **Google Drive Backup**: Sync local SQLite databases and glossaries across multiple devices.
- [ ] **AI-driven Context Translation**: Upgrade the glossary builder to use local LLM API integration.
- [ ] **OCR Chapter Translation**: Translate scan/image-based chapters using local OCR.
- [ ] **Dark Mode custom styling**: Configurable reader backgrounds, line-heights, and fonts.

---

## 🤝 Contributing

We love contributions! Whether it is adding a new scraper strategy, writing translation provider classes, or fixing UI bugs:
1. Review the [Code of Conduct](CODE_OF_CONDUCT.md).
2. Check out the [Contributing Guidelines](CONTRIBUTING.md) for how to set up your branch and submit pull requests.

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
