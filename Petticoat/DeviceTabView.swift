import SwiftUI

/// The device detail experience, pushed from the dashboard's thermostat card.
/// A native bottom TabView scoped to a single device.
struct DeviceTabView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: DeviceTab = .control

    var body: some View {
        TabView(selection: $selection) {
            Tab("Control", systemImage: "thermometer.medium", value: DeviceTab.control) {
                ControlView()
            }
            Tab("Schedule", systemImage: "calendar", value: DeviceTab.schedule) {
                DeviceTabPlaceholder(title: "Schedule", systemImage: "calendar")
            }
            Tab("Usage", systemImage: "chart.bar.xaxis", value: DeviceTab.usage) {
                DeviceTabPlaceholder(title: "Usage", systemImage: "chart.bar.xaxis")
            }
            Tab("Reminders", systemImage: "bell", value: DeviceTab.reminders) {
                DeviceTabPlaceholder(title: "Reminders", systemImage: "bell")
            }
            Tab("Settings", systemImage: "gearshape", value: DeviceTab.settings) {
                DeviceTabPlaceholder(title: "Settings", systemImage: "gearshape")
            }
        }
        .navigationTitle(title)
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "questionmark.bubble")
                }
            }
        }
    }

    private var title: String {
        switch selection {
        case .control:   model.device.name
        case .schedule:  "Schedule"
        case .usage:     "Usage"
        case .reminders: "Reminders"
        case .settings:  "Settings"
        }
    }
}

enum DeviceTab: Hashable {
    case control, schedule, usage, reminders, settings
}

/// Placeholder content for the not-yet-built device tabs.
struct DeviceTabPlaceholder: View {
    let title: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text("Prototype screen")
        )
        .background(SMA.groupedBackground.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        DeviceTabView()
    }
    .environment(AppModel())
}
