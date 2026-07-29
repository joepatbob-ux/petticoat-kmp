import ActivityKit
import Foundation

/// Shared between the main app and widget extension.
/// Add this file to both targets via File Inspector (⌘⌥1).
///
/// Marked `nonisolated` so its `ActivityAttributes` conformance isn't inferred
/// as main-actor-isolated (the project defaults new types to `@MainActor`).
/// ActivityKit passes these value types across concurrency boundaries, so the
/// conformance must be usable from non-isolated contexts.
nonisolated struct PetticoatActivityAttributes: ActivityAttributes {
    /// Static — set when the Live Activity starts.
    var deviceName: String
    /// Temperature when HVAC first kicked on, used for progress bar calculation.
    var startTemp: Int

    nonisolated struct ContentState: Codable, Hashable {
        var currentTemp: Int
        /// Current target (keepMin for heating, keepMax for cooling). Can shift
        /// if the user adjusts the setpoint while the activity is running.
        var targetTemp: Int
        /// Estimated moment the setpoint will be reached — drives the countdown timer.
        var estimatedEndDate: Date
        var isHeating: Bool
    }
}
