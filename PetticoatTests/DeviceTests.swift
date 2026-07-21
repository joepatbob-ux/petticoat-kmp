import Testing
@testable import Petticoat

struct DeviceTests {

    /// Builds a device with a specific mode, current temp, and comfort range.
    private func device(mode: SystemMode, temp: Int, low: Int = 62, high: Int = 73) -> Device {
        var d = Device.sample
        d.systemMode = mode
        d.currentTemp = temp
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
}
