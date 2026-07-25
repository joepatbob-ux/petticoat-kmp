import SwiftUI

/// The "Automation" device tab. Modeled on the Petticoat Glass "Automation" design:
/// a Schedule/Off mode selector on top, then grouped settings (Presets, Schedule,
/// Early Start) and a Vacation drill-in. Presented as tab content, not a sheet.
struct ScheduleView: View {
    @Environment(AppModel.self) private var model

    @State private var mode: AutomationMode = .schedule
    @State private var geofenceRadius = 3
    @State private var geofenceUnit: DistanceUnit = .miles

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
                Toggle("Use Presets", isOn: $model[device: \.usePresets])
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

            Section {
                if model.device.usePresets {
                    NavigationLink {
                        SchedulePresetsList(title: "Schedules")
                    } label: {
                        LabeledContent("Schedule", value: model.scheduleName)
                    }
                } else {
                    // Without presets, schedules are built per mode: Heating, Cooling, Auto.
                    ForEach(ScheduleKind.allCases) { kind in
                        NavigationLink {
                            ProgramScheduleList(kind: kind)
                        } label: {
                            LabeledContent(kind.rowTitle, value: kind.detail)
                        }
                    }
                }
            }

            Section {
                Toggle("Early Start", isOn: $model[device: \.earlyStart])
            } footer: {
                Text("Heat or cool ahead of time to reach your set temperature at the scheduled time.")
            }

            Section {
                Toggle("Auto Home/Away", isOn: $model[device: \.geofenceEnabled])
                if model.device.geofenceEnabled {
                    NavigationLink {
                        GeofenceRadiusView(radius: $geofenceRadius, unit: $geofenceUnit)
                    } label: {
                        LabeledContent("Radius", value: geofenceUnit.valueLabel(geofenceRadius))
                    }
                }
            } footer: {
                Text("Use your phone's location to end the current schedule period early when everyone leaves, and resume when you return.")
            }

            Section {
                NavigationLink {
                    VacationView()
                } label: {
                    Text("Vacations")
                }
            } footer: {
                Text("Hold an energy-saving temperature while you're away, then resume your schedule when you return.")
            }
        }
        .groupedListChrome()
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
                .renderingMode(.template)
                .font(.title)
                .foregroundStyle(SMA.labelPrimary)
                .accessibilityHidden(true)
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
                                        .fill(SMA.segmentedSelected)
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

#Preview {
    NavigationStack {
        ScheduleView()
    }
    .environment(AppModel())
}
