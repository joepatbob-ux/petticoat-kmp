import SwiftUI

/// The "Automation" device tab. Modeled on the Petticoat Glass "Automation" design:
/// a Schedule/Off mode selector on top, then grouped settings (Presets, Schedule,
/// Early Start) and a Vacation drill-in. Presented as tab content, not a sheet.
struct ScheduleView: View {
    @Environment(AppModel.self) private var model

    @State private var mode: AutomationMode = .schedule

    var body: some View {
        @Bindable var model = model
        List {
            Section {
                AutomationModeSelector(selection: $mode)
                    .onChange(of: mode) { _, newValue in
                        model.setScheduleEnabled(newValue == .schedule)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            }

            Section {
                Toggle("Use Presets", isOn: $model.device.usePresets)
                if model.device.usePresets {
                    NavigationLink {
                        ActivityProfilesList()
                    } label: {
                        LabeledContent("Presets", value: "\(model.activityProfiles.count) Profiles")
                    }
                }
            } footer: {
                Text("A preset switcher will be shown on the control screen when not running a schedule.")
            }

            Section("Schedule") {
                NavigationLink {
                    SchedulePresetsList(title: "Schedules", presets: [model.device.scheduleName, "Eco", "Custom 1"])
                } label: {
                    LabeledContent("Schedule", value: model.device.scheduleName)
                }
            }

            Section {
                Toggle("Early Start", isOn: $model.device.earlyStart)
            } footer: {
                Text("Heat or cool ahead of time to reach your set temperature at the scheduled time.")
            }

            Section {
                Toggle("Auto Home/Away", isOn: $model.device.geofenceEnabled)
            } footer: {
                Text("Use your phone's location to end the current schedule period early when everyone leaves, and resume when you return.")
            }

            Section {
                NavigationLink {
                    VacationView()
                } label: {
                    Text("Set Vacation")
                }
            } header: {
                Text("Vacation")
            } footer: {
                Text("Hold an energy-saving temperature while you're away, then resume your schedule when you return.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .foregroundStyle(SMA.labelPrimary)
        .background(SMA.groupedBackground.ignoresSafeArea())
    }
}

// MARK: - Automation mode selector (Schedule / Off)

enum AutomationMode: String, CaseIterable, Identifiable {
    case schedule, off
    var id: String { rawValue }

    var label: String {
        switch self {
        case .schedule: "Schedule"
        case .off:      "Off"
        }
    }

    /// Custom asset symbol name.
    var icon: String {
        switch self {
        case .schedule: "schedule.activity"
        case .off:      "schedule.xmark"
        }
    }
}

/// Full-width, two-segment control with large icons and labels beneath.
struct AutomationModeSelector: View {
    @Binding var selection: AutomationMode

    var body: some View {
        PillSegmentedSelector(items: AutomationMode.allCases, selection: $selection, label: \.label) { mode in
            Image(mode.icon)
                .font(.title)
                .symbolRenderingMode(.multicolor)
        }
    }
}

// MARK: - Shared pill segmented selector

/// A full-width, fully-rounded segmented control: large icons in a capsule track
/// with labels beneath. Shared by the Schedule/Off, System, and Fan selectors.
struct PillSegmentedSelector<Item: Hashable, Icon: View>: View {
    let items: [Item]
    @Binding var selection: Item
    let label: (Item) -> String
    @ViewBuilder let icon: (Item) -> Icon

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Button { selection = item } label: {
                        icon(item)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background {
                                if selection == item {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(SMA.card)
                                        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label(item))
                    .accessibilityAddTraits(selection == item ? [.isSelected] : [])
                }
            }
            .padding(5)
            .background(SMA.fillTertiary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            HStack(spacing: 6) {
                ForEach(items, id: \.self) { item in
                    Text(label(item))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(selection == item ? SMA.labelPrimary : SMA.labelSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .animation(.snappy, value: selection)
    }
}

// MARK: - Vacation drill-in

/// Create-a-vacation screen: enable, then pick a start and end date + time.
struct VacationView: View {
    @Environment(AppModel.self) private var model
    @State private var enabled = true
    @State private var start = Date()
    @State private var end = Date().addingTimeInterval(60 * 60 * 24 * 3)

    var body: some View {
        Form {
            Section {
                Toggle("Set Vacation", isOn: $enabled)
            } footer: {
                Text("While on vacation, your thermostat holds an energy-saving temperature until the end date.")
            }

            Section {
                DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                DatePicker("End", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
            }
            .disabled(!enabled)
        }
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .foregroundStyle(SMA.labelPrimary)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .onChange(of: enabled) { _, newValue in
            model.setVacation(newValue)
        }
        .navigationTitle("Vacation")
        .inlineNavTitle()
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
    .environment(AppModel())
}
