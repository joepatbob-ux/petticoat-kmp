import Testing
import Foundation
@testable import Petticoat

struct DeviceTests {

    /// Builds a device with a specific mode, current temp, and comfort range.
    private func device(mode: SystemMode, temp: Int, low: Int = 62, high: Int = 73) -> Device {
        var d = Device.sample
        d.systemMode = mode
        // Drive currentTemp by setting all participating sensors to the same value.
        d.sensors = d.sensors.map { RoomSensor(name: $0.name, temp: temp, humidity: $0.humidity,
                                               participating: $0.participating, battery: $0.battery) }
        d.keepMin = low
        d.keepMax = high
        return d
    }

    @Test func offIsAlwaysIdle() {
        #expect(device(mode: .off, temp: 90).activity == .idle)
        #expect(device(mode: .off, temp: 40).activity == .idle)
    }

    @Test func coolCallsOnlyAboveHigh() {
        #expect(device(mode: .cool, temp: 80).activity == .cooling)
        #expect(device(mode: .cool, temp: 70).activity == .idle)
        #expect(device(mode: .cool, temp: 55).activity == .idle)
    }

    @Test func heatCallsOnlyBelowLow() {
        #expect(device(mode: .heat, temp: 55).activity == .heating)
        #expect(device(mode: .heat, temp: 70).activity == .idle)
        #expect(device(mode: .auxHeat, temp: 55).activity == .heating)
    }

    @Test func autoPicksHeatingOrCoolingOrIdle() {
        #expect(device(mode: .auto, temp: 55).activity == .heating)
        #expect(device(mode: .auto, temp: 80).activity == .cooling)
        #expect(device(mode: .auto, temp: 68).activity == .idle)
    }

    @Test func profileRangeText() {
        let profile = ActivityProfile(name: "Test", symbol: "house.fill", colorHex: 0, heatTo: 62, coolTo: 78, subtitle: "")
        #expect(profile.rangeText == "62 · 78")
    }

    // MARK: HoldDuration

    @Test func indefiniteDurationEndDateIsNil() {
        #expect(HoldDuration.indefinite.endDate() == nil)
        #expect(HoldDuration.indefinite.endTimeText() == nil)
    }

    @Test func timedDurationEndDateAddsCorrectHours() throws {
        let now = Date()
        let cal = Calendar.current
        let oneHourEnd = try #require(HoldDuration.oneHour.endDate(from: now))
        let twelveHourEnd = try #require(HoldDuration.twelveHours.endDate(from: now))
        #expect(cal.dateComponents([.hour], from: now, to: oneHourEnd).hour == 1)
        #expect(cal.dateComponents([.hour], from: now, to: twelveHourEnd).hour == 12)
    }

    // MARK: RoomSensor battery

    @Test func batterySymbolBoundaries() {
        #expect(RoomSensor.batterySymbol(100) == "battery.100")
        #expect(RoomSensor.batterySymbol(67)  == "battery.100")
        #expect(RoomSensor.batterySymbol(66)  == "battery.50")
        #expect(RoomSensor.batterySymbol(34)  == "battery.50")
        #expect(RoomSensor.batterySymbol(33)  == "battery.25")
        #expect(RoomSensor.batterySymbol(1)   == "battery.25")
        #expect(RoomSensor.batterySymbol(0)   == "battery.0")
    }

    @Test func batteryColorChangesAtThresholds() {
        #expect(RoomSensor.batteryColor(50) != RoomSensor.batteryColor(49))
        #expect(RoomSensor.batteryColor(20) != RoomSensor.batteryColor(19))
    }
}
