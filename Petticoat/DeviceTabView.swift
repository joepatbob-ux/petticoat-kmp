import SwiftUI

/// The compact device detail experience, pushed from the dashboard's thermostat card.
/// Uses native bottom tab chrome scoped to a single device.
struct DeviceTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DeviceTab = .control
    /// Presents the New Reminder editor. Lives here (not in the tab content) because a
    /// toolbar declared inside a TabView tab doesn't surface in the shared nav bar.
    @State private var addingReminder = false
    /// The Usage tab's Recent/Monthly range. Owned here so its segmented control can live
    /// in the shared nav-bar header (tab-content toolbars don't surface there).
    @State private var usageRange: UsageRange = .recent

    var body: some View {
        TabView(selection: $selection) {
            Tab("Control", image: "thermostat.fill", value: DeviceTab.control) {
                DeviceTabContent(tab: .control)
            }
            Tab("Schedule", image: "schedule.activity", value: DeviceTab.schedule) {
                DeviceTabContent(tab: .schedule)
            }
            Tab("Usage", systemImage: "gauge.with.needle.fill", value: DeviceTab.usage) {
                DeviceTabContent(tab: .usage, usageRange: $usageRange)
            }
            Tab("Reminders", systemImage: "bell", value: DeviceTab.reminders) {
                DeviceTabContent(tab: .reminders)
            }
            Tab("Settings", systemImage: "gearshape", value: DeviceTab.settings) {
                DeviceTabContent(tab: .settings)
            }
        }
        .tabViewStyle(.tabBarOnly)
        .navigationTitle(title)
        .inlineNavTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "rectangle.grid.1x2")
                }
                .accessibilityLabel("Back to Dashboard")
            }
            if selection == .reminders {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingReminder = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Reminder")
                }
            }
            if selection == .usage {
                ToolbarItem(placement: .principal) {
                    Picker("Range", selection: $usageRange) {
                        ForEach(UsageRange.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
            helpButton
        }
        .sheet(isPresented: $addingReminder) {
            ReminderEditor(initial: nil) { model.saveReminder($0) }
        }
    }

    @ToolbarContentBuilder private var helpButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button { model.showHelp = true } label: {
                Image(systemName: "questionmark.bubble")
            }
            .accessibilityLabel("Help and Support")
        }
    }

    private var title: String {
        selection.navigationTitle(deviceName: model.device.name)
    }
}

enum DeviceTab: Hashable, CaseIterable, Identifiable {
    case control, schedule, usage, reminders, settings

    var id: Self { self }

    func navigationTitle(deviceName: String) -> String {
        switch self {
        case .control:   deviceName
        case .schedule:  "Schedule"
        case .usage:     "Usage"
        case .reminders: "Reminders"
        case .settings:  "Settings"
        }
    }

    var label: String {
        switch self {
        case .control:   "Control"
        case .schedule:  "Schedule"
        case .usage:     "Usage"
        case .reminders: "Reminders"
        case .settings:  "Settings"
        }
    }
}

struct DeviceTabContent: View {
    let tab: DeviceTab
    /// Bound from the parent so the Usage range control can live in the shared header.
    var usageRange: Binding<UsageRange> = .constant(.recent)

    var body: some View {
        switch tab {
        case .control:
            ControlView()
        case .schedule:
            ScheduleView()
        case .usage:
            UsageView(range: usageRange)
        case .reminders:
            RemindersView()
        case .settings:
            SettingsView()
        }
    }
}

#Preview {
    NavigationStack {
        DeviceTabView()
    }
    .environment(AppModel())
}
