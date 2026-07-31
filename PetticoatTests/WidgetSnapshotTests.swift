import Testing
import Foundation
@testable import Petticoat

struct WidgetSnapshotTests {

    // MARK: - ComfortLevel.isAvailable

    @Test func heatModeShowsColdChillyAndFan() {
        #expect(ComfortLevel.cold.isAvailable(for: .heat))
        #expect(ComfortLevel.chilly.isAvailable(for: .heat))
        #expect(ComfortLevel.stuffy.isAvailable(for: .heat))
        #expect(!ComfortLevel.warm.isAvailable(for: .heat))
        #expect(!ComfortLevel.hot.isAvailable(for: .heat))
    }

    @Test func coolModeShowsWarmHotAndFan() {
        #expect(!ComfortLevel.cold.isAvailable(for: .cool))
        #expect(!ComfortLevel.chilly.isAvailable(for: .cool))
        #expect(ComfortLevel.stuffy.isAvailable(for: .cool))
        #expect(ComfortLevel.warm.isAvailable(for: .cool))
        #expect(ComfortLevel.hot.isAvailable(for: .cool))
    }

    @Test func offModeShowsOnlyFan() {
        #expect(!ComfortLevel.cold.isAvailable(for: .off))
        #expect(!ComfortLevel.chilly.isAvailable(for: .off))
        #expect(ComfortLevel.stuffy.isAvailable(for: .off))
        #expect(!ComfortLevel.warm.isAvailable(for: .off))
        #expect(!ComfortLevel.hot.isAvailable(for: .off))
    }

    @Test func autoModeShowsAll() {
        for level in ComfortLevel.allCases {
            #expect(level.isAvailable(for: .auto), "Expected \(level) to be available in auto mode")
        }
    }

    // MARK: - WidgetSnapshot Codable

    @Test func roundTripPreservesNewFields() throws {
        var snap = WidgetSnapshot.sample
        snap.systemMode = .heat
        snap.isOffline = true
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(decoded.systemMode == .heat)
        #expect(decoded.isOffline == true)
    }

    @Test func oldSnapshotWithoutNewFieldsDecodesAsNil() throws {
        // Simulates a snapshot written before systemMode/isOffline existed —
        // both optional fields must decode as nil rather than crashing.
        let json = Data("""
            {"deviceID":"abc","deviceName":"Home","currentTemp":72,"humidity":40,"activity":"idle","feedbackGiven":false}
            """.utf8)
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: json)
        #expect(decoded.systemMode == nil)
        #expect(decoded.isOffline == nil)
    }
}
