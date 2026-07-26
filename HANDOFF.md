# Petticoat (Sensi) — Prototype → Production Handoff

This app is a **working SwiftUI prototype** of the Sensi thermostat experience. All UI,
navigation, and interaction is real; all **data is in-memory mock data** and all
"actions" mutate that in-memory state synchronously. This doc is the map for wiring in
real functionality (BLE/cloud/backend, persistence, permissions).

## 1. Architecture & the one integration seam

- **`AppModel`** (`Petticoat/AppModel.swift`) is an `@Observable` class and the single
  source of truth. Views read `model.x` and call `model.doThing()`. It's injected once at
  the root via `.environment(AppModel())`.
- Feature state already lives on the model (persists for the session): `devices`,
  `activityProfiles`, `schedules` / `selectedScheduleID`, `programs` /
  `selectedProgramID`, `serviceReminders`, `contractor`, `thermostatSettings`,
  `controlMode`, `activeProfile`, `spotlights`.
- **Recommended seam:** introduce a service/repository protocol layer that `AppModel`
  depends on, e.g. `ThermostatService`, `ScheduleService`, `UsageService`,
  `ReminderService`. Keep `AppModel` as the view-facing state holder; move I/O behind the
  protocols and inject a live implementation in the app / a mock in previews & tests.
  Views should not change.

## 2. Make mutations async + add loading/error/empty states

Every `AppModel` mutation is currently **synchronous and infallible**. Real device/cloud
calls are async and can fail. Convert the write/read paths to `async throws` and surface:

- **Loading** state (e.g. saving a schedule to the device, fetching usage).
- **Error** state (retry / offline messaging) — none exists today (happy-path only).
- **Empty** state — mostly handled (Reminders has `ContentUnavailableView`), but confirm
  for Usage (no data), Sensors (no paired sensors), Schedules/Programs.

Methods that will become async: `saveSchedule`/`selectSchedule`/`deleteSchedule` (+program
equivalents), `saveReminder`/`completeReminder`, `adjustKeep`, `setVacation`,
`toggleSensor`, `renameSensor`.

## 3. Mock data & hardcoded values to replace

~26 `*.samples()` / `static let sample` sources feed the UI. Replace each with real data:

| Area | Where | Replace with |
|---|---|---|
| Devices / sensors | `AppModel.Device.sample`, `RoomSensor.samples` | Paired device + live telemetry |
| Schedules / programs | `SchedulePreset.samples()`, `ScheduleProgram.samples(for:)` | Stored schedules |
| Reminders | `ServiceReminder.samples()` | Stored reminders + notifications |
| Contractor | `Contractor.sample` | Account/contractor record |
| Usage | `UsageView.swift` `UsageSample` | Runtime history API |
| Device facts (hardcoded strings) | `SettingsFlow.swift` Model/Firmware/MAC (`1F86U-42WF`, `6004971003`, `34:6F:…`), `SensorsView.swift` Sensor ID `1234567890ABCDEF`, About Wi-Fi/Battery strength | Device metadata |
| Thermostat Location field labels | `ThermostatLocationView` | Verify against real address schema (labels were a best-guess) |

## 4. Not-yet-wired actions (intentional stubs)

- **Remove Thermostat** — `SettingsFlow.swift` confirmation dialog's destructive action is
  a no-op `{ }`; also the full Figma "remove" survey flow (reasons + illustration) is
  condensed to this dialog. Needs the real removal call + (optional) the survey screen.
- **Thermostat Location → "Use Current Location"** — empty action; wire to CoreLocation.
- **Contractor illustration** — SF Symbol placeholder (`wrench.and.screwdriver.fill`); the
  Figma asset isn't bundled.
- **Display Options / System Configuration** — persist in `thermostatSettings` but don't
  drive any hardware; wire each to the device.
- **Energy "Enroll" / "Call Contractor"** — Enroll flips local state only; Call opens
  `tel:` from `model.contractor` (fine, but the number is sample data).

## 5. Capabilities & Info.plist (add before shipping)

- **CoreLocation** (`GeofenceRadiusView`, Auto Home/Away): add
  `NSLocationWhenInUseUsageDescription` + an authorization request flow (none today).
- **User Notifications** (Service Reminders "Email or Push"): add `UNUserNotificationCenter`
  request + scheduling; the reminder copy already promises notifications.
- **WKWebView help** (`WebView.swift` → Mavenoid): HTTPS, so no ATS change. If the Mavenoid
  assistant needs camera/mic/photo upload, add the usage strings and enable them on the
  `WKWebViewConfiguration`.

## 6. Persistence

There is **no persistence** — state resets on cold launch. Choose a strategy (SwiftData,
backend sync, or `UserDefaults` for small prefs like `thermostatSettings`) and hydrate
`AppModel` on launch.

## 7. Localization

All user-facing strings are **hardcoded English literals**; there is **no String Catalog**.
Add `Localizable.xcstrings` and migrate. (Skills exist for translation coordination.)

## 8. Accessibility

- Controls are broadly labeled, but only one stable `accessibilityIdentifier`
  (`"sensorAveragePill"`) exists — add a consistent identifier scheme for the elements the
  UI tests (and future ones) drive.
- Run an audit for **VoiceOver**, **Dynamic Type**, and **contrast** (the custom
  System-Mode colors in Usage and the dark thermostat surfaces are worth checking).

## 9. Testing & CI

Current suite (all green): **31 unit** (`AppModelTests`, `DeviceTests`) + **5 UI**
(`PetticoatUITests`) covering login→device, Reminders add, Sensors, Settings, Usage.

Recommended additions:
- **Unit:** the schedule-dial break/insert math and min-length clamping (currently private
  in `ScheduleDial`; extract the pure geometry into a testable helper), and the timeline
  `currentPeriod`/`upcomingPeriods` derivation (inject a clock so it's deterministic — it
  reads `Date()` today).
- **UI:** schedule editing (dial drag / break), vacation create + toggle, reminder
  edit/delete, program editing.
- **Snapshot tests** for the visual-heavy screens (Usage bars, reminder cards, schedule
  dial) to catch layout regressions — add a snapshot library.
- **CI:** run `xcodebuild test` on PRs; add a shared **Test Plan** and enable code coverage.

## 10. Known design/asset gaps

- **Remove Thermostat** survey flow — needs the Figma node.
- **Contractor illustration** — needs the exported asset.
- **Mavenoid help URL** — live embedded-assistant URL is wired in `HelpSupportView`; confirm
  it's the production assistant id.
