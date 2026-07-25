import SwiftUI

// MARK: - Vacations
//
// Multiple saved vacation schedules. Each can be toggled on to hold an
// energy-saving temperature over its date range; tapping a row opens its
// settings (name + inline date range). Prototype-local state, non-persistent.

struct VacationTrip: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var start: Date
    var end: Date
    var isActive: Bool = false
    /// The activity profile whose temperatures are held while the vacation is active.
    /// `nil` falls back to the default energy-saving hold.
    var profileID: UUID? = nil

    /// "Jul 24 – Jul 27" — the detail shown on the row.
    var dateRangeText: String {
        let s = start.formatted(.dateTime.month(.abbreviated).day())
        let e = end.formatted(.dateTime.month(.abbreviated).day())
        return "\(s) – \(e)"
    }

    static func samples() -> [VacationTrip] {
        let cal = Calendar.current
        let now = Date()
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now) ?? now }
        return [
            VacationTrip(name: "Summer Trip",  start: day(14),  end: day(21)),
            VacationTrip(name: "Thanksgiving", start: day(120), end: day(125)),
        ]
    }

    static func new() -> VacationTrip {
        let cal = Calendar.current
        let now = Date()
        return VacationTrip(name: "", start: now, end: cal.date(byAdding: .day, value: 3, to: now) ?? now)
    }
}

// MARK: - Vacation list

struct VacationView: View {
    @Environment(AppModel.self) private var model

    @State private var trips: [VacationTrip] = VacationTrip.samples()
    @State private var editing: VacationTrip?

    var body: some View {
        List {
            Section {
                ForEach($trips) { $trip in
                    HStack(spacing: 12) {
                        // Sibling borderless button so the row-tap (settings) and the
                        // toggle hit-test independently.
                        Button {
                            editing = trip
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.name.isEmpty ? "Untitled" : trip.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Text(trip.dateRangeText)
                                    .font(.footnote)
                                    .foregroundStyle(SMA.labelSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityHint("Opens vacation settings")

                        Toggle("", isOn: $trip.isActive)
                            .labelsHidden()
                            .accessibilityLabel("\(trip.name.isEmpty ? "Vacation" : trip.name) active")
                    }
                }
                .onDelete { trips.remove(atOffsets: $0) }
            } footer: {
                Text("Turn a vacation on to hold an energy-saving temperature over its dates, then resume your schedule when it ends.")
            }
        }
        .groupedListChrome()
        .navigationTitle("Vacations")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = .new() } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Vacation")
            }
        }
        .sheet(item: $editing) { trip in
            VacationEditor(trip: trip) { result in
                if let i = trips.firstIndex(where: { $0.id == result.id }) {
                    trips[i] = result          // existing: edit in place
                } else {
                    trips.append(result)       // new: add it
                }
            }
        }
        // Vacation mode is on whenever any saved vacation is toggled active; its
        // assigned profile (if any) drives the held setpoints.
        .onChange(of: trips) { _, list in
            let active = list.first { $0.isActive }
            let profile = active?.profileID.flatMap { id in
                model.activityProfiles.first { $0.id == id }
            }
            model.setVacation(active != nil, profile: profile)
        }
    }
}

// MARK: - Vacation editor (name + inline date range)

struct VacationEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model

    @State private var trip: VacationTrip
    let onSave: (VacationTrip) -> Void

    init(trip: VacationTrip, onSave: @escaping (VacationTrip) -> Void) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
    }

    private var isNew: Bool { trip.name.trimmingCharacters(in: .whitespaces).isEmpty }

    /// The profile currently assigned to this vacation, if any.
    private var selectedProfile: ActivityProfile? {
        guard let id = trip.profileID else { return nil }
        return model.activityProfiles.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $trip.name)
                }

                Section {
                    // Always-visible inline calendar: tap a start day, then an end day,
                    // to select a contiguous range. The band stays on screen the whole time.
                    RangeCalendar(start: $trip.start, end: $trip.end)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 12, trailing: 12))
                } header: {
                    Text("Dates")
                } footer: {
                    Text(trip.dateRangeText)
                }

                Section {
                    profileRow
                } footer: {
                    Text("Hold this profile's temperatures during the vacation, or leave it on the default energy-saving setback.")
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(isNew ? "New Vacation" : "Edit Vacation")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton {
                        var result = trip
                        if result.end < result.start { result.end = result.start }
                        onSave(result)
                        dismiss()
                    }
                }
            }
        }
    }

    /// A menu row for assigning one of the activity profiles to the vacation. The
    /// collapsed row shows the current selection as a colored icon + name.
    private var profileRow: some View {
        Menu {
            Button { trip.profileID = nil } label: {
                Label("None", systemImage: selectedProfile == nil ? "checkmark" : "slash.circle")
            }
            ForEach(model.activityProfiles) { profile in
                Button { trip.profileID = profile.id } label: {
                    Label(profile.name, systemImage: profile.id == trip.profileID ? "checkmark" : profile.symbol)
                }
            }
        } label: {
            HStack(spacing: 10) {
                Text("Profile")
                    .foregroundStyle(SMA.labelPrimary)
                Spacer()
                if let profile = selectedProfile {
                    ProfileIcon(symbol: profile.symbol, colorHex: profile.colorHex, size: 24)
                    Text(profile.name)
                        .foregroundStyle(SMA.labelSecondary)
                } else {
                    Text("None")
                        .foregroundStyle(SMA.labelSecondary)
                }
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(SMA.labelSecondary)
            }
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Profile")
        .accessibilityValue(selectedProfile?.name ?? "None")
    }
}

// MARK: - Inline range calendar

/// An always-visible month calendar that selects a contiguous date range. The first
/// tap sets a new anchor (start == end); the next tap completes the range, swapping
/// the bounds if the second day falls before the anchor. Selected days are joined by
/// a tinted band with solid endpoints, so the chosen span is always readable at rest.
struct RangeCalendar: View {
    @Binding var start: Date
    @Binding var end: Date

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    /// Any date within the month currently shown in the grid.
    @State private var visibleMonth: Date
    /// True once an anchor has been placed and we're waiting for the closing tap.
    @State private var pickingEnd = false

    init(start: Binding<Date>, end: Binding<Date>) {
        _start = start
        _end = end
        _visibleMonth = State(initialValue: start.wrappedValue)
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            weekdayHeader
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date {
                        cell(date)
                    } else {
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy, value: startDay)
        .animation(.snappy, value: endDay)
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Text(firstOfMonth.formatted(.dateTime.month(.wide).year()))
                .font(.headline)
                .foregroundStyle(SMA.labelPrimary)
            Spacer()
            Button { shiftMonth(-1) } label: {
                Image(systemName: "chevron.left").font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SMA.accent)
            .accessibilityLabel("Previous month")
            Button { shiftMonth(1) } label: {
                Image(systemName: "chevron.right").font(.body.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(SMA.accent)
            .padding(.leading, 20)
            .accessibilityLabel("Next month")
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Day cell

    @ViewBuilder private func cell(_ date: Date) -> some View {
        let d = calendar.startOfDay(for: date)
        let lo = min(startDay, endDay)
        let hi = max(startDay, endDay)
        let isEndpoint = d == lo || d == hi
        // Half-cell bands: the right half fills when the range continues to the next
        // day, the left half when it continues from the previous one. With zero column
        // spacing, adjacent halves meet to form one continuous band.
        let leftFilled = d > lo && d <= hi
        let rightFilled = d >= lo && d < hi
        let inRange = d >= lo && d <= hi
        let isToday = calendar.isDateInToday(d)
        let markSize: CGFloat = 34

        ZStack {
            // Connecting band, its height matched to the endpoint circles so the range
            // reads as one horizontal pill through the week row rather than a tall block.
            HStack(spacing: 0) {
                Rectangle().fill(leftFilled ? SMA.accent.opacity(0.15) : Color.clear)
                Rectangle().fill(rightFilled ? SMA.accent.opacity(0.15) : Color.clear)
            }
            .frame(height: markSize)

            if isEndpoint {
                Circle().fill(SMA.accent).frame(width: markSize, height: markSize)
            } else if isToday {
                Circle().stroke(SMA.accent.opacity(0.5), lineWidth: 1.5)
                    .frame(width: markSize, height: markSize)
            }

            Text("\(calendar.component(.day, from: d))")
                .font(.callout.weight(isEndpoint ? .semibold : .regular))
                .foregroundStyle(isEndpoint ? Color.white
                                 : isToday ? SMA.accent : SMA.labelPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
        .contentShape(Rectangle())
        .onTapGesture { withAnimation(.snappy) { tap(date) } }
        .accessibilityLabel(Text(date, format: .dateTime.weekday(.wide).month().day()))
        .accessibilityAddTraits(inRange ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Selection

    private var startDay: Date { calendar.startOfDay(for: start) }
    private var endDay: Date { calendar.startOfDay(for: end) }

    private func tap(_ date: Date) {
        let d = calendar.startOfDay(for: date)
        if pickingEnd {
            if d < startDay { start = d } else { end = d }
            pickingEnd = false
        } else {
            start = d
            end = d
            pickingEnd = true
        }
    }

    // MARK: Month math

    private var firstOfMonth: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: visibleMonth)) ?? visibleMonth
    }

    /// Weekday symbols rotated to match the locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The grid slots for the visible month: leading `nil`s for the offset, then each
    /// day, padded with trailing `nil`s to fill whole weeks.
    private var days: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var result: [Date?] = Array(repeating: nil, count: leading)
        for day in dayRange {
            result.append(calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth))
        }
        while result.count % 7 != 0 { result.append(nil) }
        return result
    }

    private func shiftMonth(_ delta: Int) {
        guard let shifted = calendar.date(byAdding: .month, value: delta, to: firstOfMonth) else { return }
        withAnimation(.snappy) { visibleMonth = shifted }
    }
}

#Preview {
    NavigationStack {
        VacationView()
    }
    .environment(AppModel())
}
