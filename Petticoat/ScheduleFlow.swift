import SwiftUI

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

struct ScheduleEvent: Identifiable, Hashable {
    let id = UUID()
    var setpoint: Int
    var time: Date

    var timeText: String { time.formatted(date: .omitted, time: .shortened) }

    static func samples() -> [ScheduleEvent] {
        func at(_ h: Int, _ m: Int) -> Date {
            Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
        }
        return [
            ScheduleEvent(setpoint: 70, time: at(6, 0)),
            ScheduleEvent(setpoint: 62, time: at(8, 0)),
            ScheduleEvent(setpoint: 70, time: at(17, 0)),
            ScheduleEvent(setpoint: 62, time: at(22, 0)),
        ]
    }
}

// MARK: - Presets list (Activity Schedule / Schedules)

/// A radio-select list of schedule presets with a per-row menu and an add button.
struct SchedulePresetsList: View {
    let title: String

    @State private var presets: [SchedulePreset]
    @State private var selection: UUID?
    @State private var editing: SchedulePreset?
    @State private var creating: SchedulePreset?

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
                            Menu {
                                Button("Edit", systemImage: "pencil") { editing = preset }
                                Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(preset) }
                                Button("Delete", systemImage: "trash", role: .destructive) { delete(preset) }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(SMA.accent)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("More options for \(preset.name)")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == preset.id ? [.isSelected] : [])
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
                Button { creating = SchedulePreset(name: "") } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $creating) { draft in
            ScheduleEditorView(preset: draft) { new in
                presets.append(new)
                selection = new.id
            }
        }
        .sheet(item: $editing) { preset in
            ScheduleEditorView(preset: preset) { updated in
                if let i = presets.firstIndex(where: { $0.id == updated.id }) {
                    presets[i] = updated
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

// MARK: - Edit Schedule (name + days + events)

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var preset: SchedulePreset
    @State private var editingEvent: ScheduleEvent?
    @State private var addingEventGroup: ScheduleDayGroup.ID?
    let onSave: (SchedulePreset) -> Void

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(preset: SchedulePreset, onSave: @escaping (SchedulePreset) -> Void) {
        _preset = State(initialValue: preset)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $preset.name)
                }

                ForEach(preset.groups) { group in
                    Section {
                        dayPicker(for: group)

                        ForEach(group.events) { event in
                            Button {
                                editingEvent = event
                            } label: {
                                HStack {
                                    Text("Heat to: \(event.setpoint)")
                                        .foregroundStyle(SMA.labelPrimary)
                                    Spacer()
                                    Text(event.timeText)
                                        .foregroundStyle(SMA.labelSecondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { deleteEvents($0, from: group.id) }

                        Button("Add Event", systemImage: "plus") { addingEventGroup = group.id }

                        if preset.groups.count > 1 {
                            Button("Remove Day Group", systemImage: "trash", role: .destructive) {
                                removeGroup(group.id)
                            }
                        }
                    } header: {
                        Text(daysSummary(group.days))
                    }
                }

                Section {
                    Button("Add Day Group", systemImage: "plus") { addDayGroup() }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle("Edit Schedule")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(preset)
                        dismiss()
                    }
                }
            }
            .sheet(item: Binding(get: { addingEventGroup.map { GroupTarget(id: $0) } },
                                 set: { addingEventGroup = $0?.id })) { target in
                EditEventView(setpoint: 70, time: Date()) { event in
                    addEvent(event, to: target.id)
                }
            }
            .sheet(item: $editingEvent) { event in
                EditEventView(setpoint: event.setpoint, time: event.time) { updated in
                    updateEvent(event.id, setpoint: updated.setpoint, time: updated.time)
                }
            }
        }
    }

    // MARK: - Day picker

    private func dayPicker(for group: ScheduleDayGroup) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = group.days.contains(i)
                Button {
                    toggleDay(i, in: group.id)
                } label: {
                    Text(dayLabels[i])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? .white : SMA.labelPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(on ? SMA.accent : SMA.fillTertiary))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(dayNames[i])
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Mutations

    private func groupIndex(_ id: ScheduleDayGroup.ID) -> Int? { preset.groups.firstIndex { $0.id == id } }

    private func toggleDay(_ i: Int, in id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        if preset.groups[g].days.contains(i) { preset.groups[g].days.remove(i) } else { preset.groups[g].days.insert(i) }
    }

    private func deleteEvents(_ offsets: IndexSet, from id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        preset.groups[g].events.remove(atOffsets: offsets)
    }

    private func addEvent(_ event: ScheduleEvent, to id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        preset.groups[g].events.append(event)
        preset.groups[g].events.sort { $0.time < $1.time }
    }

    private func updateEvent(_ eventID: ScheduleEvent.ID, setpoint: Int, time: Date) {
        for g in preset.groups.indices {
            if let e = preset.groups[g].events.firstIndex(where: { $0.id == eventID }) {
                preset.groups[g].events[e].setpoint = setpoint
                preset.groups[g].events[e].time = time
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

    private func daysSummary(_ days: Set<Int>) -> String {
        if days.isEmpty { return "No Days Selected" }
        if days == Set(0..<7) { return "All Week" }
        if days == Set(0..<5) { return "Weekdays" }
        if days == Set(5..<7) { return "Weekend" }
        let short = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return days.sorted().map { short[$0] }.joined(separator: ", ")
    }
}

/// Identifiable wrapper so a day-group id can drive a `.sheet(item:)`.
private struct GroupTarget: Identifiable {
    let id: ScheduleDayGroup.ID
}

// MARK: - Edit Event (start time + setpoint)

struct EditEventView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var time: Date
    @State private var setpoint: Int
    let onSave: (ScheduleEvent) -> Void

    init(setpoint: Int, time: Date, onSave: @escaping (ScheduleEvent) -> Void) {
        _setpoint = State(initialValue: setpoint)
        _time = State(initialValue: time)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Start", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section("Setpoint") {
                    Stepper(value: $setpoint, in: 45...95) {
                        LabeledContent("Heat to", value: "\(setpoint)")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .foregroundStyle(SMA.labelPrimary)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle("Edit Event")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSave(ScheduleEvent(setpoint: setpoint, time: time))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .accessibilityLabel("Save")
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SchedulePresetsList(title: "Activity Schedule", presets: ["Default", "Custom 1", "Comfort"])
    }
    .environment(AppModel())
}
