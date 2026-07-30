import SwiftUI

/// The iPad (regular width) signed-in experience. A `NavigationSplitView` where the
/// sidebar shows device cards + spotlight (mirroring the dashboard), and the detail
/// shows the selected device's content. Navigation between the five device tabs happens
/// via a pill-style strip in the detail's nav bar — same row as the sidebar
/// expand/collapse button, device name picker, and help button.
/// The compact (iPhone) experience uses `DashboardView` in a `NavigationStack`. See `MainView`.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @State private var usageRange: UsageRange = .recent

    var body: some View {
        @Bindable var model = model
        // Map the shared `sidebarVisible` flag to the split view's column visibility,
        // so the menu bar's Show/Hide Dashboard command and the toolbar button agree.
        let columnVisibility = Binding<NavigationSplitViewVisibility>(
            get: { model.sidebarVisible ? .all : .detailOnly },
            set: { model.sidebarVisible = $0 != .detailOnly }
        )
        NavigationSplitView(columnVisibility: columnVisibility) {
            // Drop the default sidebar toggle; the dashboard button in the detail's
            // nav bar (below) drives the sidebar instead, matching the iPhone icon.
            SidebarContent()
                .toolbar(removing: .sidebarToggle)
        } detail: {
            NavigationStack {
                DeviceTabContent(
                    tab: model.selectedTab,
                    usageRange: model.selectedTab == .usage ? $usageRange : .constant(.recent)
                )
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Expand / collapse the sidebar (dashboard) column.
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.snappy) { model.sidebarVisible.toggle() }
                        } label: {
                            Image(systemName: "sidebar.leading")
                        }
                        .accessibilityLabel(model.sidebarVisible ? "Collapse Sidebar" : "Expand Sidebar")
                    }
                    // Split the device picker into its own group, apart from the
                    // sidebar toggle.
                    ToolbarSpacer(.fixed, placement: .topBarLeading)
                    // Device name — tappable menu when multiple thermostats are registered
                    ToolbarItem(placement: .topBarLeading) {
                        deviceNameItem
                    }
                    // Tab strip centred in the nav bar, same row as all other actions
                    ToolbarItem(placement: .principal) {
                        DeviceTabStrip(selection: $model.selectedTab, badgeCount: model.criticalReminderCount)
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
        .sheet(isPresented: $model.addingReminder) {
            ReminderEditor(initial: nil) { model.saveReminder($0) }
        }
    }

    /// A menu-row label with the selection checkmark on the trailing edge.
    private func menuLabel(_ text: String, checked: Bool) -> some View {
        HStack {
            Text(text)
            if checked {
                Spacer()
                Image(systemName: "checkmark")
            }
        }
    }

    // MARK: - Device name / picker

    @ViewBuilder
    private var deviceNameItem: some View {
        if model.devices.count > 1 {
            Menu {
                ForEach(model.devices) { device in
                    Button { model.selectDevice(device.id) } label: {
                        menuLabel(device.name, checked: device.id == model.device.id)
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
        if model.selectedTab == .usage {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ForEach(UsageRange.allCases) { range in
                        Button { usageRange = range } label: {
                            menuLabel(range.label, checked: usageRange == range)
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
            // Split the range menu into its own group, apart from the help icon.
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
        }
    }

    // Declared after the help button so "+" lands as the rightmost trailing action.
    @ToolbarContentBuilder
    private var remindersAddToolbarItem: some ToolbarContent {
        if model.selectedTab == .reminders {
            ToolbarSpacer(.fixed, placement: .topBarTrailing)
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.addingReminder = true } label: { Image(systemName: "plus") }
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
    /// IDs of spotlight cards shown in their abbreviated form. Empty = all expanded.
    /// The header chevron collapses/expands all at once; tapping a card toggles just
    /// that one — mirroring the iPhone dashboard's Spotlight behaviour.
    @State private var collapsedSpotlights: Set<UUID> = []

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
            let allCollapsed = items.allSatisfy { collapsedSpotlights.contains($0.id) }
            if !items.isEmpty {
                Section {
                    ForEach(items) { item in
                        SpotlightCard(
                            item: item,
                            expanded: !collapsedSpotlights.contains(item.id),
                            onToggle: { toggleSpotlight(item) },
                            onDismiss: { model.dismissSpotlight(item) }
                        )
                        .spotlightSidebarCardStyle(kind: item.kind)
                    }
                } header: {
                    Button {
                        withAnimation(.snappy) {
                            collapsedSpotlights = allCollapsed ? [] : Set(items.map(\.id))
                        }
                    } label: {
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
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(SMA.labelSecondary)
                                .rotationEffect(.degrees(allCollapsed ? -90 : 0))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .textCase(.uppercase)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Spotlight, \(items.count)")
                    .accessibilityHint(allCollapsed ? "Expand spotlights" : "Collapse spotlights")
                    .accessibilityAddTraits(.isHeader)
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        // Trim the system inset-grouped section margin so cards sit closer to the
        // narrow sidebar's edges; per-row insets still provide the small gutter.
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(.ultraThinMaterial, ignoresSafeAreaEdges: .all)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .navigationTitle("")
        .toolbar { DashboardToolbar(showWordmark: true, showHelp: false) }
    }

    private func toggleSpotlight(_ item: SpotlightItem) {
        withAnimation(.snappy) { collapsedSpotlights.toggleMembership(item.id) }
    }
}

// MARK: - Sidebar device card

/// Compact thermostat card for the sidebar: device name header, current temp and
/// read-only setpoint text (or offline state), with an accent border when selected.
private struct SidebarDeviceCard: View {
    @Environment(AppModel.self) private var model
    let device: Device

    private var isSelected: Bool { device.id == model.device.id }
    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 14, style: .continuous) }

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
                .padding(EdgeInsets(top: 14, leading: 14, bottom: 14, trailing: 18))
                .frame(maxWidth: .infinity)
                // Draw card + selection border ourselves and clear the system row
                // background, matching the Spotlight cards' approach. The row inset
                // below keeps this inside the inset-grouped mask, so the border's
                // corners are never clipped and trace the fill exactly.
                .background(SMA.card, in: cardShape)
                .overlay { if isSelected { cardShape.strokeBorder(SMA.accent, lineWidth: 2) } }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .accessibilityLabel(device.name)
            .accessibilityHint("Selects this thermostat")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            // Stable handle for UI tests; disambiguates the card from the
            // detail toolbar's device-picker menu, which shares the device name.
            .accessibilityIdentifier("sidebar-device-\(device.name)")
        } header: {
            Text(device.name)
                .frame(maxWidth: .infinity, alignment: .leading)
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
