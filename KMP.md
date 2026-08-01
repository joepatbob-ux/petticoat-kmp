# KMP architecture

Petticoat is a **Kotlin Multiplatform** project with **native UIs on each platform** —
not a shared Compose Multiplatform UI.

```
┌─────────────────────────────────────────────────────────────┐
│  shared/  (KMP)                                             │
│  models · SchedulingMath · AppModel (StateFlow) · samples   │
│  targets: android · jvm · ios (PetticoatShared.framework)   │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌─────────────────────────────────┐
│  androidApp/              │   │  Petticoat/                     │
│  Jetpack Compose          │   │  native SwiftUI + SMA design    │
│  Material 3 Expressive    │   │  @Observable facade + SKIE      │
└───────────────────────────┘   └─────────────────────────────────┘
```

## Ownership

| Shared KMP | Platform-native |
|---|---|
| Devices, sensors, schedules, programs, reminders, profiles | Screens and navigation chrome |
| `TimelineMath` / `DialMath` | Radial dial rendering and gestures |
| `AppModel` + immutable `AppState` snapshots | WidgetKit, Live Activities, MapKit, WKWebView |
| All domain mutations and sample data | Install art, SF Symbols / Material icons |

`shared/` is the canonical domain implementation. New behavior lands in
`shared/src/commonMain` with tests in `shared/src/commonTest`.

## Android

```bash
./gradlew :androidApp:assembleDebug
```

Android owns its Compose UI and collects `AppModel.state` with
`collectAsStateWithLifecycle()`. The theme uses `MaterialExpressiveTheme` and expressive
motion. The adaptive device shell exposes Control, Schedule, Usage, Reminders, and
Settings tabs. Schedule includes profiles, preset/program editing, vacations, geofence,
and a draggable Canvas dial. Usage includes runtime ranges and expandable mode charts;
Control exposes Sensors and Mode sheets; global Account, Help, and Add Device flows use
native Material sheets.

## iOS

The existing `Petticoat.xcodeproj` remains the native SwiftUI application:

1. Xcode's **Build PetticoatShared** phase invokes
   `:shared:embedAndSignAppleFrameworkForXcode`.
2. SKIE exports `StateFlow<AppState>` as a typed Swift `AsyncSequence`.
3. `Petticoat/AppModel.swift` is an `@Observable` facade. It collects shared snapshots
   and maps them into native `UUID`/`Date`/SwiftUI-facing adapters.
4. SwiftUI bindings and actions route mutations back through the KMP model.
5. `Petticoat/WidgetSyncService.swift` observes projected state and keeps WidgetKit,
   ActivityKit, and App Group I/O native.

The facade preserves existing SwiftUI layouts and bindings while avoiding a second
domain implementation. Swift model structs are boundary adapters only.

## Tests

Canonical shared behavior:

```bash
./gradlew :shared:jvmTest
```

Android compile/package and instrumentation-test compile:

```bash
./gradlew :androidApp:assembleDebug :androidApp:assembleDebugAndroidTest
```

iOS facade, platform services, and UI (macOS/Xcode required):

```bash
xcodebuild test -scheme Petticoat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## Remaining production work

The apps still use in-memory sample data. Repository/service interfaces, persistence,
BLE/cloud implementations, permissions, and production error/loading states remain as
described in `HANDOFF.md`.
