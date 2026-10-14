# 译笺

每天练几句翻译。应用在中文系统里叫译笺，在英文系统里叫 LinguaLine，文件名始终是 `LinguaLine.app`。

题目、批改和范例都走你自己的大模型接口。练习记录留在本机，不需要账号。

## 能做什么

- 按母语和练习语言出题，方向是母语译出、以及译回母语。支持中文、英语、日语、韩语、法语、德语、西班牙语、俄语、葡萄牙语、意大利语、阿拉伯语。
- 用信、达、雅给译文打分，并标出删去和补上的词。
- 按分数安排复习间隔，间隔档位可以自己加。短语也可以单独放进复习。
- 记录每次作答，收藏句子，并查看用量。模型不同时，用量会分开画，填了每百万 token 的价格后会算出费用。
- 同步可以关掉，也可以走 iCloud 或 WebDAV。接口密钥留在钥匙串里，不会同步出去。

界面语言可以跟随系统，也可以改成简体中文、繁体中文、英语、日语、韩语、法语、德语或西班牙语。

## 环境

- Xcode，带 iOS 18 和 macOS 15 SDK
- iPhone、iPad，或 macOS 15 及以上

工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 根据 `project.yml` 生成。仓库里已经带了 `TranslationExercise.xcodeproj`，用 Xcode 打开即可。改过 `project.yml` 或新增了 Swift 文件之后，在仓库根目录再执行一次：

```bash
xcodegen generate
```

## 编译

用 Xcode 打开工程，选择 `TranslationExercise` scheme，运行到 Mac 或模拟器。

不签名的 macOS Release：

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

产物是 `LinguaLine.app`。当前这个包也挂在 [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0)。它没有开发者证书，也没有公证。如果系统拦住，在 Finder 里对应用按住 Control，再点「打开」。

## 使用前

在设置里填大模型的地址、模型名和密钥。协议可以是 OpenAI 兼容接口，也可以是 Anthropic。翻译可以单独用另一个模型。

母语只在第一次打开时按系统语言设好，之后可以再改。
