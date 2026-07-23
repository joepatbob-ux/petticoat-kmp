import SwiftUI

/// The device detail experience, pushed from the dashboard's thermostat card.
/// A native bottom TabView scoped to a single device.
struct DeviceTabView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: DeviceTab = .control

    var body: some View {
        TabView(selection: $selection) {
            Tab("Control", image: "thermostat.fill", value: DeviceTab.control) {
                ControlView()
            }
            Tab("Schedule", image: "schedule.activity", value: DeviceTab.schedule) {
                ScheduleView()
            }
            Tab("Usage", systemImage: "gauge.with.needle.fill", value: DeviceTab.usage) {
                DeviceTabPlaceholder(title: "Usage", systemImage: "gauge.with.needle.fill")
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "square.grid.2x2.fill")
                }
                .accessibilityLabel("Back to Dashboard")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {} label: {
                    Image(systemName: "questionmark.bubble")
                }
                .accessibilityLabel("Help and Support")
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

/// Placeholder content for the not-yet-built device tabs. Accepts either a system
/// symbol or a custom asset symbol.
struct DeviceTabPlaceholder: View {
    let title: String
    var systemImage: String? = nil
    var image: String? = nil

    var body: some View {
        Group {
            if let image {
                ContentUnavailableView(title, image: image, description: Text("Prototype screen"))
            } else {
                ContentUnavailableView(title, systemImage: systemImage ?? "questionmark", description: Text("Prototype screen"))
            }
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
    }
}

#Preview {
    NavigationStack {
        DeviceTabView()
    }
    .environment(AppModel())
}
