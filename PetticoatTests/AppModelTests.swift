import Testing
@testable import Petticoat

@MainActor
struct AppModelTests {

    // MARK: Setpoint range

    @Test func raisingLowPushesHighByDeadband() {
        let model = AppModel()
        // Push the low bound up; it drags the high bound along, keeping the deadband,
        // and caps at the ceiling minus the deadband.
        for _ in 0..<50 { model.adjustKeep(.low, by: 1) }
        #expect(model.device.keepMin == SetpointConfig.maxTemp - SetpointConfig.deadband)
        #expect(model.device.keepMax == SetpointConfig.maxTemp)
        #expect(model.device.keepMax - model.device.keepMin == SetpointConfig.deadband)
    }

    @Test func loweringHighPushesLowByDeadband() {
        let model = AppModel()
        // Lowering the high bound drags the low bound down, keeping the deadband,
        // and caps at the floor plus the deadband.
        for _ in 0..<50 { model.adjustKeep(.high, by: -1) }
        #expect(model.device.keepMax == SetpointConfig.minTemp + SetpointConfig.deadband)
        #expect(model.device.keepMin == SetpointConfig.minTemp)
        #expect(model.device.keepMax - model.device.keepMin == SetpointConfig.deadband)
    }

    @Test func lowBoundClampsAtFloor() {
        let model = AppModel()
        for _ in 0..<50 { model.adjustKeep(.low, by: -1) }
        #expect(model.device.keepMin == 45)
    }

    // MARK: Control mode transitions

    @Test func adjustingWhileOnScheduleCreatesHold() {
        let model = AppModel()
        model.controlMode = .schedule
        model.adjustKeep(.high, by: 1)
        #expect(model.controlMode == .hold)
    }

    @Test func adjustingWhileStandardStaysStandard() {
        let model = AppModel()
        model.controlMode = .standard
        model.adjustKeep(.high, by: 1)
        #expect(model.controlMode == .standard)
    }

    @Test func scheduleToggleDrivesMode() {
        let model = AppModel()
        model.setScheduleEnabled(false)
        #expect(model.controlMode == .standard)
        model.setScheduleEnabled(true)
        #expect(model.controlMode == .schedule)
    }

    @Test func activatingProfileEntersActivityMode() {
        let model = AppModel()
        let profile = ActivityProfile.samples[3]   // Workout
        model.activateProfile(profile)
        #expect(model.controlMode == .activity)
        #expect(model.activeProfile.id == profile.id)
    }

    @Test func vacationThenResume() {
        let model = AppModel()
        model.setVacation(true)
        #expect(model.controlMode == .vacation)
        model.resumeSchedule()
        #expect(model.controlMode == .schedule)
    }

    // MARK: Spotlight

    @Test func dismissingSpotlightRemovesIt() {
        let model = AppModel()
        let start = model.spotlights.count
        let first = model.spotlights[0]
        model.dismissSpotlight(first)
        #expect(model.spotlights.count == start - 1)
        #expect(!model.spotlights.contains { $0.id == first.id })
    }

    // MARK: Routing

    @Test func signInRoutesToMainAndOutToLogin() {
        let model = AppModel()
        model.signIn()
        #expect(model.route == .main)

        model.showAccount = true
        model.signOut()
        #expect(model.route == .login)
        #expect(model.showAccount == false)
    }

    // MARK: Activity profiles

    @Test func savingEditedProfileUpdatesInPlace() {
        let model = AppModel()
        var edited = model.activityProfiles[0]
        let id = edited.id
        edited.name = "Renamed"
        edited.coolTo = 81
        model.saveProfile(edited)
        #expect(model.activityProfiles.count == ActivityProfile.samples.count)
        #expect(model.activityProfiles[0].id == id)
        #expect(model.activityProfiles[0].name == "Renamed")
        #expect(model.activityProfiles[0].coolTo == 81)
    }

    @Test func savingUnknownProfileAppends() {
        let model = AppModel()
        let start = model.activityProfiles.count
        let new = ActivityProfile(name: "Guest", symbol: "person.fill", colorHex: 0, heatTo: 60, coolTo: 80, subtitle: "")
        model.saveProfile(new)
        #expect(model.activityProfiles.count == start + 1)
        #expect(model.activityProfiles.last?.id == new.id)
    }

    @Test func savingActiveProfileSyncsController() {
        let model = AppModel()
        var active = model.activeProfile
        active.name = "Active Edited"
        model.saveProfile(active)
        #expect(model.activeProfile.name == "Active Edited")
    }

    @Test func duplicatingInsertsCopyAfterOriginal() {
        let model = AppModel()
        let start = model.activityProfiles.count
        let first = model.activityProfiles[0]
        model.duplicateProfile(first)
        #expect(model.activityProfiles.count == start + 1)
        #expect(model.activityProfiles[1].name == first.name + " Copy")
        #expect(model.activityProfiles[1].id != first.id)
    }

    @Test func deletingRemovesProfile() {
        let model = AppModel()
        let first = model.activityProfiles[0]
        model.deleteProfile(first)
        #expect(!model.activityProfiles.contains { $0.id == first.id })
    }

    // MARK: Service reminders

    private func newReminder(_ name: String = "Test") -> ServiceReminder {
        ServiceReminder(name: name, type: "Air Filter", basedOn: .runtime, durationText: "300 Hours",
                        nextService: .now, lastCompleted: nil, spec: "", lifeRemaining: 1)
    }

    @Test func savingUnknownReminderAppends() {
        let model = AppModel()
        let start = model.serviceReminders.count
        let reminder = newReminder("Guest Filter")
        model.saveReminder(reminder)
        #expect(model.serviceReminders.count == start + 1)
        #expect(model.serviceReminders.last?.id == reminder.id)
    }

    @Test func savingExistingReminderUpdatesInPlace() {
        let model = AppModel()
        let count = model.serviceReminders.count
        var edited = model.serviceReminders[0]
        edited.name = "Renamed"
        model.saveReminder(edited)
        #expect(model.serviceReminders.count == count)
        #expect(model.serviceReminders[0].id == edited.id)
        #expect(model.serviceReminders[0].name == "Renamed")
    }

    @Test func deletingRemovesReminder() {
        let model = AppModel()
        let first = model.serviceReminders[0]
        model.deleteReminder(first.id)
        #expect(!model.serviceReminders.contains { $0.id == first.id })
    }

    @Test func completingResetsLifeAndStampsDate() {
        let model = AppModel()
        var reminder = model.serviceReminders[0]
        reminder.lifeRemaining = 0.2
        reminder.lastCompleted = nil
        model.saveReminder(reminder)
        model.completeReminder(reminder.id)
        let updated = model.serviceReminders.first { $0.id == reminder.id }
        #expect(updated?.lifeRemaining == 1)
        #expect(updated?.lastCompleted != nil)
    }

    // MARK: Schedules

    @Test func selectingScheduleUpdatesActive() {
        let model = AppModel()
        let second = model.schedules[1]
        model.selectSchedule(second.id)
        #expect(model.activeSchedule?.id == second.id)
    }

    @Test func savingUnknownScheduleAppendsAndSelects() {
        let model = AppModel()
        let start = model.schedules.count
        let new = SchedulePreset(name: "Custom")
        model.saveSchedule(new)
        #expect(model.schedules.count == start + 1)
        #expect(model.activeSchedule?.id == new.id)
    }

    @Test func duplicatingScheduleInsertsCopy() {
        let model = AppModel()
        let start = model.schedules.count
        let first = model.schedules[0]
        model.duplicateSchedule(first)
        #expect(model.schedules.count == start + 1)
        #expect(model.schedules[1].name == first.name + " Copy")
    }

    @Test func deletingScheduleRemovesAndReselects() {
        let model = AppModel()
        let first = model.schedules[0]
        model.selectSchedule(first.id)
        model.deleteSchedule(first.id)
        #expect(!model.schedules.contains { $0.id == first.id })
        #expect(model.selectedScheduleID != first.id)
    }

    // MARK: Programs (non-preset)

    @Test func savingProgramForKindAppendsAndSelects() {
        let model = AppModel()
        let start = model.programs[.heat]?.count ?? 0
        let new = ScheduleProgram(name: "Custom Heat",
                                  groups: [ProgramDayGroup(days: Set(0..<7), events: ScheduleProgram.sampleEvents())])
        model.saveProgram(new, kind: .heat)
        #expect(model.programs[.heat]?.count == start + 1)
        #expect(model.activeProgramID(for: .heat) == new.id)
    }

    @Test func deletingProgramRemoves() {
        let model = AppModel()
        guard let first = model.programs[.cool]?.first else { return }
        model.deleteProgram(first.id, kind: .cool)
        #expect(model.programs[.cool]?.contains { $0.id == first.id } == false)
    }

    // MARK: Sensors

    @Test func renamingSensorUpdatesModel() {
        let model = AppModel()
        guard let sensor = model.device.sensors.first else { return }
        model.renameSensor(sensor.id, to: "Living Room", in: model.device.id)
        #expect(model.device.sensors.first?.name == "Living Room")
    }

    @Test func renamingSensorIgnoresBlank() {
        let model = AppModel()
        guard let sensor = model.device.sensors.first else { return }
        let original = sensor.name
        model.renameSensor(sensor.id, to: "   ", in: model.device.id)
        #expect(model.device.sensors.first?.name == original)
    }

    // MARK: Contractor

    @Test func contractorPhoneDigitsStripsFormatting() {
        var c = Contractor.sample
        c.phone = "(314) 555-0123"
        #expect(c.phoneDigits == "3145550123")
    }

    // MARK: Single-mode setpoint + vacation

    @Test func adjustingInHeatModeMovesHeatTarget() {
        let model = AppModel()
        model.devices[0].systemMode = .heat
        let before = model.device.keepMin
        model.adjustKeep(.high, by: 2)   // bound is ignored in single-target modes
        #expect(model.device.keepMin == before + 2)
    }

    @Test func adjustingInCoolModeMovesCoolTarget() {
        let model = AppModel()
        model.devices[0].systemMode = .cool
        let before = model.device.keepMax
        model.adjustKeep(.low, by: -3)
        #expect(model.device.keepMax == before - 3)
    }

    @Test func vacationWithProfileAppliesItsSetpoints() {
        let model = AppModel()
        let profile = model.activityProfiles[0]
        model.setVacation(true, profile: profile)
        #expect(model.controlMode == .vacation)
        #expect(model.device.keepMin == profile.heatTo)
        #expect(model.device.keepMax == profile.coolTo)
    }
}
