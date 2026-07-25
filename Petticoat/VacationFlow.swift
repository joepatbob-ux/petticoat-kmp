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
        // Vacation mode is on whenever any saved vacation is toggled active.
        .onChange(of: trips) { _, list in
            model.setVacation(list.contains { $0.isActive })
        }
    }
}

// MARK: - Vacation editor (name + inline date range)

struct VacationEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State private var trip: VacationTrip
    let onSave: (VacationTrip) -> Void

    init(trip: VacationTrip, onSave: @escaping (VacationTrip) -> Void) {
        _trip = State(initialValue: trip)
        self.onSave = onSave
    }

    private var isNew: Bool { trip.name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $trip.name)
                }

                Section("Dates") {
                    DatePicker("Starts", selection: $trip.start, displayedComponents: [.date])
                    DatePicker("Ends", selection: $trip.end, in: trip.start..., displayedComponents: [.date])
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
}

#Preview {
    NavigationStack {
        VacationView()
    }
    .environment(AppModel())
}
