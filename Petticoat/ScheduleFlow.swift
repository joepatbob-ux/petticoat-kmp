import SwiftUI

// MARK: - Models

struct SchedulePreset: Identifiable, Hashable {
    let id = UUID()
    var name: String
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
    @State private var editingName: String?
    @State private var creatingNew = false

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
                                Button("Edit", systemImage: "pencil") { editingName = preset.name }
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
                Button { creatingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $creatingNew) {
            ScheduleEditorView(scheduleName: "")
        }
        .sheet(item: Binding(get: { editingName.map { NamedSheet(name: $0) } },
                             set: { editingName = $0?.name })) { sheet in
            ScheduleEditorView(scheduleName: sheet.name)
        }
    }

    private func duplicate(_ preset: SchedulePreset) {
        guard let i = presets.firstIndex(of: preset) else { return }
        presets.insert(SchedulePreset(name: preset.name + " Copy"), at: i + 1)
    }

    private func delete(_ preset: SchedulePreset) {
        presets.removeAll { $0.id == preset.id }
        if selection == preset.id { selection = presets.first?.id }
    }
}

/// Identifiable wrapper so a plain name string can drive a `.sheet(item:)`.
private struct NamedSheet: Identifiable {
    let id = UUID()
    let name: String
}

// MARK: - Edit Schedule (name + days + events)

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// A set of days sharing the same list of events. A schedule is one or more
    /// of these (e.g. "Weekdays" + "Weekend").
    private struct DayGroup: Identifiable {
        let id = UUID()
        var days: Set<Int>
        var events: [ScheduleEvent]
    }

    @State private var scheduleName: String
    @State private var groups: [DayGroup]
    @State private var editingEvent: ScheduleEvent?
    @State private var addingEventGroup: DayGroup.ID?

    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
    private let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(scheduleName: String) {
        _scheduleName = State(initialValue: scheduleName)
        _groups = State(initialValue: [DayGroup(days: Set(0..<7), events: ScheduleEvent.samples())])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $scheduleName)
                }

                ForEach(groups) { group in
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

                        if groups.count > 1 {
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
            .sheet(isPresented: Binding(get: { addingEventGroup != nil },
                                        set: { if !$0 { addingEventGroup = nil } })) {
                EditEventView(setpoint: 70, time: Date()) { event in
                    if let id = addingEventGroup { addEvent(event, to: id) }
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

    private func dayPicker(for group: DayGroup) -> some View {
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

    private func groupIndex(_ id: DayGroup.ID) -> Int? { groups.firstIndex { $0.id == id } }

    private func toggleDay(_ i: Int, in id: DayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        if groups[g].days.contains(i) { groups[g].days.remove(i) } else { groups[g].days.insert(i) }
    }

    private func deleteEvents(_ offsets: IndexSet, from id: DayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        groups[g].events.remove(atOffsets: offsets)
    }

    private func addEvent(_ event: ScheduleEvent, to id: DayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        groups[g].events.append(event)
        groups[g].events.sort { $0.time < $1.time }
    }

    private func updateEvent(_ eventID: ScheduleEvent.ID, setpoint: Int, time: Date) {
        for g in groups.indices {
            if let e = groups[g].events.firstIndex(where: { $0.id == eventID }) {
                groups[g].events[e].setpoint = setpoint
                groups[g].events[e].time = time
                groups[g].events.sort { $0.time < $1.time }
                return
            }
        }
    }

    private func addDayGroup() {
        withAnimation(.snappy) {
            groups.append(DayGroup(days: [], events: ScheduleEvent.samples()))
        }
    }

    private func removeGroup(_ id: DayGroup.ID) {
        withAnimation(.snappy) { groups.removeAll { $0.id == id } }
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
