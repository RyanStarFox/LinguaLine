[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [English](README.en.md) | 日本語 | [한국어](README.ko.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

# 訳箋

毎日、翻訳を数文練習します。簡体字中国語のシステムでは译笺、繁体字中国語では譯箋、日本語では訳箋、それ以外の言語では LinguaLine と表示されます。ファイル名は常に `LinguaLine.app` です。

問題、添削、範例は、自分で用意した大規模言語モデルの API を使います。練習の記録はこの端末に残り、アカウントは要りません。

## できること

- 母語と練習する言語で問題を出します。方向は、母語から練習言語へ、および練習言語から母語へです。中国語、英語、日本語、韓国語、フランス語、ドイツ語、スペイン語、ロシア語、ポルトガル語、イタリア語、アラビア語に対応しています。
- 訳文を信・達・雅で採点し、削った語と補った語を示します。
- 点数に応じて復習の間隔を決めます。間隔の段階は自分で追加できます。語句だけを復習に入れることもできます。
- 毎回の回答を記録し、文を保存し、使用量を見られます。モデルが違うときは使用量を分けて描き、100万トークンあたりの価格を入れると費用を出します。
- 同期はオフ、iCloud、WebDAV から選べます。API キーはキーチェーンに残り、同期されません。

表示言語はシステムに従うことも、簡体字中国語、繁体字中国語、英語、日本語、韓国語、フランス語、ドイツ語、スペイン語に変えることもできます。

## 環境

- iOS 18 と macOS 15 の SDK が入った Xcode
- iPhone、iPad、または macOS 15 以降

プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) が `project.yml` から生成します。リポジトリには `TranslationExercise.xcodeproj` が入っているので、Xcode で開けます。`project.yml` を変えたあと、または Swift ファイルを追加したあとは、リポジトリのルートで次を一度実行します。

```bash
xcodegen generate
```

## ビルド

Xcode でプロジェクトを開き、`TranslationExercise` scheme を選んで、Mac またはシミュレータで実行します。

署名なしの macOS Release：

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

成果物は `LinguaLine.app` です。いまのパッケージは [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0) にも付いています。開発者証明書はなく、公証もされていません。システムに止められたときは、Finder でアプリを Control キーを押しながらクリックし、「開く」を選びます。

## 使う前に

設定で、モデルのアドレス、モデル名、キーを入力します。プロトコルは OpenAI 互換 API でも Anthropic でも構いません。翻訳だけ別のモデルにできます。

母語は、最初に開いたときだけシステム言語から設定されます。あとから変更できます。
