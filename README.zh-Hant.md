[简体中文](README.md) | 繁體中文 | [English](README.en.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

# 譯箋

每天練幾句翻譯。應用在簡體中文系統裡叫译笺，在繁體中文裡叫譯箋，在日語裡叫訳箋，其他語言裡叫 LinguaLine。檔名始終是 `LinguaLine.app`。

題目、批改和範例都走你自己的大模型介面。練習記錄留在本機，不需要帳號。

## 能做什麼

- 按母語和練習語言出題，方向是母語譯出、以及譯回母語。支援中文、英語、日語、韓語、法語、德語、西班牙語、俄語、葡萄牙語、義大利語、阿拉伯語。
- 用信、達、雅給譯文打分，並標出刪去和補上的詞。
- 按分數安排複習間隔，間隔檔位可以自己加。短語也可以單獨放進複習。
- 記錄每次作答，收藏句子，並查看用量。模型不同時，用量會分開畫，填了每百萬 token 的價格後會算出費用。
- 同步可以關掉，也可以走 iCloud 或 WebDAV。介面密鑰留在鑰匙圈裡，不會同步出去。

介面語言可以跟隨系統，也可以改成簡體中文、繁體中文、英語、日語、韓語、法語、德語或西班牙語。

## 環境

- Xcode，帶 iOS 18 和 macOS 15 SDK
- iPhone、iPad，或 macOS 15 及以上

工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 根據 `project.yml` 生成。倉庫裡已經帶了 `TranslationExercise.xcodeproj`，用 Xcode 打開即可。改過 `project.yml` 或新增了 Swift 檔案之後，在倉庫根目錄再執行一次：

```bash
xcodegen generate
```

## 編譯

用 Xcode 打開工程，選擇 `TranslationExercise` scheme，執行到 Mac 或模擬器。

不簽名的 macOS Release：

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

產物是 `LinguaLine.app`。目前這個套件也掛在 [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0)。它沒有開發者憑證，也沒有公證。如果系統攔住，在 Finder 裡對應用按住 Control，再點「打開」。

## 使用前

在設定裡填大模型的位址、模型名和密鑰。協定可以是 OpenAI 相容介面，也可以是 Anthropic。翻譯可以單獨用另一個模型。

母語只在第一次打開時按系統語言設好，之後可以再改。
