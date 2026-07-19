# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-07-19

### Added
- Multi-site scraper parsing (RoyalRoad, ScribbleHub, WuxiaWorld, Webnovel.com, 69shuba, and generic fallback).
- Multi-provider translation service supporting Microsoft Translator, Google Translate, DeepL API, and LibreTranslate with automatic failover.
- Context Glossary Builder to dynamically construct name/terminology mappings and build consistent translation templates.
- Manual extraction fallback using WebView to bypass strict cloud protection (Cloudflare/anti-bot) and extract chapters.
- Local SQLite database using Drift for offline reading support.
- Detailed translation configuration UI.

### Fixed
- Fixed WebView extraction parsing bug caused by JSON-escaped HTML Unicode characters.
- Fixed analyzer warnings and deprecated Flutter API calls.
