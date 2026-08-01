# AGENTS.md

Petticoat is a native iOS / SwiftUI prototype of the Sensi smart-thermostat app. See
[`README.md`](README.md) for the screen/file map and architecture, and
[`HANDOFF.md`](HANDOFF.md) for the prototype→production roadmap.

## Cursor Cloud specific instructions

### Platform reality: this app requires macOS + Xcode and CANNOT be built or run on the Linux cloud VM

- This is an **Apple-only toolchain project** (`Petticoat.xcodeproj`, deployment target iOS 27.0).
  Every app/UI/test source imports Apple frameworks that do not exist on Linux —
  `SwiftUI`, `UIKit`, `WebKit`, `MapKit`, `CoreLocation`, `WidgetKit`, `ActivityKit`, `CoreText`.
- The cloud VM is **Linux (Ubuntu)** with no Xcode, no iOS SDK, no simulator, and no `xcodebuild`.
  There is therefore **no way to build, run, or run the full test/UI suite here**. Building and
  the GUI "login → dashboard" flow must be done on **macOS with Xcode + the iOS 27 SDK/simulator**.
- Standard build/run/test commands are documented in [`README.md`](README.md)
  (`xcodebuild test -scheme Petticoat -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`).
  Run them on macOS; do not expect them to work on the cloud VM.

### Dependencies & update script

- There are **no external dependencies to install**: no SPM (`Package.swift`), CocoaPods, or
  Carthage, and no lockfiles. Xcode uses file-system-synchronized groups, so files dropped into
  `Petticoat/` are picked up automatically — no manual target membership edits.
- Because nothing is fetched by a package manager, the startup **update script is intentionally a
  no-op**. Do not add toolchain/system-dependency installs to it.

### What *can* be verified on Linux (optional, verification-only — not the real dev workflow)

- Only two sources are framework-independent (Foundation-only): `Petticoat/SchedulingMath.swift`
  (pure timeline + radial-dial math) and `Petticoat/WidgetSnapshot.swift` (Codable widget model +
  `ComfortLevel`). Their real Swift Testing suites are
  `PetticoatTests/SchedulingMathTests.swift` and `PetticoatTests/WidgetSnapshotTests.swift`.
- To exercise just those on Linux: install a Swift toolchain (e.g. via `swiftly`), then copy those
  4 files verbatim into a throwaway SwiftPM package **whose library target is named `Petticoat`**
  (so `@testable import Petticoat` resolves unchanged) with a matching `PetticoatTests` test target,
  and run `swift test`. This compiles/passes all 26 of those tests but does **not** cover the app,
  the widget, or any SwiftUI/UIKit code — it is not a substitute for building in Xcode.

### Android / KMP toolchain (installed on the Linux VM snapshot)

Despite the repo name (`petticoat-kmp`), **there is currently no Kotlin Multiplatform / Gradle
project in this repository** — no `gradlew`, no `settings.gradle(.kts)`, and no `:androidApp` or
`:shared` modules on any branch. So `./gradlew :androidApp:assembleDebug :shared:allTests` cannot be
run against this repo until that project structure is added.

The VM snapshot nonetheless has a ready Android/JVM toolchain for when a Gradle/KMP project lands:

- **JDK 21** (`openjdk-21-jdk`, system-installed). `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64`.
- **Android SDK** under `$HOME/android-sdk` (`ANDROID_HOME`/`ANDROID_SDK_ROOT`): `platform-tools`,
  `platforms;android-35`, `build-tools;35.0.0`, plus `cmdline-tools;latest`. All licenses accepted
  (`$ANDROID_HOME/licenses`).
- `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT`, and the tool `PATH` are exported from `~/.bashrc`
  (interactive shells). If you need them in a non-login/non-interactive shell, source `~/.bashrc` or
  set them explicitly.
- **Gradle 8.14.3** wrapper distribution and the Kotlin/AGP/Android dependency caches are pre-warmed
  in `~/.gradle` (verified by building a throwaway Android+KMP smoke project — that project lives in
  `/tmp`, not the repo). A future in-repo `./gradlew` on Gradle 8.14.3 will reuse the warmed cache.

These are one-time snapshot installs, **not** part of the startup update script (which stays a
no-op). Do not add SDK/JDK installs or `gradle assemble` to the update script.
