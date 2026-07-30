import SwiftUI

/// The iPad (regular width) signed-in experience. A `NavigationSplitView` where the
/// sidebar shows device cards + spotlight (mirroring the dashboard), and the detail
/// shows the selected device's content. Navigation between the five device tabs happens
/// via a pill-style strip in the detail's nav bar — same row as the sidebar toggle,
/// device name picker, and help button.
/// The compact (iPhone) experience uses `DashboardView` in a `NavigationStack`. See `MainView`.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: DeviceTab = .control
    @State private var usageRange: UsageRange = .recent
    @State private var addingReminder = false

    var body: some View {
        NavigationSplitView {
            SidebarContent()
        } detail: {
            NavigationStack {
                DeviceTabContent(
                    tab: selection,
                    usageRange: selection == .usage ? $usageRange : .constant(.recent)
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Device name — tappable menu when multiple thermostats are registered
                    ToolbarItem(placement: .topBarLeading) {
                        deviceNameItem
                    }
                    // Tab strip centred in the nav bar, same row as all other actions
                    ToolbarItem(placement: .principal) {
                        DeviceTabStrip(selection: $selection, badgeCount: model.criticalReminderCount)
                    }
                    // Usage range toggle sits between the tab strip and the help button
                    usageRangeToolbarItem
                    // Help button — always visible, right of the usage toggle
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { model.showHelp = true } label: {
                            Image(systemName: "questionmark.bubble")
                        }
                        .accessibilityLabel("Help and Support")
                    }
                    // Reminders "+" is the primary action — rightmost
                    remindersAddToolbarItem
                }
            }
        }
        .sheet(isPresented: $addingReminder) {
            ReminderEditor(initial: nil) { model.saveReminder($0) }
        }
    }

    // MARK: - Device name / picker

    @ViewBuilder
    private var deviceNameItem: some View {
        if model.devices.count > 1 {
            Menu {
                ForEach(model.devices) { device in
                    Button { model.selectDevice(device.id) } label: {
                        if device.id == model.device.id {
                            Label(device.name, systemImage: "checkmark")
                        } else {
                            Text(device.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.device.name)
                        .font(.headline)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(SMA.labelPrimary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            Text(model.device.name)
                .font(.headline)
                .foregroundStyle(SMA.labelPrimary)
        }
    }

    // MARK: - Per-tab toolbar extras

    // Declared before the help button in the toolbar so it renders between the tab
    // strip and help (trailing items are laid out left-to-right in declaration order).
    @ToolbarContentBuilder
    private var usageRangeToolbarItem: some ToolbarContent {
        if selection == .usage {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(UsageRange.allCases) { range in
                        Button { usageRange = range } label: {
                            if usageRange == range {
                                Label(range.label, systemImage: "checkmark")
                            } else {
                                Text(range.label)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(usageRange.label).font(.headline)
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(SMA.labelPrimary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // Declared after the help button so "+" lands as the rightmost trailing action.
    @ToolbarContentBuilder
    private var remindersAddToolbarItem: some ToolbarContent {
        if selection == .reminders {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { addingReminder = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Add Reminder")
            }
        }
    }
}

// MARK: - Tab strip

/// Pill-style segmented tab selector displayed inline in the navigation bar.
private struct DeviceTabStrip: View {
    @Binding var selection: DeviceTab
    let badgeCount: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DeviceTab.allCases) { tab in
                Button { selection = tab } label: {
                    tabLabel(tab)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.label)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(3)
        .background(SMA.fillTertiary, in: Capsule())
        .animation(.snappy, value: selection)
    }

    @ViewBuilder
    private func tabLabel(_ tab: DeviceTab) -> some View {
        let on = selection == tab
        Text(tab.label)
            .font(.subheadline.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? SMA.labelPrimary : SMA.labelSecondary)
            .overlay(alignment: .topTrailing) {
                if tab == .reminders && badgeCount > 0 {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .offset(x: 5, y: -3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(on ? SMA.segmentedSelected : Color.clear, in: Capsule())
    }
}

// MARK: - Sidebar

/// The sidebar column: Sensi wordmark + account actions in the nav bar, device cards
/// and spotlight below — identical layout to the iPhone dashboard.
private struct SidebarContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            if model.devices.isEmpty {
                SpotlightCard(item: .welcome, expanded: true, onToggle: {}, onDismiss: {})
                    .spotlightCardStyle(kind: .promotional)
            } else {
                ForEach(model.devices) { device in
                    SidebarDeviceCard(device: device)
                }
            }

            let items = model.visibleSpotlights
            if !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        SpotlightCard(
                            item: item,
                            expanded: false,
                            onToggle: {},
                            onDismiss: { model.dismissSpotlight(item) }
                        )
                        .spotlightSidebarCardStyle(kind: item.kind)
                    }
                } header: {
                    HStack(spacing: 6) {
                        Text("Spotlight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SMA.labelSecondary)
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(SMA.accent, in: Capsule())
                            .accessibilityLabel("\(items.count) spotlights")
                    }
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationTitle("")
        .toolbar { DashboardToolbar(showWordmark: true, showHelp: false) }
    }
}

// MARK: - Sidebar device card

/// Compact thermostat card for the sidebar: device name header, current temp and
/// read-only setpoint text (or offline state), with an accent border when selected.
private struct SidebarDeviceCard: View {
    @Environment(AppModel.self) private var model
    let device: Device

    private var isSelected: Bool { device.id == model.device.id }

    var body: some View {
        Section {
            Button { model.selectDevice(device.id) } label: {
                HStack(spacing: 12) {
                    if device.isOffline {
                        Image(systemName: "wifi.slash")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(SMA.offlineRed)
                            .accessibilityHidden(true)
                        Text("Offline")
                            .font(.callout)
                            .foregroundStyle(SMA.labelSecondary)
                        Spacer(minLength: 0)
                    } else {
                        DisplayTemp(value: device.currentTemp, size: 42, activity: device.activity)
                        Spacer(minLength: 8)
                        if !setpointText.isEmpty {
                            Text(setpointText)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(SMA.labelSecondary)
                                .monospacedDigit()
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(
                ZStack {
                    SMA.card
                    if isSelected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(SMA.accent, lineWidth: 2)
                    }
                }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 18))
            .accessibilityLabel(device.name)
            .accessibilityHint("Selects this thermostat")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } header: {
            HStack {
                Text(device.name)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                        .accessibilityHidden(true)
                }
            }
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
        } footer: {
            if device.isOffline, let since = device.offlineSince {
                Text("Offline since \(since)")
                    .textCase(nil)
            }
        }
        .headerProminence(.increased)
    }

    private var setpointText: String {
        switch device.systemMode {
        case .cool:            return "\(device.keepMax)\u{00B0}"
        case .heat, .auxHeat:  return "\(device.keepMin)\u{00B0}"
        case .auto:            return "\(device.keepMin)\u{00B7}\(device.keepMax)"
        case .off:             return ""
        }
    }
}

// MARK: - Spotlight sidebar card style

private extension View {
    func spotlightSidebarCardStyle(kind: SpotlightItem.Kind) -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                SpotlightRowBackground(kind: kind)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowSeparator(.hidden)
    }
}

#Preview {
    MainSplitView()
        .environment(AppModel())
}
