# Classic Solitaire

A native, offline Klondike Solitaire project inspired by the Windows Solitaire games of the Windows 98, XP, and Vista eras. It began as a way to bring the familiar game—and especially the animated palm beach sun and castle card backs—to my mom on modern Apple devices.

Built with Swift, SwiftUI, and SpriteKit, the project shares a Swift game engine across Apple platforms and is being adapted for the iPhone Duo cover and inner displays, the iPhone 13 mini, iPad, and Mac. No accounts, ads, subscriptions, or gameplay tracking are intended.

## In progress

The current development build includes Klondike with draw one or three, local game restoration, undo, hints, theme and card-back selection, and experimental legacy animations and victory effects. Windows 98 and XP artwork also have optional remastered previews. The user interface adapts to folding and rotation, with continuing work on the Duo's native navigation and compact-phone layouts.

This is an evolving recreation, not a finished or verified reproduction of every original Windows behavior. Physical-device testing, scoring parity, animation and audio fidelity, accessibility, and polish remain ongoing. The screenshots below are user-provided photographs of development builds; controls and layout may have changed since they were taken.

## Downloads and development status

The current iOS prerelease is **0.6.17 (build 25)**, available as an unsigned IPA on the [release page](https://github.com/wireproof/ClassicSolitaire/releases/tag/v0.6.17). The package needs signing and provisioning before installation. The app uses the bundle identifier `com.wireproof.solitaire` and the Home Screen name Solitaire.

This build includes tap-to-move and experimental drag-and-drop. It has been installed on the iPhone Duo and iPad Pro; physical-device gameplay and drag interactions have not been verified for this release. A newer macOS development build has been packaged but is not included in this iOS release.

## Screenshots

| Duo inner display — portrait | Duo inner display — landscape |
| --- | --- |
| ![Duo inner portrait showing Windows 98 cards](docs/screenshots/duo-inner-portrait.jpg) | ![Duo inner landscape showing Windows 98 cards](docs/screenshots/duo-inner-landscape.jpg) |

| Duo cover — Vista | Duo cover — Windows 98 |
| --- | --- |
| ![Duo cover with Vista appearance](docs/screenshots/duo-cover-vista.jpg) | ![Duo cover with Windows 98 appearance](docs/screenshots/duo-cover-windows98.jpg) |

## Source and tests

- `Sources/SolitaireEngine/` contains the Swift game rules and state.
- `Tests/SolitaireEngineTests/` contains engine tests; run them with `swift test`.
- `App/ClassicSolitaireApp.swift` contains the SwiftUI application and visual effects.

The engine is a Swift package. The SwiftUI app source and its image and audio resources are included in `App/`. A complete Xcode project and turnkey app build are not yet included.

This is an independent fan project and is not affiliated with or endorsed by Microsoft or Apple. Windows names and imagery belong to their respective owners.
