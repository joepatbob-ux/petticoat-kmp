# Petticoat — Sensi thermostat app (KMP + native UIs)

A working prototype of the Sensi smart-thermostat experience. **Domain logic lives in a
Kotlin Multiplatform `shared` module**; UIs are native:

- **iOS** — existing SwiftUI app (`Petticoat.xcodeproj`) with the SMA design system
- **Android** — Jetpack Compose with **Material 3 Expressive** (`androidApp/`)

The UI, navigation, and interactions are real; all data is in-memory mock data.
Architecture details: [`KMP.md`](KMP.md). Production wiring: [`HANDOFF.md`](HANDOFF.md).

## Requirements

### iOS
- **Xcode** with the **iOS 27** SDK/simulator (deployment target: iOS 27.0).
- Swift 5 language mode. No third-party dependencies — plain SwiftUI + WebKit + MapKit.

### Android / shared
- JDK 17+, Android SDK 35, Android Studio or CLI (`./gradlew`).
- Kotlin 2.1 / AGP 8.10 (see `gradle/libs.versions.toml`).

## Build & run

### iOS (SwiftUI)

1. Open `Petticoat.xcodeproj`.
2. Select the **Petticoat** scheme and an iOS 26/27 simulator (e.g. iPhone 17 Pro).
3. Run (⌘R). The app boots at a splash screen, auto-advances to Login; tap **Login** to
   reach the dashboard.

Xcode uses **file-system-synchronized groups**, so files added to the `Petticoat/`
folder are picked up automatically — no manual target membership needed.

### Android (Material Expressive)

```
./gradlew :androidApp:assembleDebug
```

Install the debug APK on an emulator/device, or open the repo root in Android Studio and
run the **androidApp** configuration.

### Shared tests

```
./gradlew :shared:jvmTest
```

## Test

Shared domain tests, native iOS unit tests, and 5 iOS UI flows cover the prototype.

```
xcodebuild test -scheme Petticoat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- `shared/src/commonTest/` — canonical `AppModel` state/mutation and scheduling-math tests.
- `PetticoatTests/` — Swift facade, native widget contract, and iOS presentation tests.
- `PetticoatUITests/` — login→device flow, Reminders add, Sensors, Settings, Usage.

## Architecture

- **Shared KMP** (`shared/`) is the domain source of truth: models, `SchedulingMath`, and
  `AppModel` (`StateFlow<AppState>`). See [`KMP.md`](KMP.md).
- **iOS `AppModel`** (`Petticoat/AppModel.swift`) is an `@Observable` facade over
  `PetticoatShared.AppModel`. SKIE projects shared state into Swift concurrency while
  preserving native SwiftUI bindings. It is owned by the app scene and injected via
  `.environment(...)`.
- **Routing** (`RootView`): `splash → login → main`. `MainView` shows the iPhone (compact)
  experience as `DashboardView` in a `NavigationStack`, and the iPad (regular) experience
  as `MainSplitView` (adaptive sidebar/tab). Account / Add Device / Help present as sheets.
- **Device detail** is `DeviceTabView` — a `TabView` (Control / Schedule / Usage /
  Reminders / Settings) pushed from a dashboard thermostat card.
- **Pure logic** that's easy to get wrong is extracted and unit-tested in shared
  `SchedulingMath` — timeline current/upcoming and radial-dial break placement.
- **Design tokens & shared UI** live in `Theme.swift` (`SMA` color tokens) on iOS and
  `ui/theme/Theme.kt` (Material Expressive + SMA brand colors) on Android.

## Screen / file map

| File | Screen / role |
|---|---|
| `RootView.swift` | App root, routing (splash/login/main), appearance |
| `SplashView.swift` / `LoginView.swift` | Splash, sign-in |
| `DashboardView.swift` | Dashboard (iPhone home): thermostat cards, spotlight, sensor disclosure |
| `MainSplitView.swift` | iPad adaptive sidebar/tab container |
| `DeviceTabView.swift` | Device-detail tab container + Reminders add button |
| `ThermostatView.swift` | **Control** tab: setpoint stepper, mode pill, schedule pager, status |
| `ScheduleView.swift` | **Schedule/Automation** tab: mode toggle, presets, schedules, geofence, vacations |
| `ScheduleFlow.swift` | Profile-based Schedules list + editor (radial dial) |
| `ProgramScheduleFlow.swift` | Non-preset per-mode (Heat/Cool/Auto) programs list + editor |
| `ScheduleDial.swift` | Radial 24h schedule dial (drag + break-to-insert) |
| `ScheduleComponents.swift` | Shared editor components (DayPicker, Save/Cancel, `RowActionButton`) |
| `ActivityProfiles.swift` | Activity profiles (presets) list + editor |
| `VacationFlow.swift` | Vacations list + editor (inline date-range calendar) |
| `UsageView.swift` | **Usage** tab: per-mode runtime breakdown + legend |
| `RemindersFlow.swift` | **Reminders** tab: service reminders + add/edit editor |
| `SettingsFlow.swift` | **Settings** tab: thermostat settings menu + Display Options, System Configuration, About, Location, Contractor, Energy Programs |
| `SensorsView.swift` | Sensors screen + Sensor Details (opened from the Control sensor pill) |
| `ModeSheet.swift` | System / fan mode picker sheet |
| `AccountView.swift` | Account sheet, Help & Support (web view), About |
| `WebView.swift` | `WKWebView` wrapper (Mavenoid help assistant) |
| `GeofenceRadiusView.swift` | Geofence radius map (Auto Home/Away) |
| `InstallFlow.swift` / `InstallFlowScreens.swift` | Device install / onboarding flow |
| `AppModel.swift` | `@Observable` state + models (`Device`, `RoomSensor`, `TimelinePeriod`, …) + mutations |
| `SchedulingMath.swift` | Pure, tested timeline + dial math |
| `Theme.swift` | `SMA` design tokens + shared view helpers |

## Status & next steps

Feature-complete for everything designed; remaining work (real data wiring, persistence,
permissions, CI, plus the design-blocked Remove-Thermostat survey and Contractor
illustration) is tracked in [`HANDOFF.md`](HANDOFF.md).
