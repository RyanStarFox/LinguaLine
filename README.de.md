[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [English](README.en.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | Deutsch | [Español](README.es.md)

# LinguaLine

Jeden Tag ein paar Sätze übersetzen. Auf einem System mit vereinfachtem Chinesisch heißt die App 译笺, mit traditionellem Chinesisch 譯箋, auf Japanisch 訳箋, in den übrigen Sprachen LinguaLine. Die Datei heißt immer `LinguaLine.app`.

Aufgaben, Korrekturen und Beispiele laufen über Ihre eigene Modellschnittstelle. Die Übungen bleiben auf dem Gerät. Ein Konto ist nicht nötig.

## Was sie kann

- Sie stellt Aufgaben nach Muttersprache und Übungssprache, in beide Richtungen. Unterstützt werden Chinesisch, Englisch, Japanisch, Koreanisch, Französisch, Deutsch, Spanisch, Russisch, Portugiesisch, Italienisch und Arabisch.
- Sie bewertet die Übersetzung nach Treue, Ausdruck und Eleganz und markiert entfernte und ergänzte Wörter.
- Sie legt den Wiederholungsabstand nach der Punktzahl fest. Abstands-Stufen lassen sich selbst hinzufügen. Eine Wendung kann allein in die Wiederholung.
- Sie speichert jede Antwort, merkt sich Sätze und zeigt den Verbrauch. Verschiedene Modelle werden getrennt gezeichnet. Steht ein Preis je Million Tokens, wird auch der Betrag berechnet.
- Die Synchronisierung kann aus sein oder über iCloud oder WebDAV laufen. API-Schlüssel bleiben im Schlüsselbund und werden nicht synchronisiert.

Die Oberflächensprache kann dem System folgen oder Vereinfachtes Chinesisch, Traditionelles Chinesisch, Englisch, Japanisch, Koreanisch, Französisch, Deutsch oder Spanisch sein.

## Umgebung

- Xcode mit den SDKs für iOS 18 und macOS 15
- iPhone, iPad oder macOS 15 und neuer

Das Projekt entsteht aus `project.yml` mit [XcodeGen](https://github.com/yonaskolb/XcodeGen). `TranslationExercise.xcodeproj` liegt bereits im Depot und lässt sich in Xcode öffnen. Nach einer Änderung an `project.yml` oder einer neuen Swift-Datei einmal im Stammverzeichnis ausführen:

```bash
xcodegen generate
```

## Bauen

Projekt in Xcode öffnen, das Scheme `TranslationExercise` wählen und auf einem Mac oder Simulator starten.

macOS-Release ohne Signatur:

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

Das Ergebnis ist `LinguaLine.app`. Dieses Paket hängt auch an [v1.1.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.1.0). Es hat kein Entwicklerzertifikat und ist nicht notarisiert. Wenn das System es anhält, die App im Finder bei gedrückter Control-Taste anklicken und „Öffnen“ wählen.

## Vor dem Start

In den Einstellungen Adresse, Modellname und Schlüssel eintragen. Das Protokoll kann eine OpenAI-kompatible Schnittstelle oder Anthropic sein. Die Übersetzung kann ein eigenes Modell nutzen.

Die Muttersprache wird nur beim ersten Öffnen aus der Systemsprache gesetzt. Danach lässt sie sich ändern.
