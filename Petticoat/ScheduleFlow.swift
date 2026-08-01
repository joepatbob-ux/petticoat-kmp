import SwiftUI
import UIKit

// MARK: - Models

struct SchedulePreset: Identifiable, Hashable {
    let id = UUID()
    var name: String
    /// The schedule itself: one or more day groups, each with its own events.
    var groups: [ScheduleDayGroup] = [ScheduleDayGroup(days: Set(0..<7), events: ScheduleEvent.samples())]

    /// Default saved schedules, all week on the sample events.
    static func samples() -> [SchedulePreset] {
        [SchedulePreset(name: "Comfort"), SchedulePreset(name: "Eco")]
    }
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

    /// Whether `other` snapshots the same activity (ignoring start time).
    func sameActivity(as other: ScheduleEvent) -> Bool {
        name == other.name && symbol == other.symbol && colorHex == other.colorHex
            && heatTo == other.heatTo && coolTo == other.coolTo
    }

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

/// A radio-select list of schedule presets. Each row selects the running schedule;
/// tapping it (or the Edit swipe) drills into the editor. Swipe also offers Duplicate
/// and Delete; a "+" adds a new one.
struct SchedulePresetsList: View {
    let title: String

    @Environment(AppModel.self) private var model
    /// Drives the drill-in editor. A preset whose id isn't in the model yet is a new one
    /// (create); an existing id edits in place.
    @State private var editorPreset: SchedulePreset?

    /// The schedule shown as selected (the model's active one).
    private var selectedID: SchedulePreset.ID? { model.activeSchedule?.id }

    var body: some View {
        List {
            Section {
                ForEach(model.schedules) { preset in
                    HStack(spacing: 12) {
                        // Sibling controls with .borderless button styles so the List
                        // hit-tests the radio and the drill-in independently.
                        Button {
                            model.selectSchedule(preset.id)
                        } label: {
                            Image(systemName: selectedID == preset.id ? "largecircle.fill.circle" : "circle")
                                .font(.title3)
                                .foregroundStyle(selectedID == preset.id ? SMA.accent : SMA.labelSecondary)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Select \(preset.name)")
                        .accessibilityAddTraits(selectedID == preset.id ? [.isSelected] : [])

                        Button {
                            editorPreset = preset
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(SMA.labelSecondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Edit \(preset.name)")
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { model.deleteSchedule(preset.id) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        Button { model.duplicateSchedule(preset) } label: {
                            Label("Duplicate", systemImage: "plus.square.on.square")
                        }
                        .tint(SMA.accent)
                        Button { editorPreset = preset } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(.gray)
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
                Menu {
                    Button("New Schedule", systemImage: "plus") {
                        editorPreset = SchedulePreset(name: "")
                    }
                    if let active = model.activeSchedule {
                        Button("Duplicate \"\(active.name)\"", systemImage: "plus.square.on.square") {
                            model.duplicateSchedule(active)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(item: $editorPreset) { draft in
            let existing = model.schedules.contains { $0.id == draft.id }
            ScheduleEditorView(
                preset: draft,
                onSave: { model.saveSchedule($0) },
                onDelete: existing ? { model.deleteSchedule(draft.id) } : nil
            )
        }
    }
}

// MARK: - Edit Schedule (name + day groups + radial dial + events)

struct ScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var preset: SchedulePreset
    @State private var selectedEventID: ScheduleEvent.ID?
    /// Which day groups have their event details expanded — tracked per group so each
    /// card's "Show Details" is independent.
    @State private var detailGroups: Set<ScheduleDayGroup.ID> = []
    @State private var addTarget: GroupTarget?
    @State private var editTarget: EventTarget?
    @State private var timeTarget: EventTarget?
    /// Validation message shown when Save is blocked (uncovered days / empty group).
    @State private var saveWarning: String?
    let onSave: (SchedulePreset) -> Void
    /// Present when editing an existing schedule — drives the Delete action. Nil while
    /// creating a new one.
    var onDelete: (() -> Void)?

    private let minEvents = 1
    private let maxEvents = 8
    /// The 15-minute grid every start time snaps to.
    private let snapMinutes = 15
    /// The one-hour floor dial gestures keep on every piece — a drag-only, visual floor
    /// (arcs stay big enough to grab; the sandwiched slide honors it too). Manual entry
    /// may still set finer sub-hour periods on the 15-minute grid.
    private let minDurationMinutes = 60

    init(preset: SchedulePreset, onSave: @escaping (SchedulePreset) -> Void, onDelete: (() -> Void)? = nil) {
        _preset = State(initialValue: preset)
        _selectedEventID = State(initialValue: preset.groups.first?.events.first?.id)
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $preset.name)
            }

            ForEach(preset.groups) { group in
                Section {
                    DayPicker(days: group.days, usedElsewhere: daysUsedElsewhere(than: group.id)) {
                        toggleDay($0, in: group.id)
                    }

                    RadialScheduleDial(
                        events: group.events,
                        selectedID: selectedEventID,
                        onChangeStart: { id, newTime in setEventTime(id, to: newTime) },
                        onSelect: { id in selectedEventID = id },
                        onCommitDrop: { moves, tailCopy in
                            commitDrop(moves, tailCopy: tailCopy, in: group.id)
                        },
                        onRequestManualTime: { id in
                            if let event = group.events.first(where: { $0.id == id }) {
                                timeTarget = EventTarget(groupID: group.id, event: event)
                            }
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

                        let expanded = detailGroups.contains(group.id)
                        Button {
                            withAnimation(.snappy) {
                                if expanded { detailGroups.remove(group.id) } else { detailGroups.insert(group.id) }
                            }
                        } label: {
                            Text(expanded ? "Hide Details" : "Show Details")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SMA.accent)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(expanded ? "Hide event details" : "Show event details")

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

                    if detailGroups.contains(group.id) {
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
                            Button("Duplicate Day Group", systemImage: "plus.square.on.square") {
                                duplicateGroup(group.id)
                            }
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
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle(onDelete == nil ? "Create Schedule" : "Edit Schedule")
        .inlineNavTitle()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { model.showHelp = true } label: { Image(systemName: "questionmark.bubble") }
                    .accessibilityLabel("Help and Support")
                EditorSaveButton {
                    if let issue = validationIssue() {
                        saveWarning = issue
                    } else {
                        onSave(preset)
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
            ScheduleEventEditor(title: "Add Event", initial: nil, profiles: model.activityProfiles) { event in
                addEvent(event, to: target.id)
            }
        }
        .sheet(item: $editTarget) { target in
            let canDelete = (preset.groups.first { $0.id == target.groupID }?.events.count ?? 0) > minEvents
            ScheduleEventEditor(
                title: "Edit Event",
                initial: target.event,
                profiles: model.activityProfiles,
                onDelete: canDelete ? { deleteEvent(target.event.id, from: target.groupID) } : nil
            ) { updated in
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
            Button {
                editTarget = EventTarget(groupID: group.id, event: event)
            } label: {
                Image(systemName: "info.circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(SMA.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(event.name)")
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

    /// Days claimed by every day group except the given one — the picker's grey-dot state.
    private func daysUsedElsewhere(than id: ScheduleDayGroup.ID) -> Set<Int> {
        preset.groups.reduce(into: Set<Int>()) { if $1.id != id { $0.formUnion($1.days) } }
    }

    /// Why the schedule can't be saved yet, or nil when it's valid: every day of the week
    /// must belong to a day group, and every day group needs at least one event.
    private func validationIssue() -> String? {
        let covered = preset.groups.reduce(into: Set<Int>()) { $0.formUnion($1.days) }
        let missing = Set(0..<7).subtracting(covered)
        if !missing.isEmpty {
            let names = missing.sorted().map { WeekDay.names[$0] }.joined(separator: ", ")
            return "Every day needs a day group. Not scheduled yet: \(names)."
        }
        if preset.groups.contains(where: { $0.events.isEmpty }) {
            return "Every day group needs at least one event."
        }
        return nil
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

    /// Replace a selected event's start time (from the dial's grip or the manual sheet),
    /// snapping to the 15-min grid and keeping the list sorted. The one-hour floor is a
    /// drag-only, visual minimum (the dial clamps its gestures before calling) — manual
    /// entry may set finer sub-hour periods. An event sandwiched between two pieces of
    /// the same activity slides instead of resizing (see `slideBetweenSamePieces`).
    private func setEventTime(_ eventID: ScheduleEvent.ID, to newTime: Date) {
        for g in preset.groups.indices {
            guard let e = preset.groups[g].events.firstIndex(where: { $0.id == eventID }) else { continue }
            let snapped = DialMath.snapToGrid(minutesOfDay(newTime), snap: snapMinutes)
            if !slideBetweenSamePieces(at: e, to: snapped, in: g) {
                preset.groups[g].events[e].time = dateAtMinutes(snapped)
                preset.groups[g].events.sort { $0.time < $1.time }
            }
            mergeAdjacentSameEvents(in: g)
            return
        }
    }

    /// When the same activity sits on both sides of a moved event, a start change slides
    /// the event between the two pieces instead of resizing it: the event keeps its
    /// duration and its tail (the following piece) moves with it, so the piece before
    /// shrinks while the one after grows — or vice versa — each keeping the one-hour
    /// floor. Returns false when the event isn't sandwiched, or the room between the
    /// outer neighbors can't fit the slide; the normal resize path applies instead.
    private func slideBetweenSamePieces(at idx: Int, to proposed: Int, in g: Int) -> Bool {
        let evs = preset.groups[g].events
        let n = evs.count
        guard n >= 3 else { return false }
        let prevIdx = (idx - 1 + n) % n
        let nextIdx = (idx + 1) % n
        let afterIdx = (idx + 2) % n
        guard evs[prevIdx].sameActivity(as: evs[nextIdx]) else { return false }
        let start = minutesOfDay(evs[idx].time)
        let dur = DialMath.cwDistance(start, minutesOfDay(evs[nextIdx].time))
        let prev = minutesOfDay(evs[prevIdx].time)
        let span = afterIdx == prevIdx ? 1440 : DialMath.cwDistance(prev, minutesOfDay(evs[afterIdx].time))
        // The event's duration is reserved out of the room; what's left must still fit
        // the head and tail pieces at the floor.
        let room = span - dur
        guard room >= 2 * minDurationMinutes else { return false }
        let newStart = DialMath.clampStart(proposed, prev: prev, span: room, minLen: minDurationMinutes)
        preset.groups[g].events[idx].time = dateAtMinutes(newStart)
        preset.groups[g].events[nextIdx].time = dateAtMinutes((newStart + dur) % 1440)
        preset.groups[g].events.sort { $0.time < $1.time }
        return true
    }


    /// Applies a dial pickup-and-move drop: start-time changes for the moved (and possibly
    /// pushed) events, plus an optional tail copy when an event's interior was broken. The
    /// tail is skipped at the event cap — the moved event then absorbs it.
    private func commitDrop(_ moves: [(id: ScheduleEvent.ID, time: Date)],
                            tailCopy: ScheduleEvent?, in id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        for move in moves {
            guard let e = preset.groups[g].events.firstIndex(where: { $0.id == move.id }) else { continue }
            preset.groups[g].events[e].time = dateAtMinutes(DialMath.snapToGrid(minutesOfDay(move.time), snap: snapMinutes))
        }
        if let tailCopy, preset.groups[g].events.count < maxEvents {
            preset.groups[g].events.append(tailCopy)
        }
        preset.groups[g].events.sort { $0.time < $1.time }
        mergeAdjacentSameEvents(in: g)
    }

    /// After a drag move, collapse any two adjacent events that share the same activity
    /// into one — keeping the earlier start time.
    private func mergeAdjacentSameEvents(in g: Int) {
        var evs = preset.groups[g].events
        guard evs.count > 1 else { return }
        var i = 0
        while i < evs.count {
            let next = (i + 1) % evs.count
            if evs[i].sameActivity(as: evs[next]) {
                evs.remove(at: next > i ? next : i)
                if evs.count <= 1 { break }
            } else {
                i += 1
            }
        }
        if evs.count != preset.groups[g].events.count {
            preset.groups[g].events = evs
        }
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

    private func duplicateGroup(_ id: ScheduleDayGroup.ID) {
        guard let g = groupIndex(id) else { return }
        // Copy the events (fresh ids); clear the days so the two groups don't claim the
        // same days — the user assigns days to the copy.
        let copy = ScheduleDayGroup(days: [], events: preset.groups[g].events.map {
            ScheduleEvent(name: $0.name, symbol: $0.symbol, colorHex: $0.colorHex,
                          heatTo: $0.heatTo, coolTo: $0.coolTo, time: $0.time)
        })
        withAnimation(.snappy) { preset.groups.insert(copy, at: g + 1) }
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
/// Minutes since midnight for a time-of-day `Date`.
private func minutesOfDay(_ date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
}

/// A today-anchored `Date` at the given minutes since midnight.
private func dateAtMinutes(_ minutes: Int) -> Date {
    let m = ((minutes % 1440) + 1440) % 1440
    return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
}

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
    /// Present when editing an existing event — drives the Delete Event section. Nil
    /// while adding a new one (or when the group is at its minimum).
    let onDelete: (() -> Void)?

    @State private var selectedProfileID: ActivityProfile.ID?
    @State private var time: Date
    @State private var creatingProfile = false

    init(title: String, initial: ScheduleEvent?, profiles: [ActivityProfile],
         onDelete: (() -> Void)? = nil, onSave: @escaping (ScheduleEvent) -> Void) {
        self.title = title
        self.profiles = profiles
        self.onDelete = onDelete
        self.onSave = onSave
        _time = State(initialValue: initial?.time ?? ScheduleEvent.at(12, 0))
        let match = profiles.first(where: { $0.name == initial?.name })?.id ?? profiles.first?.id
        _selectedProfileID = State(initialValue: match)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Start") {
                    IntervalTimePicker(time: $time, minuteInterval: 15)
                        .frame(height: 180)
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
/// has no minute-interval option, so this wraps `UIDatePicker`. Shared by the manual
/// start sheet and the Add/Edit event editors so every start time lands on the grid.
struct IntervalTimePicker: UIViewRepresentable {
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
        SchedulePresetsList(title: "Activity Schedule")
    }
    .environment(AppModel())
}
