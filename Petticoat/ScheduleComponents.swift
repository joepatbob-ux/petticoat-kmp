import SwiftUI

// MARK: - Shared schedule / editor components
//
// Extracted from the preset (ScheduleFlow), non-preset (ProgramScheduleFlow),
// vacation, and activity-profile flows, which each carried byte-identical copies.

/// Day-of-week labels/names and the human-readable summary of a day set. The
/// index order is Monday…Sunday (0 = Monday) to match the "M T W T F S S" picker.
enum WeekDay {
    static let labels = ["M", "T", "W", "T", "F", "S", "S"]
    static let names  = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    static let short  = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    /// "All Week" / "Weekdays" / "Weekend" / "Mon, Wed" / "No Days Selected".
    static func summary(_ days: Set<Int>) -> String {
        if days.isEmpty { return "No Days Selected" }
        if days == Set(0..<7) { return "All Week" }
        if days == Set(0..<5) { return "Weekdays" }
        if days == Set(5..<7) { return "Weekend" }
        return days.sorted().map { short[$0] }.joined(separator: ", ")
    }
}

/// The 7-circle day selector used by the schedule editors. The caller owns the
/// day set and is notified which index was toggled.
struct DayPicker: View {
    let days: Set<Int>
    let onToggle: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<7, id: \.self) { i in
                let on = days.contains(i)
                Button {
                    onToggle(i)
                } label: {
                    Text(WeekDay.labels[i])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? .white : SMA.labelPrimary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(on ? SMA.accent : SMA.fillTertiary))
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(WeekDay.names[i])
                .accessibilityAddTraits(on ? [.isSelected] : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// The circular ellipsis label shared by per-row "more options" `Menu`s.
struct EllipsisMenuLabel: View {
    /// When true, draws the accent outline used on section-header menus.
    var outlined: Bool = false

    var body: some View {
        Image(systemName: "ellipsis")
            .font(.body.weight(.semibold))
            .foregroundStyle(SMA.accent)
            .frame(width: 28, height: 28)
            .overlay { if outlined { Circle().stroke(SMA.accent, lineWidth: 1.5) } }
            .contentShape(Rectangle())
    }
}

/// The capsule "Save" confirmation action shared by editor toolbars.
struct EditorSaveButton: View {
    var title: LocalizedStringKey = "Save"
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(SMA.accent)
            .disabled(!isEnabled)
    }
}

/// The "x" cancellation action shared by editor toolbars.
struct EditorCancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) { Image(systemName: "xmark") }
            .accessibilityLabel("Cancel")
    }
}

/// A full-width grouped-list action button (e.g. "Delete", "Enroll", "Call"). Uses the
/// accent tint by default and the destructive token for `.destructive` roles.
struct RowActionButton: View {
    let title: LocalizedStringKey
    var role: ButtonRole? = nil
    var isEnabled: Bool = true
    let action: () -> Void

    init(_ title: LocalizedStringKey, role: ButtonRole? = nil, isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.role = role
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button(title, role: role, action: action)
            .frame(maxWidth: .infinity)
            .foregroundStyle(role == .destructive ? SMA.destructive : SMA.accent)
            .disabled(!isEnabled)
    }
}

extension Set {
    /// Inserts `member` if absent, removes it if present.
    mutating func toggleMembership(_ member: Element) {
        if contains(member) { remove(member) } else { insert(member) }
    }
}
