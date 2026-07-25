import SwiftUI

// MARK: - Service Reminders
//
// The Reminders device tab: HVAC service reminders (air filter changes, maintenance)
// shown as life-tracked cards. Each reminder tracks a percentage of life remaining,
// a next-service date, and can be marked complete. Prototype-local state.

enum ReminderBasis: String, CaseIterable, Identifiable {
    case runtime = "Runtime"
    case calendar = "Calendar"
    var id: String { rawValue }
}

struct ServiceReminder: Identifiable, Hashable {
    let id = UUID()
    var name: String
    var type: String
    var basedOn: ReminderBasis
    var durationText: String
    var nextService: Date
    var lastCompleted: Date?
    var spec: String
    /// Fraction of life remaining, 0…1 — drives the bar and the percentage.
    var lifeRemaining: Double
    /// Whether a contractor is on file (shows the "Call Contractor" action).
    var hasContractor: Bool = false

    static func samples() -> [ServiceReminder] {
        let cal = Calendar.current
        let now = Date()
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now) ?? now }
        return [
            ServiceReminder(name: "Reminder", type: "Air Filter", basedOn: .runtime,
                            durationText: "300 Hours", nextService: day(60), lastCompleted: day(-305),
                            spec: "16” x 25” x 2” - MERV8", lifeRemaining: 0.8),
            ServiceReminder(name: "Reminder", type: "Air Filter", basedOn: .runtime,
                            durationText: "300 Hours", nextService: day(24), lastCompleted: day(-305),
                            spec: "16” x 25” x 2” - MERV8", lifeRemaining: 0.4, hasContractor: true),
        ]
    }
}

// MARK: - Reminders list

struct RemindersView: View {
    @Environment(AppModel.self) private var model

    @State private var reminders: [ServiceReminder] = ServiceReminder.samples()
    @State private var creating = false

    var body: some View {
        Group {
            if reminders.isEmpty {
                ContentUnavailableView {
                    Label("No Reminders", systemImage: "bell.badge")
                } description: {
                    Text("Tap ‘+’ to set up your first service reminder — like air filter changes or HVAC maintenance. You can opt for updates via Email or Push notifications.")
                }
                .background(SMA.groupedBackground.ignoresSafeArea())
            } else {
                List {
                    ForEach($reminders) { $reminder in
                        ServiceReminderSection(reminder: reminder) {
                            markComplete(reminder.id)
                        }
                    }
                    .onDelete { reminders.remove(atOffsets: $0) }
                }
                .groupedListChrome()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Reminder")
            }
        }
        .sheet(isPresented: $creating) {
            NewReminderEditor { reminders.append($0) }
        }
    }

    private func markComplete(_ id: ServiceReminder.ID) {
        guard let i = reminders.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.snappy) {
            reminders[i].lastCompleted = Date()
            reminders[i].lifeRemaining = 1
            reminders[i].nextService = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        }
    }
}

/// One reminder rendered as a grouped card: a life bar, next-service date, the part
/// spec, and the mark-complete (and optional call-contractor) actions.
private struct ServiceReminderSection: View {
    let reminder: ServiceReminder
    let onComplete: () -> Void

    var body: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.name)
                        .foregroundStyle(SMA.labelPrimary)
                    Text(reminder.type)
                        .font(.footnote)
                        .foregroundStyle(SMA.labelSecondary)
                }
                Spacer()
                Text("\(Int((reminder.lifeRemaining * 100).rounded()))%")
                    .foregroundStyle(SMA.labelSecondary)
                    .monospacedDigit()
                Button { } label: { Image(systemName: "info.circle") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SMA.accent)
                    .accessibilityLabel("About this reminder")
            }

            ReminderLifeBar(progress: reminder.lifeRemaining)
                .listRowSeparator(.hidden)

            LabeledContent("Next Service Date") {
                Text(reminder.nextService, format: .dateTime.month(.abbreviated).day().year())
                    .foregroundStyle(SMA.accent)
            }

            Text(reminder.spec)
                .foregroundStyle(SMA.labelPrimary)

            HStack(spacing: 12) {
                if reminder.hasContractor {
                    Button("Call Contractor") { }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                }
                Button("Mark Complete", action: onComplete)
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
            }
            .tint(SMA.accent)
            .listRowSeparator(.hidden)
        } footer: {
            if let last = reminder.lastCompleted {
                Text("Last Completed: \(last.formatted(.dateTime.month(.wide).day().year()))")
            }
        }
    }
}

/// The colored life bar: green while healthy, yellow as it wanes, red when depleted.
private struct ReminderLifeBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(SMA.fillTertiary)
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .frame(height: 16)
        .padding(.vertical, 4)
        .accessibilityLabel("Life remaining \(Int((progress * 100).rounded())) percent")
    }

    private var color: Color {
        switch progress {
        case 0.5...:   return Color(hex: 0x34C759)
        case 0.25...:  return Color(hex: 0xFFCC00)
        default:       return SMA.destructive
        }
    }
}

// MARK: - New Reminder editor

struct NewReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    let onSave: (ServiceReminder) -> Void

    @State private var name = ""
    @State private var type = "Air Filter"
    @State private var basedOn: ReminderBasis = .runtime
    @State private var duration = "300 Hours"
    @State private var lastCompleted = Date()
    @State private var notes = ""

    private let types = ["Air Filter", "Humidifier Pad", "UV Bulb", "Blower Motor", "Custom"]
    private let runtimeDurations = ["100 Hours", "200 Hours", "300 Hours", "500 Hours", "1000 Hours"]
    private let calendarDurations = ["1 Month", "3 Months", "6 Months", "12 Months"]

    private var durations: [String] { basedOn == .runtime ? runtimeDurations : calendarDurations }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section {
                    Picker("Reminder Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    Picker("Based On", selection: $basedOn) {
                        ForEach(ReminderBasis.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { Text($0) }
                    }
                    DatePicker("Last Completed", selection: $lastCompleted, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Size, Rating, Brand", text: $notes)
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle("New Reminder")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .onChange(of: basedOn) { _, _ in
                if !durations.contains(duration) { duration = durations.first ?? "" }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton(isEnabled: isValid) {
                        onSave(makeReminder())
                        dismiss()
                    }
                }
            }
        }
    }

    private func makeReminder() -> ServiceReminder {
        let component: Calendar.Component = basedOn == .runtime ? .month : .month
        let next = Calendar.current.date(byAdding: component, value: 3, to: Date()) ?? Date()
        return ServiceReminder(name: name, type: type, basedOn: basedOn, durationText: duration,
                               nextService: next, lastCompleted: lastCompleted, spec: notes,
                               lifeRemaining: 1)
    }
}

#Preview {
    NavigationStack {
        RemindersView()
    }
    .environment(AppModel())
}
