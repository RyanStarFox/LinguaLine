[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [English](README.en.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | [Français](README.fr.md) | [Deutsch](README.de.md) | Español

# LinguaLine

Unas frases de traducción cada día. En un sistema en chino simplificado la app se llama 译笺; en chino tradicional, 譯箋; en japonés, 訳箋; en los demás idiomas, LinguaLine. El archivo se llama siempre `LinguaLine.app`.

Los enunciados, las correcciones y los ejemplos pasan por tu propia interfaz de modelo. Los ejercicios se quedan en el dispositivo. No hace falta una cuenta.

## Qué hace

- Plantea enunciados según la lengua materna y la lengua de práctica, en las dos direcciones. Admite chino, inglés, japonés, coreano, francés, alemán, español, ruso, portugués, italiano y árabe.
- Puntúa la traducción por fidelidad, expresividad y elegancia, y marca las palabras quitadas o añadidas.
- Fija el intervalo de repaso según la puntuación. Los tramos del intervalo se pueden añadir. Una expresión puede entrar sola en el repaso.
- Guarda cada respuesta, permite conservar frases y muestra el consumo. Si los modelos son distintos, el consumo se dibuja por separado. Si indicas un precio por millón de tokens, calcula el coste.
- La sincronización puede estar apagada, o ir por iCloud o WebDAV. Las claves de la API se quedan en el llavero y no se sincronizan.

El idioma de la interfaz puede seguir al sistema, o ser chino simplificado, chino tradicional, inglés, japonés, coreano, francés, alemán o español.

## Entorno

- Xcode, con los SDK de iOS 18 y macOS 15
- iPhone, iPad, o macOS 15 o posterior

El proyecto lo genera [XcodeGen](https://github.com/yonaskolb/XcodeGen) a partir de `project.yml`. `TranslationExercise.xcodeproj` ya está en el repositorio y se abre con Xcode. Después de cambiar `project.yml` o de añadir un archivo Swift, ejecuta esto una vez en la raíz del repositorio:

```bash
xcodegen generate
```

## Compilación

Abre el proyecto en Xcode, elige el scheme `TranslationExercise` y ejecútalo en un Mac o en un simulador.

Release de macOS sin firma:

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

El resultado es `LinguaLine.app`. Este paquete también está en [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0). No tiene certificado de desarrollador ni está notarizado. Si el sistema lo bloquea, en el Finder pulsa la app con la tecla Control y elige Abrir.

## Antes de empezar

En los ajustes, escribe la dirección del modelo, su nombre y la clave. El protocolo puede ser una API compatible con OpenAI o Anthropic. La traducción puede usar otro modelo.

La lengua materna solo se fija según el idioma del sistema la primera vez que se abre. Después se puede cambiar.
