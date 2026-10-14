[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [English](README.en.md) | [日本語](README.ja.md) | 한국어 | [Français](README.fr.md) | [Deutsch](README.de.md) | [Español](README.es.md)

# LinguaLine

매일 번역을 몇 문장씩 연습합니다. 간체 중국어 시스템에서는 译笺, 번체 중국어에서는 譯箋, 일본어에서는 訳箋, 그 밖의 언어에서는 LinguaLine으로 보입니다. 파일 이름은 항상 `LinguaLine.app`입니다.

문제, 첨삭, 모범 답안은 직접 준비한 대규모 언어 모델 API를 사용합니다. 연습 기록은 이 기기에 남고, 계정은 필요 없습니다.

## 할 수 있는 일

- 모국어와 연습 언어로 문제를 냅니다. 방향은 모국어에서 연습 언어로, 그리고 연습 언어에서 모국어로입니다. 중국어, 영어, 일본어, 한국어, 프랑스어, 독일어, 스페인어, 러시아어, 포르투갈어, 이탈리아어, 아랍어를 지원합니다.
- 번역을 신·달·아로 채점하고, 뺀 말과 더한 말을 표시합니다.
- 점수에 따라 복습 간격을 정합니다. 간격 구간은 직접 추가할 수 있습니다. 표현만 따로 복습에 넣을 수도 있습니다.
- 매번 답을 기록하고, 문장을 저장하고, 사용량을 볼 수 있습니다. 모델이 다르면 사용량을 나눠 그립니다. 백만 토큰당 가격을 적으면 비용도 계산합니다.
- 동기화는 끄거나, iCloud 또는 WebDAV를 쓸 수 있습니다. API 키는 키체인에 남고 동기화되지 않습니다.

화면 언어는 시스템을 따르거나, 간체 중국어, 번체 중국어, 영어, 일본어, 한국어, 프랑스어, 독일어, 스페인어로 바꿀 수 있습니다.

## 환경

- iOS 18과 macOS 15 SDK가 있는 Xcode
- iPhone, iPad, 또는 macOS 15 이상

프로젝트는 [XcodeGen](https://github.com/yonaskolb/XcodeGen)이 `project.yml`로 만듭니다. 저장소에 `TranslationExercise.xcodeproj`가 들어 있어 Xcode로 바로 열 수 있습니다. `project.yml`을 고치거나 Swift 파일을 추가한 뒤에는 저장소 루트에서 한 번 실행합니다.

```bash
xcodegen generate
```

## 빌드

Xcode에서 프로젝트를 열고 `TranslationExercise` scheme을 선택한 뒤 Mac 또는 시뮬레이터에서 실행합니다.

서명하지 않은 macOS Release:

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

결과물은 `LinguaLine.app`입니다. 현재 패키지는 [v1.1.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.1.0)에도 있습니다. 개발자 인증서가 없고 공증도 되어 있지 않습니다. 시스템이 막으면 Finder에서 앱을 Control-클릭한 뒤 「열기」를 선택합니다.

## 시작하기 전에

설정에서 모델 주소, 모델 이름, 키를 입력합니다. 프로토콜은 OpenAI 호환 API 또는 Anthropic입니다. 번역만 다른 모델을 쓸 수 있습니다.

모국어는 처음 열 때만 시스템 언어로 정해집니다. 나중에 바꿀 수 있습니다.
