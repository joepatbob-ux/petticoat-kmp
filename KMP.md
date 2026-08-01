# KMP architecture

Petticoat is becoming a **Kotlin Multiplatform** project with **native UIs on each
platform** — not Compose Multiplatform shared UI.

```
┌─────────────────────────────────────────────────────────────┐
│  shared/  (KMP)                                             │
│  models · SchedulingMath · AppModel (StateFlow) · samples   │
│  targets: android · jvm · ios (PetticoatShared.framework)   │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                ▼                             ▼
┌───────────────────────────┐   ┌─────────────────────────────────┐
│  androidApp/              │   │  Petticoat/ (existing Xcode)    │
│  Jetpack Compose          │   │  SwiftUI (keeps SMA design)     │
│  Material 3 Expressive    │   │  → migrate onto shared via      │
│  MaterialExpressiveTheme  │   │    PetticoatShared.framework    │
└───────────────────────────┘   └─────────────────────────────────┘
```

## What is shared

| Shared (Kotlin) | Platform-native |
|---|---|
| `Device`, sensors, schedules, programs, reminders, profiles | All screens / navigation chrome |
| `TimelineMath` / `DialMath` | Radial schedule dial rendering |
| `AppModel` + `AppState` (`StateFlow`) | Widgets, Live Activities, MapKit, WKWebView |
| Sample / mock data | Install-flow art, SF Symbols / Material icons |

## Android

```
./gradlew :androidApp:assembleDebug
```

Uses `MaterialExpressiveTheme` + expressive motion. Current screens: Splash → Login →
Dashboard (thermostat + spotlight cards) → Control (setpoint / mode / hold).

## iOS (SwiftUI stays)

The existing `Petticoat.xcodeproj` SwiftUI app is unchanged and remains the iOS UI.

### Wiring shared into Xcode (next step)

1. On a Mac: `./gradlew :shared:linkDebugFrameworkIosSimulatorArm64`
   (or the matching `iosArm64` / `iosX64` task).
2. Drag `PetticoatShared.framework` into the Xcode project (or use a Gradle
   `embedAndSignAppleFrameworkForXcode` run script phase).
3. Replace Swift `AppModel` mutations gradually with calls into
   `PetticoatShared.AppModel`, observing `state` via a small Swift bridge
   (SKIE recommended for Flow → `AsyncSequence`).

Until that bridge ships, **Swift and Kotlin `AppModel`s are parallel** — keep
behavioral changes in sync, or prefer landing logic in `shared/` first.

## Tests

```
./gradlew :shared:jvmTest
```

Ports of `SchedulingMathTests` plus smoke tests for `AppModel` (sign-in, hold, timeline).

## Out of scope for this scaffold

- Full Android parity with every SwiftUI screen (Schedule dial, Install, Usage, …)
- Live iOS framework consumption from Xcode
- Real network / BLE / persistence (still mock data; see `HANDOFF.md`)
