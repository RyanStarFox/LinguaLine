[简体中文](README.md) | [繁體中文](README.zh-Hant.md) | [English](README.en.md) | [日本語](README.ja.md) | [한국어](README.ko.md) | Français | [Deutsch](README.de.md) | [Español](README.es.md)

# LinguaLine

Quelques phrases à traduire chaque jour. Sur un système en chinois simplifié, l’app s’appelle 译笺 ; en chinois traditionnel, 譯箋 ; en japonais, 訳箋 ; dans les autres langues, LinguaLine. Le fichier s’appelle toujours `LinguaLine.app`.

Les sujets, les corrections et les exemples passent par votre propre interface de modèle. Les exercices restent sur l’appareil. Aucun compte n’est nécessaire.

## Ce qu’elle fait

- Elle propose des sujets selon la langue maternelle et la langue d’exercice, dans les deux sens. Langues prises en charge : chinois, anglais, japonais, coréen, français, allemand, espagnol, russe, portugais, italien et arabe.
- Elle note la traduction selon la fidélité, l’expressivité et l’élégance, et marque les mots retirés ou ajoutés.
- Elle fixe l’intervalle de révision d’après la note. Les paliers d’intervalle peuvent être ajoutés. Une expression peut entrer seule dans la révision.
- Elle garde chaque réponse, permet d’enregistrer des phrases et montre la consommation. Les modèles distincts sont tracés à part. Si vous indiquez un prix par million de tokens, le coût est calculé.
- La synchronisation peut être coupée, ou passer par iCloud ou WebDAV. Les clés d’API restent dans le trousseau et ne sont pas synchronisées.

La langue de l’interface peut suivre le système, ou être le chinois simplifié, le chinois traditionnel, l’anglais, le japonais, le coréen, le français, l’allemand ou l’espagnol.

## Environnement

- Xcode, avec les SDK iOS 18 et macOS 15
- iPhone, iPad, ou macOS 15 et versions suivantes

Le projet est produit à partir de `project.yml` par [XcodeGen](https://github.com/yonaskolb/XcodeGen). `TranslationExercise.xcodeproj` est déjà dans le dépôt : ouvrez-le avec Xcode. Après une modification de `project.yml` ou l’ajout d’un fichier Swift, exécutez ceci une fois à la racine du dépôt :

```bash
xcodegen generate
```

## Compilation

Ouvrez le projet dans Xcode, choisissez le scheme `TranslationExercise`, puis lancez-le sur un Mac ou un simulateur.

Release macOS sans signature :

```bash
xcodebuild -scheme TranslationExercise -destination 'platform=macOS' -configuration Release build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

Le produit est `LinguaLine.app`. Ce paquet est aussi joint à [v1.0.0](https://github.com/RyanStarFox/LinguaLine/releases/tag/v1.0.0). Il n’a pas de certificat de développeur et n’est pas notarisé. Si le système le bloque, cliquez sur l’app dans le Finder tout en maintenant Contrôle, puis choisissez Ouvrir.

## Avant de commencer

Dans les réglages, indiquez l’adresse du modèle, son nom et la clé. Le protocole peut être une API compatible OpenAI ou Anthropic. La traduction peut utiliser un autre modèle.

La langue maternelle n’est réglée d’après la langue du système qu’au premier lancement. Vous pouvez la changer ensuite.
