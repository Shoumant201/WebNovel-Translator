# Contributing to Webnovel Translator

Thank you for your interest in contributing to Webnovel Translator! We welcome contributions from the community to help make this the best open-source tool for translating web novels.

Here are some guidelines to help you get started.

## Code of Conduct

By participating in this project, you agree to abide by our [Code of Conduct](CODE_OF_CONDUCT.md).

## How Can I Contribute?

### Reporting Bugs

If you find a bug:
1. Search the [Issue Tracker](https://github.com/Shoumant/webnovel_translator/issues) to see if it has already been reported.
2. If not, open a new issue using the **Bug Report** template.
3. Provide as much detail as possible, including:
   - Steps to reproduce
   - Expected vs actual behavior
   - Novel URL/site where it happened
   - Screenshots/logs if applicable

### Suggesting Enhancements

If you have ideas for new features or improvements:
1. Search active issues to ensure it's not already suggested.
2. Open a feature request issue.
3. Describe the problem it solves and how you envision the feature working.

### Contributing Code (Pull Requests)

We welcome pull requests! To contribute code:
1. Fork the repository.
2. Create a new branch for your feature or bug fix: `git checkout -b feature/your-feature-name` or `bugfix/issue-description`.
3. Make your changes.
4. Ensure the code compiles and passes analysis with `flutter analyze`.
5. Format your code using `dart format .`.
6. Submit a Pull Request targeting the `main` branch.

## Development Setup

This is a Flutter application. To run the project locally:

1. Install the [Flutter SDK](https://flutter.dev/docs/get-started/install).
2. Clone your fork of this repository.
3. Run `flutter pub get` to download dependencies.
4. Run the code generation for local storage schemas:
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```
5. Run the application:
   ```bash
   flutter run
   ```

## Coding Conventions

- **State Management**: We use Riverpod. Ensure providers are scoped cleanly in `lib/providers.dart`.
- **Parsing/Scrapers**: Site-specific novel parsers must implement the `ChapterParser` interface in `lib/services/scrapers/chapter_parser.dart` and be registered in `ChapterFetchService`.
- **Formatting**: Always format your code before committing:
  ```bash
  dart format .
  ```
