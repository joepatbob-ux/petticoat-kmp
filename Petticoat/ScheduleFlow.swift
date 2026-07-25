import SwiftUI
import UIKit

// MARK: - Models

struct SchedulePreset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    /// The schedule itself: one or more day groups, each with its own events.
    var groups: [ScheduleDayGroup] = [ScheduleDayGroup(days: Set(0..<7), events: ScheduleEvent.samples())]
}

/// A set of days sharing the same list of events. A schedule is one or more of
/// these (e.g. "Weekdays" + "Weekend").
struct ScheduleDayGroup: Identifiable, Hashable {
    let id = UUID()
    var days: Set<Int>
    var events: [ScheduleEvent]
}

/// One scheduled period: an Activity Profile snapshot (name/icon/color/range) that
/// starts at `time`. Snapshotting keeps a saved schedule stable if the source
/// profile is later edited.
struct ScheduleEvent: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var symbol: String
    var colorHex: UInt
    var heatTo: Int
    var coolTo: Int
    var time: Date

    var timeText: String { time.formatted(date: .omitted, time: .shortened) }
    var rangeText: String { "\(heatTo) · \(coolTo)" }

    init(name: String, symbol: String, colorHex: UInt, heatTo: Int, coolTo: Int, time: Date) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.heatTo = heatTo
        self.coolTo = coolTo
        self.time = time
    }

    init(from profile: ActivityProfile, time: Date) {
        self.init(name: profile.name, symbol: profile.symbol, colorHex: profile.colorHex,
                  heatTo: profile.heatTo, coolTo: profile.coolTo, time: time)
    }

    static func at(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }

    static func samples() -> [ScheduleEvent] {
        let p = ActivityProfile.samples   // [Away, Home, Sleep, Workout]
        return [
            ScheduleEvent(from: p[1], time: at(6, 0)),    // Home
            ScheduleEvent(from: p[0], time: at(8, 0)),    // Away
            ScheduleEvent(from: p[1], time: at(17, 0)),   // Home
            ScheduleEvent(from: p[2], time: at(22, 0)),   // Sleep
        ]
    }
}

// MARK: - Presets list (Activity Schedule / Schedules)

/// A radio-select list of schedule presets with a per-row menu and an add button.
struct SchedulePresetsList: View {
    let title: String

    @State private var presets: [SchedulePreset]
    @State private var selection: UUID?
    /// Drives the create/edit sheet. A preset whose id isn't in `presets` yet is a
    /// new one (create); an existing id edits in place. One sheet avoids the
    /// stacked-`.sheet` presentation bug.
    @State private var editorPreset: SchedulePreset?

    init(title: String, presets: [String]) {
        self.title = title
        let items = presets.map { SchedulePreset(name: $0) }
        _presets = State(initialValue: items)
        _selection = State(initialValue: items.first?.id)
    }

    var body: some View {
        List {
            Section {
                ForEach(presets) { preset in
                    HStack(spacing: 12) {
                        // Sibling controls with .borderless button styles so the List
                        // hit-tests the row selection and the menu independently — a
                        // Menu nested in a tappable row otherwise leaks its first
                        // action ("Edit") to row-body taps.
                        Button {
                            selection = preset.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection == preset.id ? "largecircle.fill.circle" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selection == preset.id ? SMA.accent : SMA.labelSecondary)
                                    .accessibilityHidden(true)
                                Text(preset.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityAddTraits(selection == preset.id ? [.isSelected] : [])

                        Menu {
                            Button("Edit", systemImage: "pencil") { editorPreset = preset }
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(preset) }
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(preset) }
                        } label: {
                            EllipsisMenuLabel()
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("More options for \(preset.name)")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editorPreset = SchedulePreset(name: "") } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editorPreset) { draft in
            ScheduleEditorView(preset: draft) { result in
                if let i = presets.firstIndex(where: { $0.id == result.id }) {
                    presets[i] = result          // existing preset: edit in place
                } else {
                    presets.append(result)       // new preset: add and select it
                    selection = result.id
                }
            }
        }
    }

    private func duplicate(_ preset: SchedulePreset) {
        guard let i = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets.insert(SchedulePreset(name: preset.name + " Copy", groups: preset.groups), at: i + 1)
    }

    private func delete(_ preset: SchedulePreset) {
        presets.removeAll { $0.id == preset.id }
        if selection == preset.id { selection = presets.first?.id }
    }
}

// MARK: - Edit Schedule (name + day groups + radial dial + events)

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var preset: SchedulePreset
    @State private var selectedEventID: ScheduleEvent.ID?
    @State private var showingDetails = false
    @State private var addTarget: GroupTarget?
    @State private var editTarget: EventTarget?
    @State private var timeTarget: EventTarget?
    let onSave: (SchedulePreset) -> Void

    private let minEvents = 1
    private let maxEvents = 8

    init(preset: SchedulePreset, onSave: @escaping (SchedulePreset) -> Void) {
        _preset = State(initialValue: preset)
        _selectedEventID = State(initialValue: preset.groups.first?.events.first?.id)
        self.onSave = onSave
    }

    private var isNew: Bool { preset.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $preset.name)
                }

                ForEach(preset.groups) { group in
                    Section {
                        DayPicker(days: group.days) { toggleDay($0, in: group.id) }

                        RadialScheduleDial(
                            events: group.events,
                            selectedID: selectedEventID,
                            onChangeStart: { id, newTime in setEventTime(id, to: newTime) },
                            onSelect: { id in selectedEventID = id },
                            onRequestManualTime: { id in
                                if let event = group.events.first(where: { $0.id == id }) {
                                    timeTarget = EventTarget(groupID: group.id, event: event)
                                }
                            },
                            onBreak: { draggedID, newStart, brokenID, tailStart in
                                breakEvent(draggedID, newStart: newStart, breaking: brokenID,
                                           tailStart: tailStart, in: group.id)
                            }
                        )
                        .frame(height: 340)
                        .frame(maxWidth: .infinity)
                        .listRowBackground(SMA.card)
                        .listRowSeparator(.hidden)

                        HStack {
                            roundIconButton("trash", tint: SMA.destructive, label: "Remove Event") {
                                removeSelectedEvent(in: group.id)
                            }
                            .disabled(group.events.count <= minEvents)

                            Spacer()

                            Button {
                                withAnimation(.snappy) { showingDetails.toggle() }
                            } label: {
                                Text(showingDetails ? "Hide Details" : "Show Details")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(SMA.accent)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(showingDetails ? "Hide event details" : "Show event details")

                            Spacer()

                            roundIconButton("plus", tint: SMA.accent, label: "Add Event") {
                                addTarget = GroupTarget(id: group.id)
                            }
                            .disabled(group.events.count >= maxEvents)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .listRowBackground(SMA.card)
                        .listRowSeparator(.hidden)

                        if showingDetails {
                            ForEach(group.events) { event in
                                eventRow(event, in: group)
                            }
                            .onDelete { deleteEvents($0, from: group.id) }
                        }
                    } header: {
                        HStack {
                            Text(WeekDay.summary(group.days))
                                .font(.headline)
                                .foregroundStyle(SMA.labelPrimary)
                            Spacer()
                            Menu {
                                Button("Remove Day Group", systemImage: "trash", role: .destructive) {
                                    removeGroup(group.id)
                                }
                                .disabled(preset.groups.count <= 1)
                            } label: {
                                EllipsisMenuLabel(outlined: true)
                            }
                            .accessibilityLabel("Day group options")
                        }
                        .textCase(nil)
                    }
                }

                Section {
                    Button {
                        addDayGroup()
                    } label: {
                        Text("Create New Day Group")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(SMA.accent)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(isNew ? "Create Schedule" : "Edit Schedule")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {} label: { Image(systemName: "questionmark.bubble") }
                        .accessibilityLabel("Help and Support")
                    EditorSaveButton {
                        onSave(preset)
                        dismiss()
                    }
                }
            }
            .sheet(item: $addTarget) { target in
                ScheduleEventEditor(title: "Add Event", initial: nil, profiles: model.activityProfiles) { event in
                    addEvent(event, to: target.id)
                }
            }
            .sheet(item: $editTarget) { target in
                ScheduleEventEditor(title: "Edit Event", initial: target.event, profiles: model.activityProfiles) { updated in
                    replaceEvent(target.event.id, with: updated)
                }
            }
            .sheet(item: $timeTarget) { target in
                ManualStartTimeSheet(name: target.event.name, time: target.event.time) { newTime in
                    setEventTime(target.event.id, to: newTime)
                }
                .presentationDetents([.height(320)])
            }
        }
    }

    // MARK: - Round icon button (add / remove)

    private func roundIconButton(_ symbol: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Event row

    private func eventRow(_ event: ScheduleEvent, in group: ScheduleDayGroup) -> some View {
        HStack(spacing: 12) {
            ProfileIcon(symbol: event.symbol, colorHex: event.colorHex, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.name)
                    .foregroundStyle(SMA.labelPrimary)
                Text("Keep between: \(event.rangeText)")
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
            }
            Spacer(minLength: 8)
            Text(event.timeText)
                .foregroundStyle(SMA.labelSecondary)
                .monospacedDigit()
            Menu {
                Button("Edit", systemImage: "pencil") { editTarget = EventTarget(groupID: group.id, event: event) }
                Button("Delete", systemImage: "trash", role: .destructive) { deleteEvent(event.id, from: group.id) }
                    .disabled(group.events.count <= minEvents)
            } label: {
                EllipsisMenuLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options for \(event.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture { selectedEventID = event.id }
        .accessibilityAddTraits(selectedEventID == event.id ? [.isSelected] : [])
    }

    // MARK: - Mutations

    private func groupIndex(_ id: ScheduleDayGroup.ID) -> Int? { preset.groups.firstIndex { $0.id == id } }

    private func toggleDay(_ i: Int, in id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        if preset.groups[g].days.contains(i) { preset.groups[g].days.remove(i) } else { preset.groups[g].days.insert(i) }
    }

    private func deleteEvents(_ offsets: IndexSet, from id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id), preset.groups[g].events.count - offsets.count >= minEvents else { return }
        preset.groups[g].events.remove(atOffsets: offsets)
        if !preset.groups[g].events.contains(where: { $0.id == selectedEventID }) {
            selectedEventID = preset.groups[g].events.first?.id
        }
    }

    private func deleteEvent(_ eventID: ScheduleEvent.ID, from id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id), preset.groups[g].events.count > minEvents else { return }
        preset.groups[g].events.removeAll { $0.id == eventID }
        if selectedEventID == eventID { selectedEventID = preset.groups[g].events.first?.id }
    }

    private func addEvent(_ event: ScheduleEvent, to id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id), preset.groups[g].events.count < maxEvents else { return }
        preset.groups[g].events.append(event)
        preset.groups[g].events.sort { $0.time < $1.time }
        selectedEventID = event.id
    }

    /// Removes the selected event (or the group's last) — never below `minEvents`.
    private func removeSelectedEvent(in id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id), preset.groups[g].events.count > minEvents else { return }
        let targetID = preset.groups[g].events.contains(where: { $0.id == selectedEventID })
            ? selectedEventID : preset.groups[g].events.last?.id
        preset.groups[g].events.removeAll { $0.id == targetID }
        selectedEventID = preset.groups[g].events.first?.id
    }

    /// Replace a selected event's start time (from the dial), keeping the list sorted.
    private func setEventTime(_ eventID: ScheduleEvent.ID, to newTime: Date) {
        for g in preset.groups.indices {
            if let e = preset.groups[g].events.firstIndex(where: { $0.id == eventID }) {
                preset.groups[g].events[e].time = newTime
                preset.groups[g].events.sort { $0.time < $1.time }
                return
            }
        }
    }

    /// Break an event into two around a dropped event: move the dragged event to its new
    /// start and insert a copy of the broken event for the tail, so the broken activity
    /// resumes after the inserted one. No-ops if the group is already at `maxEvents`.
    private func breakEvent(_ draggedID: ScheduleEvent.ID, newStart: Date,
                            breaking brokenID: ScheduleEvent.ID, tailStart: Date,
                            in id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id),
              preset.groups[g].events.count < maxEvents,
              let d = preset.groups[g].events.firstIndex(where: { $0.id == draggedID }),
              let broken = preset.groups[g].events.first(where: { $0.id == brokenID }) else { return }
        let tail = ScheduleEvent(name: broken.name, symbol: broken.symbol, colorHex: broken.colorHex,
                                 heatTo: broken.heatTo, coolTo: broken.coolTo, time: tailStart)
        withAnimation(.snappy) {
            preset.groups[g].events[d].time = newStart
            preset.groups[g].events.append(tail)
            preset.groups[g].events.sort { $0.time < $1.time }
        }
        selectedEventID = draggedID
    }

    /// Replace an event's profile snapshot + time (from the event editor).
    private func replaceEvent(_ eventID: ScheduleEvent.ID, with new: ScheduleEvent) {
        for g in preset.groups.indices {
            if let e = preset.groups[g].events.firstIndex(where: { $0.id == eventID }) {
                var updated = preset.groups[g].events[e]
                updated.name = new.name
                updated.symbol = new.symbol
                updated.colorHex = new.colorHex
                updated.heatTo = new.heatTo
                updated.coolTo = new.coolTo
                updated.time = new.time
                preset.groups[g].events[e] = updated
                preset.groups[g].events.sort { $0.time < $1.time }
                return
            }
        }
    }

    private func addDayGroup() {
        withAnimation(.snappy) {
            preset.groups.append(ScheduleDayGroup(days: [], events: ScheduleEvent.samples()))
        }
    }

    private func removeGroup(_ id: ScheduleDayGroup.ID) {
        withAnimation(.snappy) { preset.groups.removeAll { $0.id == id } }
    }

    // MARK: - Labels

}

/// Identifiable wrapper so a day-group id can drive a `.sheet(item:)` (Add Event).
private struct GroupTarget: Identifiable {
    let id: ScheduleDayGroup.ID
}

/// Identifiable wrapper for the Edit Event sheet, carrying the event + its group.
private struct EventTarget: Identifiable {
    var id: ScheduleEvent.ID { event.id }
    let groupID: ScheduleDayGroup.ID
    let event: ScheduleEvent
}

// MARK: - Add / Edit Event (pick an Activity Profile + start time)

struct ScheduleEventEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    let title: String
    let profiles: [ActivityProfile]
    let onSave: (ScheduleEvent) -> Void

    @State private var selectedProfileID: ActivityProfile.ID?
    @State private var time: Date
    @State private var creatingProfile = false

    init(title: String, initial: ScheduleEvent?, profiles: [ActivityProfile], onSave: @escaping (ScheduleEvent) -> Void) {
        self.title = title
        self.profiles = profiles
        self.onSave = onSave
        _time = State(initialValue: initial?.time ?? ScheduleEvent.at(12, 0))
        let match = profiles.first(where: { $0.name == initial?.name })?.id ?? profiles.first?.id
        _selectedProfileID = State(initialValue: match)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Start", selection: $time, displayedComponents: .hourAndMinute)
                        .foregroundStyle(SMA.labelPrimary)
                }

                Section("Activity") {
                    ForEach(model.activityProfiles) { profile in
                        Button {
                            selectedProfileID = profile.id
                        } label: {
                            HStack(spacing: 12) {
                                ProfileIcon(symbol: profile.symbol, colorHex: profile.colorHex, size: 30)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(profile.name)
                                        .foregroundStyle(SMA.labelPrimary)
                                    Text("Keep between: \(profile.rangeText)")
                                        .font(.footnote)
                                        .foregroundStyle(SMA.labelSecondary)
                                }
                                Spacer()
                                if profile.id == selectedProfileID {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(SMA.accent)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(profile.id == selectedProfileID ? [.isSelected] : [])
                    }

                    Button {
                        creatingProfile = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(SMA.accent)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(SMA.accent.opacity(0.12)))
                            Text("Create New Profile")
                                .foregroundStyle(SMA.accent)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(title)
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton(isEnabled: selectedProfileID != nil) {
                        if let profile = model.activityProfiles.first(where: { $0.id == selectedProfileID }) {
                            onSave(ScheduleEvent(from: profile, time: time))
                        }
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $creatingProfile) {
                EditActivityProfileView(profile: .new) { newProfile in
                    model.saveProfile(newProfile)
                    selectedProfileID = newProfile.id
                }
            }
        }
    }
}

// MARK: - Manual start time entry

/// A compact sheet for typing a period's start time, opened by tapping the time in
/// the center of the dial.
struct ManualStartTimeSheet: View {
    @Environment(\.dismiss) private var dismiss

    let name: String
    let onSave: (Date) -> Void
    @State private var time: Date

    init(name: String, time: Date, onSave: @escaping (Date) -> Void) {
        self.name = name
        self.onSave = onSave
        _time = State(initialValue: time)
    }

    var body: some View {
        NavigationStack {
            VStack {
                IntervalTimePicker(time: $time, minuteInterval: 15)
                    .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle("\(name) Start")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton(title: "Set") {
                        onSave(time)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// A wheels-style time picker with a fixed minute interval. SwiftUI's `DatePicker`
/// has no minute-interval option, so this wraps `UIDatePicker`.
private struct IntervalTimePicker: UIViewRepresentable {
    @Binding var time: Date
    var minuteInterval: Int = 15

    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .time
        picker.preferredDatePickerStyle = .wheels
        picker.minuteInterval = minuteInterval
        picker.date = time
        picker.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return picker
    }

    func updateUIView(_ picker: UIDatePicker, context: Context) {
        picker.minuteInterval = minuteInterval
        if picker.date != time { picker.date = time }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject {
        let parent: IntervalTimePicker
        init(_ parent: IntervalTimePicker) { self.parent = parent }
        @objc func changed(_ sender: UIDatePicker) { parent.time = sender.date }
    }
}

#Preview {
    NavigationStack {
        SchedulePresetsList(title: "Activity Schedule", presets: ["Default", "Custom 1", "Comfort"])
    }
    .environment(AppModel())
}
