# Expo Native Dependency Inventory

## Current runtime dependencies still tied to Expo / React Native

- `ExpoModulesProvider.swift` is still compiled into the target through CocoaPods and remains part of module registration.
- The app lifecycle still boots through the existing Expo/Pods-integrated iOS project rather than a fully standalone pure-native project file.
- Xcode build phases still include `[Expo] Configure project` plus CocoaPods-generated Expo support files.

## Native code that is already independent

- App state, repositories, parsers, notification logic, and SwiftUI screens live in native Swift code.
- Root presentation is driven by `UIHostingController` and `SwiftUI` rather than a React Native root view.
- Web parsing, API access, Keychain persistence, user/session/settings state, and subject notification checks are all native implementations.

## Script and project residues

- `Podfile` / Pods still generate Expo support scripts and `ExpoModulesProvider.swift`.
- `Bangumi.xcodeproj` still links Expo-managed pod products and resource phases.
- `Supporting/Expo.plist` remains bundled.

## Likely migration order

1. Remove script-only Expo dependencies once the target no longer needs generated module wiring.
2. Replace or eliminate `ExpoModulesProvider.swift` and validate no Expo module is still referenced at runtime.
3. Prune Expo-related pods and project phases, then re-verify simulator install/build.
