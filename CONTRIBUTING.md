# Contributing to Itsyhome

Thanks for your interest in contributing! Itsyhome is a native macOS menu bar app for HomeKit and Home Assistant, built with Swift, AppKit (as a Mac Catalyst plugin) and SwiftUI.

## Getting started

### Requirements

- macOS 14.0 or later
- Xcode 15.0 or later (CI uses Xcode 16.4)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) – `brew install xcodegen`
- For HomeKit mode: an Apple Developer account with the HomeKit entitlement
- For Home Assistant mode: a Home Assistant server with a long-lived access token (no Apple Developer account needed)

### Building

```bash
git clone https://github.com/nickustinov/itsyhome-macos.git
cd itsyhome-macos
xcodegen generate
xcodebuild -scheme Itsyhome -configuration Debug -destination "platform=macOS" build
```

The Xcode project is generated from `project.yml` and is not the source of truth. Always run `xcodegen generate` after changing `project.yml` or adding/removing source files, and never edit `Itsyhome.xcodeproj/project.pbxproj` by hand.

If you don't have the HomeKit entitlement, you can still develop and test almost everything using Home Assistant mode. For local testing without real hardware, run the Home Assistant demo in Docker:

```bash
docker run -d --name homeassistant -p 8123:8123 ghcr.io/home-assistant/home-assistant:stable
```

Then open `http://localhost:8123`, create an account, and generate a long-lived access token (Profile → Security → Long-lived access tokens).

### Running tests

```bash
xcodebuild -scheme Itsyhome -destination "platform=macOS" test
```

Tests live in `macOSBridgeTests/` and run automatically on every pull request via GitHub Actions.

## Project structure

| Path | Purpose |
|------|---------|
| `Itsyhome/iOS/` | Main Catalyst app (hidden, headless) – owns the HomeKit session |
| `Itsyhome/Shared/` | Code shared between the Catalyst app and the plugin (protocols, data structures) |
| `Itsyhome/HomeAssistant/` | Home Assistant WebSocket + REST integration |
| `macOSBridge/` | Native AppKit plugin – menu bar UI, settings, Pro features, sync, webhook server |
| `macOSBridgeTests/` | Unit tests |
| `project.yml` | XcodeGen project definition (also holds the version numbers) |

See the "How it works" section of the [README](README.md) for an overview of how the Catalyst app and the AppKit plugin talk to each other.

## Making changes

1. Fork the repository and create a branch from `main`.
2. Make your changes, keeping the conventions below in mind.
3. Add or update tests for anything testable.
4. Make sure the project builds and all tests pass locally.
5. Open a pull request against `main` with a clear description of what the change does and why.

For larger features or behavioural changes, please open an issue first to discuss the approach before investing significant time.

### Conventions

- **Fix root causes, not symptoms** – no temporary workarounds or dead code.
- **European-style titles** – sentence case for headings and UI strings, never American Title Case.
- **En dashes (–), not em dashes (—)** – in all user-facing text and documentation.
- **No manual pbxproj edits** – change `project.yml` and run `xcodegen generate`.
- Match the style, naming and comment density of the surrounding code.

### Localization

All user-facing strings use `String(localized:defaultValue:bundle:)` with structured keys and `bundle: .macOSBridge` (required because the string catalog lives in the plugin bundle):

```swift
String(localized: "menu.loading.homekit", defaultValue: "Loading HomeKit…", bundle: .macOSBridge)
```

Keys follow the `{area}.{context}.{name}` format – e.g. `menu.*`, `settings.*`, `device.*`, `alert.*`, `common.*`, `onboarding.*`, `group.*`, `pinned.*`, `shortcut.*`.

After adding new strings:

1. Build the project – Xcode populates `macOSBridge/Resources/Localizable.xcstrings` with strings from the macOSBridge target. Strings from the Catalyst target must be added to the catalog by hand.
2. Translate the new strings directly in `Localizable.xcstrings` into all 11 languages (de, es, fr, it, ja, ko, pl, pt-BR, ru, zh-Hans, zh-Hant). Match the existing terminology and tone per language – for example German uses the informal du-form, French uses vouvoiement.
3. Preserve the file's exact formatting: 2-space indent, `" : "` key separator, languages alphabetical within each key, no trailing newline.

If you can't translate into all languages, say so in the pull request – English plus whatever languages you know is a fine starting point.

## Reporting issues

Use [GitHub Issues](https://github.com/nickustinov/itsyhome-macos/issues) for bugs and feature requests. For bugs, please include:

- macOS version and Itsyhome version
- Whether you're in HomeKit or Home Assistant mode
- Steps to reproduce and what you expected to happen
- Relevant log output if available – startup diagnostics can be enabled as described in the [README](README.md#debugging), and the webhook server exposes `/debug/*` endpoints that are often useful

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE), the same license that covers the project.
