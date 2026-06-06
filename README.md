# CloneMine — воксельная песочница для iOS

Нативная iOS-игра в стиле Minecraft на **Swift + Metal**. Процедурная генерация мира,
разрушение/установка блоков, инвентарь, управление от первого лица. Сборка
неподписанного `.ipa` автоматизирована через GitHub Actions.

## Стек

- Swift, Metal (рендеринг воксельного мира), UIKit (HUD)
- Проект генерируется из `project.yml` через [XcodeGen](https://github.com/yonaskolb/XcodeGen)
- CI: GitHub Actions, macOS-раннер, `xcodebuild`

## Сборка в CI

Workflow `.github/workflows/ios-build.yml`:

1. По `push`/`pull_request` в `main` запускается на `macos-14`.
2. Генерирует `.xcodeproj` через XcodeGen.
3. На PR прогоняет тесты на симуляторе.
4. Собирает архив **без подписи** (`CODE_SIGNING_ALLOWED=NO`).
5. Вручную упаковывает `.app` в `Payload/` -> `VoxelGame-unsigned.ipa`.
6. Выкладывает `.ipa` как артефакт (хранение 30 дней).

> **Важно:** получаемый `.ipa` **не подписан**. Установить его можно только через
> sideloading (AltStore, Sideloadly) или на устройство с джейлбрейком. Через
> App Store / TestFlight он не устанавливается.

## Локальная сборка (только macOS)

```bash
brew install xcodegen
xcodegen generate
open VoxelGame.xcodeproj
```

## Управление

- Левая половина экрана — джойстик движения.
- Правая половина — обзор (перетаскивание).
- Кнопки справа: Сломать / Поставить / Прыжок.
- Нижняя панель — выбор типа блока.
