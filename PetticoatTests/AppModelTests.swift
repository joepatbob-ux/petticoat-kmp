import Testing
@testable import Petticoat

/// Swift tests now verify the observation/mutation facade. Canonical domain behavior
/// lives in `shared/src/commonTest/.../AppModelTest.kt`.
@MainActor
struct AppModelTests {
    private func eventually(
        timeoutIterations: Int = 50,
        _ predicate: @MainActor () -> Bool
    ) async -> Bool {
        for _ in 0..<timeoutIterations {
            if predicate() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return predicate()
    }

    @Test func routeMutationFlowsThroughSharedModel() async {
        let model = AppModel()
        model.signIn()
        #expect(await eventually { model.route == .main })

        model.signOut()
        #expect(await eventually { model.route == .login })
        #expect(model.showAccount == false)
    }

    @Test func setpointMutationFlowsBackAndCreatesHold() async {
        let model = AppModel()
        let before = model.device.keepMax
        model.adjustKeep(.high, by: 1)

        #expect(await eventually {
            model.device.keepMax == before + 1 && model.controlMode == .hold
        })
    }

    @Test func selectedDeviceAndSensorMutationRoundTrip() async {
        let model = AppModel()
        let upstairs = model.devices[1]
        model.selectDevice(upstairs.id)
        #expect(await eventually { model.device.id == upstairs.id })

        guard let sensor = model.device.sensors.first else {
            Issue.record("Expected a sample sensor")
            return
        }
        model.renameSensor(sensor.id, to: "Living Room", in: model.device.id)
        #expect(await eventually {
            model.device.sensors.first(where: { $0.id == sensor.id })?.name == "Living Room"
        })
    }

    @Test func scheduleTimelineIsProjectedIntoSwiftTypes() async {
        let model = AppModel()
        #expect(await eventually { model.todaysTimeline.count == 4 })
        #expect(model.currentPeriod != nil)
    }

    @Test func contractorPhoneDigitsRemainsNativePresentationLogic() {
        let contractor = Contractor.sample
        contractor.phone = "(314) 555-0123"
        #expect(contractor.phoneDigits == "3145550123")
    }
}
