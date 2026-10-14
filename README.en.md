[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | English | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

# LinguaLine

Practice a few translations every day. On a Simplified Chinese system the app is named 译笺, in Traditional Chinese 譯箋, in Japanese 訳箋, and in every other language LinguaLine. The file is always `LinguaLine.app`.

Prompts, corrections, and exemplars go through your own model API. Practice records stay on the device. No account is required.

## What it does

- Writes prompts from your native language and the language you are practicing, in both directions. Supported languages: Chinese, English, Japanese, Korean, French, German, Spanish, Russian, Portuguese, Italian, and Arabic.
- Scores a translation for faithfulness, expressiveness, and elegance, and marks words that were removed or added.
- Schedules review intervals from the score. You can add interval bands. Phrases can go into review on their own.
- Keeps every answer, lets you save sentences, and shows token use. Different models are charted separately. If you enter a price per million tokens, it also shows the cost.
- Sync can be off, iCloud, or WebDAV. API keys stay in the Keychain and are not synced.

The interface can follow the system language, or be set to Simplified Chinese, Traditional Chinese, English, Japanese, Korean, French, German, or Spanish.

## Requirements

- Xcode with the iOS 18 and macOS 15 SDKs
- iPhone, iPad, or macOS 15 or later

The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen). `TranslationExercise.xcodeproj` is already in the repo, so you can open it in Xcode. After you change `project.yml` or add a Swift file, run this once from the repository root:

```bash
xcodegen generate
```

## Build

Open the project in Xcode, select the `TranslationExercise` scheme, and run it on a Mac or a simulator.

Unsigned macOS Release:

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

The product is `LinguaLine.app`. The current package is also attached to [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0). It has no developer certificate and is not notarized. If the system blocks it, Control-click the app in Finder and choose Open.

## Before you start

In Settings, enter the model endpoint, model name, and key. The protocol can be an OpenAI-compatible API or Anthropic. Translation can use a separate model.

The native language is set from the system language only on the first launch. You can change it later.
