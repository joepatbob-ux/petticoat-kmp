import SwiftUI
import Observation

// MARK: - Mock models

struct Device {
    let name: String
    let location: String
    var currentTemp: Int
    var setpoint: Int
    var heatTo: Int
    var keepMin: Int
    var keepMax: Int
    let holdUntil: String
    let humidity: Int
    let outdoorTemp: Int
    let outdoorHigh: Int
    let outdoorLow: Int
    let scheduleName: String
    let sensorSummary: String
    var systemMode: SystemMode = .auto
    var fanMode: FanMode = .auto
    var circulateFan: Bool = true
    var circulateAmount: String = "33% (15min)"

    /// Whether the HVAC is actively calling, derived from mode + temp vs. range.
    var activity: HVACActivity {
        switch systemMode {
        case .off:            return .idle
        case .cool:           return currentTemp > keepMax ? .cooling : .idle
        case .heat, .auxHeat: return currentTemp < keepMin ? .heating : .idle
        case .auto:
            if currentTemp < keepMin { return .heating }
            if currentTemp > keepMax { return .cooling }
            return .idle
        }
    }

    static let sample = Device(
        name: "Home",
        location: "St. Louis, MO",
        currentTemp: 72,
        setpoint: 72,
        heatTo: 75,
        keepMin: 62,
        keepMax: 73,
        holdUntil: "6:00AM or Away",
        humidity: 40,
        outdoorTemp: 89,
        outdoorHigh: 89,
        outdoorLow: 81,
        scheduleName: "Comfort",
        sensorSummary: "2 of 3 Sensors"
    )
}

struct SpotlightItem {
    let provider: String
    let title: String
    let body: String
    let validUntil: String

    static let sample = SpotlightItem(
        provider: "ACME POWER",
        title: "Save with the EcoSmart program!",
        body: "Optimize your energy usage by registering to the EcoSmart program today!",
        validUntil: "July 15, 2025"
    )
}

struct ScheduleBlock: Identifiable {
    let id = UUID()
    let temp: Int
    let time: String

    static let sample = [
        ScheduleBlock(temp: 76, time: "7:15 AM"),
        ScheduleBlock(temp: 76, time: "7:15 AM"),
        ScheduleBlock(temp: 76, time: "7:15 AM"),
        ScheduleBlock(temp: 76, time: "7:15 AM"),
    ]
}

// MARK: - App state

/// Which end of the comfort range is being adjusted.
enum SetpointBound { case low, high }

/// Current HVAC call state, derived from temperature vs. the comfort range.
enum HVACActivity { case idle, heating, cooling }

enum SystemMode: String, CaseIterable, Identifiable {
    case cool, heat, auxHeat, auto, off
    var id: String { rawValue }
    var label: String {
        switch self {
        case .cool:    "Cool"
        case .heat:    "Heat"
        case .auxHeat: "AUX"
        case .auto:    "Auto"
        case .off:     "Off"
        }
    }
}

enum FanMode: String, CaseIterable, Identifiable {
    case auto, on
    var id: String { rawValue }
    var label: String { self == .auto ? "Auto" : "On" }
}

@Observable
final class AppModel {
    enum Route { case splash, login, main }

    var route: Route = .splash
    var showAccount = false

    var device = Device.sample
    let spotlight = SpotlightItem.sample
    let schedule = ScheduleBlock.sample

    /// Single-value adjustment used by the dashboard card.
    func adjustSetpoint(by delta: Int) {
        device.setpoint = min(90, max(50, device.setpoint + delta))
    }

    /// Adjusts a single comfort-range bound, keeping low strictly below high.
    func adjustKeep(_ bound: SetpointBound, by delta: Int) {
        switch bound {
        case .low:
            let v = device.keepMin + delta
            if v >= 45, v < device.keepMax { device.keepMin = v }
        case .high:
            let v = device.keepMax + delta
            if v <= 95, v > device.keepMin { device.keepMax = v }
        }
    }

    func signIn() {
        withAnimation(.easeInOut) { route = .main }
    }

    func signOut() {
        showAccount = false
        withAnimation(.easeInOut) { route = .login }
    }
}
