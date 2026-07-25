import SwiftUI

// MARK: - Non-preset schedule (Program) flow
//
// The setpoint-based scheduling used when Use Presets is off. Unlike the
// preset flow in ScheduleFlow.swift (events are Activity Profile snapshots on a
// radial dial), here a schedule is split by mode into Heating / Cooling / Auto
// programs whose events are a bare Start time + setpoint. Prototype-local state,
// non-persistent — mirrors SchedulePresetsList.

/// The three non-preset schedule modes.
enum ScheduleKind: String, CaseIterable, Identifiable {
    case heat, cool, auto
    var id: String { rawValue }

    var listTitle: String {
        switch self {
        case .heat: "Heating Schedule"
        case .cool: "Cooling Schedule"
        case .auto: "Auto Schedule"
        }
    }
    var rowTitle: String { listTitle }
    /// The trailing detail shown on the Automation-tab rows.
    var detail: String {
        switch self {
        case .heat: "Heat"
        case .cool: "Cool"
        case .auto: "Auto"
        }
    }
    /// Which setpoints an event of this kind edits.
    var editsHeat: Bool { self != .cool }
    var editsCool: Bool { self != .heat }
}

// MARK: - Models

/// One scheduled period: a start time and the setpoint(s) it applies. Which
/// setpoints are meaningful depends on the schedule's `ScheduleKind`.
struct ProgramEvent: Identifiable, Hashable {
    let id = UUID()
    var time: Date
    var heatTo: Int
    var coolTo: Int

    var timeText: String { time.formatted(date: .omitted, time: .shortened) }

    func setpointText(for kind: ScheduleKind) -> String {
        switch kind {
        case .heat: "Heat to: \(heatTo)"
        case .cool: "Cool to: \(coolTo)"
        case .auto: "\(heatTo) · \(coolTo)"
        }
    }

    static func at(_ h: Int, _ m: Int) -> Date {
        Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date()) ?? Date()
    }
}

/// A set of days sharing the same list of events (e.g. "Weekdays" + "Weekend").
struct ProgramDayGroup: Identifiable, Hashable {
    let id = UUID()
    var days: Set<Int>
    var events: [ProgramEvent]
}

/// A named schedule program (one or more day groups).
struct ScheduleProgram: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var groups: [ProgramDayGroup]

    static func sampleEvents() -> [ProgramEvent] {
        [
            ProgramEvent(time: ProgramEvent.at(6, 0),  heatTo: 70, coolTo: 75),
            ProgramEvent(time: ProgramEvent.at(8, 0),  heatTo: 62, coolTo: 80),
            ProgramEvent(time: ProgramEvent.at(17, 0), heatTo: 70, coolTo: 74),
            ProgramEvent(time: ProgramEvent.at(22, 0), heatTo: 62, coolTo: 72),
        ]
    }

    static func makeSample(_ name: String) -> ScheduleProgram {
        ScheduleProgram(name: name, groups: [ProgramDayGroup(days: Set(0..<7), events: sampleEvents())])
    }

    static func samples(for kind: ScheduleKind) -> [ScheduleProgram] {
        switch kind {
        case .heat: [makeSample("Heat"), makeSample("Heat Custom 1")]
        case .cool: [makeSample("Cool"), makeSample("Cool Custom 1")]
        case .auto: [makeSample("Auto"), makeSample("Auto Custom 1")]
        }
    }
}

// MARK: - Program list (Heating / Cooling / Auto Schedule)

/// A radio-select list of schedule programs for one mode, with a per-row menu
/// and an add button. Mirrors `SchedulePresetsList`.
struct ProgramScheduleList: View {
    let kind: ScheduleKind

    @State private var programs: [ScheduleProgram]
    @State private var selection: UUID?
    /// Drives the create/edit sheet. A program whose id isn't in `programs` yet
    /// is new (create); an existing id edits in place.
    @State private var editor: ScheduleProgram?

    init(kind: ScheduleKind) {
        self.kind = kind
        let items = ScheduleProgram.samples(for: kind)
        _programs = State(initialValue: items)
        _selection = State(initialValue: items.first?.id)
    }

    var body: some View {
        List {
            Section {
                ForEach(programs) { program in
                    HStack(spacing: 12) {
                        // Sibling borderless buttons so the List hit-tests the row
                        // selection and the menu independently.
                        Button {
                            selection = program.id
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selection == program.id ? "largecircle.fill.circle" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(selection == program.id ? SMA.accent : SMA.labelSecondary)
                                    .accessibilityHidden(true)
                                Text(program.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityAddTraits(selection == program.id ? [.isSelected] : [])

                        Menu {
                            Button("Edit", systemImage: "pencil") { editor = program }
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(program) }
                            Button("Delete", systemImage: "trash", role: .destructive) { delete(program) }
                        } label: {
                            EllipsisMenuLabel()
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("More options for \(program.name)")
                    }
                }
            }
        }
        .groupedListChrome()
        .navigationTitle(kind.listTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    editor = ScheduleProgram(name: "", groups: [ProgramDayGroup(days: Set(0..<7), events: ScheduleProgram.sampleEvents())])
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $editor) { draft in
            ProgramScheduleEditor(kind: kind, program: draft) { result in
                if let i = programs.firstIndex(where: { $0.id == result.id }) {
                    programs[i] = result          // existing program: edit in place
                } else {
                    programs.append(result)       // new program: add and select it
                    selection = result.id
                }
            }
        }
    }

    private func duplicate(_ program: ScheduleProgram) {
        guard let i = programs.firstIndex(where: { $0.id == program.id }) else { return }
        programs.insert(ScheduleProgram(name: program.name + " Copy", groups: program.groups), at: i + 1)
    }

    private func delete(_ program: ScheduleProgram) {
        programs.removeAll { $0.id == program.id }
        if selection == program.id { selection = programs.first?.id }
    }
}

// MARK: - Program editor (name + day groups + events)

struct ProgramScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss

    let kind: ScheduleKind
    @State private var program: ScheduleProgram
    @State private var addTarget: ProgramGroupRef?
    @State private var editTarget: ProgramEventRef?
    let onSave: (ScheduleProgram) -> Void

    private let minEvents = 1
    private let maxEvents = 8

    init(kind: ScheduleKind, program: ScheduleProgram, onSave: @escaping (ScheduleProgram) -> Void) {
        self.kind = kind
        _program = State(initialValue: program)
        self.onSave = onSave
    }

    private var isNew: Bool { program.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name", text: $program.name)
                }

                ForEach(program.groups) { group in
                    Section {
                        DayPicker(days: group.days) { toggleDay($0, in: group.id) }

                        ForEach(group.events) { event in
                            eventRow(event, in: group)
                        }

                        Button {
                            addTarget = ProgramGroupRef(id: group.id)
                        } label: {
                            Text("Add Event")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .foregroundStyle(SMA.accent)
                        }
                        .disabled(group.events.count >= maxEvents)
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
                                .disabled(program.groups.count <= 1)
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
                        Text("Add Day Group")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(SMA.accent)
                    }
                }
            }
            .groupedListChrome()
            .navigationTitle(isNew ? "New \(kind.detail) Schedule" : "Edit Schedule")
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
                        onSave(program)
                        dismiss()
                    }
                }
            }
            .sheet(item: $addTarget) { target in
                ProgramEventEditor(kind: kind, title: "Add Event", initial: nil) { event in
                    addEvent(event, to: target.id)
                }
            }
            .sheet(item: $editTarget) { target in
                ProgramEventEditor(kind: kind, title: "Edit Event", initial: target.event) { updated in
                    replaceEvent(target.event.id, with: updated)
                }
            }
        }
    }

    // MARK: Rows

    private func eventRow(_ event: ProgramEvent, in group: ProgramDayGroup) -> some View {
        HStack(spacing: 12) {
            Text(event.setpointText(for: kind))
                .foregroundStyle(SMA.labelPrimary)
            Spacer(minLength: 8)
            Text(event.timeText)
                .foregroundStyle(SMA.labelSecondary)
                .monospacedDigit()
            Menu {
                Button("Edit", systemImage: "pencil") { editTarget = ProgramEventRef(groupID: group.id, event: event) }
                Button("Delete", systemImage: "trash", role: .destructive) { deleteEvent(event.id, from: group.id) }
                    .disabled(group.events.count <= minEvents)
            } label: {
                EllipsisMenuLabel()
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Options for event at \(event.timeText)")
        }
        .contentShape(Rectangle())
        .onTapGesture { editTarget = ProgramEventRef(groupID: group.id, event: event) }
    }

    // MARK: Mutations

    private func groupIndex(_ id: ProgramDayGroup.ID) -> Int? { program.groups.firstIndex { $0.id == id } }

    private func toggleDay(_ i: Int, in id: ProgramDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        if program.groups[g].days.contains(i) { program.groups[g].days.remove(i) } else { program.groups[g].days.insert(i) }
    }

    private func addEvent(_ event: ProgramEvent, to id: ProgramDayGroup.ID) {
        guard let g = groupIndex(id), program.groups[g].events.count < maxEvents else { return }
        program.groups[g].events.append(event)
        program.groups[g].events.sort { $0.time < $1.time }
    }

    private func deleteEvent(_ eventID: ProgramEvent.ID, from id: ProgramDayGroup.ID) {
        guard let g = groupIndex(id), program.groups[g].events.count > minEvents else { return }
        program.groups[g].events.removeAll { $0.id == eventID }
    }

    private func replaceEvent(_ eventID: ProgramEvent.ID, with new: ProgramEvent) {
        for g in program.groups.indices {
            if let e = program.groups[g].events.firstIndex(where: { $0.id == eventID }) {
                program.groups[g].events[e].time = new.time
                program.groups[g].events[e].heatTo = new.heatTo
                program.groups[g].events[e].coolTo = new.coolTo
                program.groups[g].events.sort { $0.time < $1.time }
                return
            }
        }
    }

    private func addDayGroup() {
        withAnimation(.snappy) {
            program.groups.append(ProgramDayGroup(days: [], events: ScheduleProgram.sampleEvents()))
        }
    }

    private func removeGroup(_ id: ProgramDayGroup.ID) {
        withAnimation(.snappy) { program.groups.removeAll { $0.id == id } }
    }

}

/// Identifiable wrapper so a day-group id can drive `.sheet(item:)` (Add Event).
private struct ProgramGroupRef: Identifiable {
    let id: ProgramDayGroup.ID
}

/// Identifiable wrapper for the Edit Event sheet, carrying the event + its group.
private struct ProgramEventRef: Identifiable {
    var id: ProgramEvent.ID { event.id }
    let groupID: ProgramDayGroup.ID
    let event: ProgramEvent
}

// MARK: - Event editor (Start time + setpoint)

struct ProgramEventEditor: View {
    @Environment(\.dismiss) private var dismiss

    let kind: ScheduleKind
    let title: String
    let onSave: (ProgramEvent) -> Void

    @State private var time: Date
    @State private var heatTo: Int
    @State private var coolTo: Int

    init(kind: ScheduleKind, title: String, initial: ProgramEvent?, onSave: @escaping (ProgramEvent) -> Void) {
        self.kind = kind
        self.title = title
        self.onSave = onSave
        _time = State(initialValue: initial?.time ?? ProgramEvent.at(12, 0))
        _heatTo = State(initialValue: initial?.heatTo ?? 70)
        _coolTo = State(initialValue: initial?.coolTo ?? 75)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Start", selection: $time, displayedComponents: .hourAndMinute)
                        .foregroundStyle(SMA.labelPrimary)
                }

                Section("Setpoint") {
                    if kind.editsHeat {
                        Stepper(value: $heatTo, in: SetpointConfig.minTemp...SetpointConfig.maxTemp) {
                            HStack {
                                Text("Heat to")
                                Spacer()
                                Text("\(heatTo)")
                                    .foregroundStyle(SMA.labelSecondary)
                                    .monospacedDigit()
                            }
                        }
                        .onChange(of: heatTo) { _, v in
                            // In Auto, keep the cool setpoint at least a deadband above heat.
                            if kind.editsCool, coolTo < v + SetpointConfig.deadband {
                                coolTo = min(v + SetpointConfig.deadband, SetpointConfig.maxTemp)
                            }
                        }
                    }
                    if kind.editsCool {
                        Stepper(value: $coolTo, in: SetpointConfig.minTemp...SetpointConfig.maxTemp) {
                            HStack {
                                Text("Cool to")
                                Spacer()
                                Text("\(coolTo)")
                                    .foregroundStyle(SMA.labelSecondary)
                                    .monospacedDigit()
                            }
                        }
                        .onChange(of: coolTo) { _, v in
                            if kind.editsHeat, heatTo > v - SetpointConfig.deadband {
                                heatTo = max(v - SetpointConfig.deadband, SetpointConfig.minTemp)
                            }
                        }
                    }
                }
            }
            .groupedListChrome()
            .navigationTitle(title)
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton {
                        onSave(ProgramEvent(time: time, heatTo: heatTo, coolTo: coolTo))
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProgramScheduleList(kind: .heat)
    }
    .environment(AppModel())
}
