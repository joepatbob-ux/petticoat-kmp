import SwiftUI

// MARK: - Service Reminders
//
// The Reminders device tab: HVAC service reminders (air filter changes, maintenance)
// shown as life-tracked cards. Each reminder tracks a percentage of life remaining,
// a next-service date, and can be added, edited, completed, or deleted.
// Prototype-local state.

enum ReminderBasis: String, CaseIterable, Identifiable {
    case runtime = "Runtime"
    case calendar = "Calendar"
    var id: String { rawValue }
}

struct ServiceReminder: Identifiable, Hashable {
    var id = UUID()
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

    /// Below this fraction the life bar turns red (matches `MetricBar`'s red band).
    static let criticalThreshold = 0.25
    /// In the red — needs attention. Surfaced as the Reminders tab badge.
    var isCritical: Bool { lifeRemaining < Self.criticalThreshold }

    static func samples() -> [ServiceReminder] {
        let cal = Calendar.current
        let now = Date()
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now) ?? now }
        return [
            ServiceReminder(name: "Upstairs Air Filter", type: "Air Filter", basedOn: .runtime,
                            durationText: "300 Hours", nextService: day(60), lastCompleted: day(-305),
                            spec: "16” x 25” x 2” - MERV8", lifeRemaining: 0.8),
            ServiceReminder(name: "Downstairs Air Filter", type: "Air Filter", basedOn: .runtime,
                            durationText: "300 Hours", nextService: day(6), lastCompleted: day(-305),
                            spec: "16” x 25” x 2” - MERV8", lifeRemaining: 0.15, hasContractor: true),
        ]
    }
}

// MARK: - Reminders list

struct RemindersView: View {
    @Environment(AppModel.self) private var model
    /// Drives the add/edit sheet: a nil `reminder` is a new one, otherwise an edit.
    @State private var editTarget: ReminderEditTarget?

    var body: some View {
        Group {
            if model.serviceReminders.isEmpty {
                ContentUnavailableView {
                    Label("No Reminders", systemImage: "bell.badge")
                } description: {
                    Text("Tap ‘+’ to set up your first service reminder — like air filter changes or HVAC maintenance. You can opt for updates via Email or Push notifications.")
                } actions: {
                    Button("Add Reminder") { editTarget = ReminderEditTarget(reminder: nil) }
                        .buttonStyle(.borderedProminent)
                }
                .background(SMA.groupedBackground.ignoresSafeArea())
            } else {
                List {
                    ForEach(model.serviceReminders) { reminder in
                        ServiceReminderSection(
                            reminder: reminder,
                            onComplete: { withAnimation(.snappy) { model.completeReminder(reminder.id) } },
                            onEdit: { editTarget = ReminderEditTarget(reminder: reminder) }
                        )
                    }
                    .onDelete { model.deleteReminders($0) }
                }
                .groupedListChrome()
            }
        }
        .sheet(item: $editTarget) { target in
            ReminderEditor(
                initial: target.reminder,
                onSave: { model.saveReminder($0) },
                onDelete: target.reminder.map { existing in { model.deleteReminder(existing.id) } }
            )
        }
    }
}

/// Identifiable wrapper so a new-or-existing reminder can drive `.sheet(item:)`.
struct ReminderEditTarget: Identifiable {
    let id = UUID()
    let reminder: ServiceReminder?
}

/// One reminder rendered as a grouped card: a life bar, next-service date, the part
/// spec, and the mark-complete (and optional call-contractor) actions. The info button
/// opens the editor.
private struct ServiceReminderSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL
    let reminder: ServiceReminder
    let onComplete: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(reminder.name)
                        .font(.headline)
                        .foregroundStyle(SMA.labelPrimary)
                    Text(reminder.type)
                        .font(.footnote)
                        .foregroundStyle(SMA.labelSecondary)
                }
                Spacer(minLength: 8)
                Text("\(Int((reminder.lifeRemaining * 100).rounded()))%")
                    .foregroundStyle(SMA.labelSecondary)
                    .monospacedDigit()
                Button(action: onEdit) { Image(systemName: "info.circle") }
                    .buttonStyle(.borderless)
                    .foregroundStyle(SMA.accent)
                    .accessibilityLabel("Edit \(reminder.name)")
            }

            MetricBar(progress: reminder.lifeRemaining,
                      accessibilityLabel: "Life remaining \(Int((reminder.lifeRemaining * 100).rounded())) percent")
                .listRowSeparator(.hidden)

            LabeledContent("Next Service Date") {
                Text(reminder.nextService, format: .dateTime.month(.abbreviated).day().year())
                    .foregroundStyle(SMA.accent)
            }

            if !reminder.spec.isEmpty {
                Text(reminder.spec)
                    .foregroundStyle(SMA.labelPrimary)
            }

            HStack(spacing: 12) {
                if reminder.hasContractor {
                    Button {
                        if let url = URL(string: "tel://\(model.contractor.phoneDigits)") { openURL(url) }
                    } label: {
                        Text("Call Contractor").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(model.contractor.phoneDigits.isEmpty)
                }
                Button(action: onComplete) {
                    Text("Mark Complete").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .tint(SMA.accent)
            .listRowSeparator(.hidden)
        } footer: {
            if let last = reminder.lastCompleted {
                Text("Last Completed: \(last.formatted(.dateTime.month(.wide).day().year()))")
            }
        }
    }
}

// MARK: - Add / Edit reminder

struct ReminderEditor: View {
    @Environment(\.dismiss) private var dismiss

    let initial: ServiceReminder?
    let onSave: (ServiceReminder) -> Void
    var onDelete: (() -> Void)?

    @State private var name: String
    @State private var type: String
    @State private var basedOn: ReminderBasis
    @State private var duration: String
    @State private var lastCompleted: Date
    @State private var notes: String

    private let types = ["Air Filter", "Humidifier Pad", "UV Bulb", "Blower Motor", "Custom"]
    private let runtimeDurations = ["100 Hours", "200 Hours", "300 Hours", "500 Hours", "1000 Hours"]
    private let calendarDurations = ["1 Month", "3 Months", "6 Months", "12 Months"]

    init(initial: ServiceReminder?, onSave: @escaping (ServiceReminder) -> Void, onDelete: (() -> Void)? = nil) {
        self.initial = initial
        self.onSave = onSave
        self.onDelete = onDelete
        _name = State(initialValue: initial?.name ?? "")
        _type = State(initialValue: initial?.type ?? "Air Filter")
        _basedOn = State(initialValue: initial?.basedOn ?? .runtime)
        _duration = State(initialValue: initial?.durationText ?? "300 Hours")
        _lastCompleted = State(initialValue: initial?.lastCompleted ?? Date())
        _notes = State(initialValue: initial?.spec ?? "")
    }

    private var durations: [String] { basedOn == .runtime ? runtimeDurations : calendarDurations }
    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isNew: Bool { initial == nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section {
                    Picker("Reminder Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("Based On", selection: $basedOn) {
                        ForEach(ReminderBasis.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("Duration", selection: $duration) {
                        ForEach(durations, id: \.self) { Text($0).tag($0) }
                    }
                    DatePicker("Last Completed", selection: $lastCompleted, displayedComponents: .date)
                }

                Section("Notes") {
                    TextField("Size, Rating, Brand", text: $notes)
                }

                if !isNew, let onDelete {
                    Section {
                        RowActionButton("Delete Reminder", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(isNew ? "New Reminder" : "Edit Reminder")
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
        let next = initial?.nextService
            ?? Calendar.current.date(byAdding: .month, value: 3, to: Date())
            ?? Date()
        var result = ServiceReminder(
            name: name, type: type, basedOn: basedOn, durationText: duration,
            nextService: next, lastCompleted: lastCompleted, spec: notes,
            lifeRemaining: initial?.lifeRemaining ?? 1,
            hasContractor: initial?.hasContractor ?? false
        )
        if let initial { result.id = initial.id }   // preserve identity when editing
        return result
    }
}

#Preview {
    NavigationStack {
        RemindersView()
    }
    .environment(AppModel())
}
