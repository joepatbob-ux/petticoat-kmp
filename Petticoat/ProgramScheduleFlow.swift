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

/// A radio-select list of schedule programs for one mode. Rows select the running
/// program and drill into the editor; swipe offers Delete / Duplicate / Edit. Backed by
/// the model so the selected program drives the controller timeline.
struct ProgramScheduleList: View {
    let kind: ScheduleKind

    @Environment(AppModel.self) private var model
    /// Drives the drill-in editor (new when its id isn't in the model yet).
    @State private var editor: ScheduleProgram?

    private var programs: [ScheduleProgram] { model.programs[kind] ?? [] }
    private var selectedID: ScheduleProgram.ID? { model.activeProgramID(for: kind) }

    var body: some View {
        List {
            Section {
                ForEach(programs) { program in
                    HStack(spacing: 12) {
                        // Sibling borderless buttons so the List hit-tests the radio and
                        // the drill-in independently.
                        Button {
                            model.selectProgram(program.id, kind: kind)
                        } label: {
                            Image(systemName: selectedID == program.id ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedID == program.id ? SMA.accent : SMA.labelSecondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Select \(program.name)")
                        .accessibilityAddTraits(selectedID == program.id ? [.isSelected] : [])

                        Button {
                            editor = program
                        } label: {
                            HStack {
                                Text(program.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(SMA.labelSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(program.name)")
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { model.deleteProgram(program.id, kind: kind) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { model.duplicateProgram(program, kind: kind) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(SMA.accent)
                        Button { editor = program } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
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
        .navigationDestination(item: $editor) { draft in
            let existing = programs.contains { $0.id == draft.id }
            ProgramScheduleEditor(
                kind: kind,
                program: draft,
                onSave: { model.saveProgram($0, kind: kind) },
                onDelete: existing ? { model.deleteProgram(draft.id, kind: kind) } : nil
            )
        }
    }
}

// MARK: - Program editor (name + day groups + events)

struct ProgramScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    let kind: ScheduleKind
    @State private var program: ScheduleProgram
    @State private var addTarget: ProgramGroupRef?
    @State private var editTarget: ProgramEventRef?
    /// Validation message shown when Save is blocked (uncovered days / empty group).
    @State private var saveWarning: String?
    let onSave: (ScheduleProgram) -> Void
    /// Present when editing an existing program — drives the Delete action. Nil while
    /// creating a new one.
    var onDelete: (() -> Void)?

    private let minEvents = 1
    private let maxEvents = 8

    init(kind: ScheduleKind, program: ScheduleProgram, onSave: @escaping (ScheduleProgram) -> Void, onDelete: (() -> Void)? = nil) {
        self.kind = kind
        _program = State(initialValue: program)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $program.name)
            }

            ForEach(program.groups) { group in
                Section {
                    DayPicker(days: group.days, usedElsewhere: daysUsedElsewhere(than: group.id)) {
                        toggleDay($0, in: group.id)
                    }

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
                            Button("Duplicate Day Group", systemImage: "plus.square.on.square") {
                                duplicateGroup(group.id)
                            }
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

            if let onDelete {
                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Delete Schedule")
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(SMA.destructive)
                    }
                }
            }
        }
        .groupedListChrome()
        .navigationTitle(onDelete == nil ? "New \(kind.detail) Schedule" : "Edit Schedule")
        .inlineNavTitle()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.showHelp = true } label: { Image(systemName: "questionmark.bubble") }
                    .accessibilityLabel("Help and Support")
                EditorSaveButton {
                    if let issue = validationIssue() {
                        saveWarning = issue
                    } else {
                        onSave(program)
                        dismiss()
                    }
                }
            }
        }
        .alert("Can't Save Schedule", isPresented: Binding(
            get: { saveWarning != nil },
            set: { if !$0 { saveWarning = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveWarning ?? "")
        }
        .sheet(item: $addTarget) { target in
            ProgramEventEditor(kind: kind, title: "Add Event", initial: nil) { event in
                addEvent(event, to: target.id)
            }
        }
        .sheet(item: $editTarget) { target in
            let canDelete = (program.groups.first { $0.id == target.groupID }?.events.count ?? 0) > minEvents
            ProgramEventEditor(
                kind: kind,
                title: "Edit Event",
                initial: target.event,
                onDelete: canDelete ? { deleteEvent(target.event.id, from: target.groupID) } : nil
            ) { updated in
                replaceEvent(target.event.id, with: updated)
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
            Button {
                editTarget = ProgramEventRef(groupID: group.id, event: event)
            } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SMA.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit event at \(event.timeText)")
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

    /// Days claimed by every day group except the given one — the picker's grey-dot state.
    private func daysUsedElsewhere(than id: ProgramDayGroup.ID) -> Set<Int> {
        program.groups.reduce(into: Set<Int>()) { if $1.id != id { $0.formUnion($1.days) } }
    }

    /// Why the schedule can't be saved yet, or nil when it's valid: every day of the week
    /// must belong to a day group, and every day group needs at least one event.
    private func validationIssue() -> String? {
        let covered = program.groups.reduce(into: Set<Int>()) { $0.formUnion($1.days) }
        let missing = Set(0..<7).subtracting(covered)
        if !missing.isEmpty {
            let names = missing.sorted().map { WeekDay.names[$0] }.joined(separator: ", ")
            return "Every day needs a day group. Not scheduled yet: \(names)."
        }
        if program.groups.contains(where: { $0.events.isEmpty }) {
            return "Every day group needs at least one event."
        }
        return nil
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

    private func duplicateGroup(_ id: ProgramDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        // Copy the events (fresh ids); clear the days so the copy doesn't claim the
        // same days — the user assigns days to it.
        let copy = ProgramDayGroup(days: [], events: program.groups[g].events.map {
            ProgramEvent(time: $0.time, heatTo: $0.heatTo, coolTo: $0.coolTo)
        })
        withAnimation(.snappy) { program.groups.insert(copy, at: g + 1) }
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
    /// Present when editing an existing event — drives the Delete Event section. Nil
    /// while adding a new one (or when the group is at its minimum).
    let onDelete: (() -> Void)?

    @State private var time: Date
    @State private var heatTo: Int
    @State private var coolTo: Int

    init(kind: ScheduleKind, title: String, initial: ProgramEvent?,
         onDelete: (() -> Void)? = nil, onSave: @escaping (ProgramEvent) -> Void) {
        self.kind = kind
        self.title = title
        self.onDelete = onDelete
        self.onSave = onSave
        _time = State(initialValue: initial?.time ?? ProgramEvent.at(12, 0))
        _heatTo = State(initialValue: initial?.heatTo ?? 70)
        _coolTo = State(initialValue: initial?.coolTo ?? 75)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Start") {
                    IntervalTimePicker(time: $time, minuteInterval: 15)
                        .frame(height: 180)
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

                if let onDelete {
                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete Event")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(SMA.destructive)
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
