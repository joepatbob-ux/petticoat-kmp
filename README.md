# Petticoat — Sensi thermostat app (SwiftUI prototype)

A working SwiftUI prototype of the Sensi smart-thermostat experience: onboarding, a
device dashboard, and a full device-detail experience (Control, Schedule, Usage,
Reminders, Settings). **The UI, navigation, and interactions are real; all data is
in-memory mock data.** For wiring in real device/cloud functionality, see
[`HANDOFF.md`](HANDOFF.md).

## Requirements

- **Xcode** with the **iOS 27** SDK/simulator (deployment target: iOS 27.0).
- Swift 5 language mode. No third-party dependencies — plain SwiftUI + WebKit + MapKit.

## Build & run

1. Open `Petticoat.xcodeproj`.
2. Select the **Petticoat** scheme and an iOS 26/27 simulator (e.g. iPhone 17 Pro).
3. Run (⌘R). The app boots at a splash screen, auto-advances to Login; tap **Login** to
   reach the dashboard.

Xcode uses **file-system-synchronized groups**, so files added to the `Petticoat/`
folder are picked up automatically — no manual target membership needed.

## Test

44 unit tests + 5 UI tests, all passing.

```
xcodebuild test -scheme Petticoat \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

- `PetticoatTests/` — `AppModelTests` (state/mutations), `DeviceTests` (HVAC activity),
  `SchedulingMathTests` (pure timeline + dial-break math).
- `PetticoatUITests/` — login→device flow, Reminders add, Sensors, Settings, Usage.

## Architecture

- **`AppModel`** (`Petticoat/AppModel.swift`) is an `@Observable` class and the **single
  source of truth**. It's created once in `RootView` and injected via `.environment(...)`;
  views read `model.x` and call `model.doThing()`. State is in-memory (resets on cold
  launch).
- **Routing** (`RootView`): `splash → login → main`. `MainView` shows the iPhone (compact)
  experience as `DashboardView` in a `NavigationStack`, and the iPad (regular) experience
  as `MainSplitView` (adaptive sidebar/tab). Account / Add Device / Help present as sheets.
- **Device detail** is `DeviceTabView` — a `TabView` (Control / Schedule / Usage /
  Reminders / Settings) pushed from a dashboard thermostat card.
- **Pure logic** that's easy to get wrong is extracted and unit-tested in
  `SchedulingMath.swift` (timeline current/upcoming; radial-dial break placement).
- **Design tokens & shared UI** live in `Theme.swift` (`SMA` color tokens,
  `groupedListChrome()`, `MetricBar`, card styles).

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
