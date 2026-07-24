import SwiftUI

/// The iPad (regular width) signed-in experience. Uses SwiftUI's adaptive tab
/// container so device navigation can present as a sidebar or collapse into a tab bar.
/// The compact (iPhone) experience uses `DashboardView` in a `NavigationStack`
/// instead. See `MainView`.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: DeviceTab = .control
    @State private var spotlightExpanded = true
    /// Individually collapsed spotlight cards (matches the dashboard behavior).
    @State private var collapsedSpotlights: Set<UUID> = []

    var body: some View {
        TabView(selection: $selection) {
            Tab("Control", image: "thermostat.fill", value: DeviceTab.control) {
                destination(for: .control)
            }
            Tab("Schedule", image: "schedule.activity", value: DeviceTab.schedule) {
                destination(for: .schedule)
            }
            Tab("Usage", systemImage: "gauge.with.needle.fill", value: DeviceTab.usage) {
                destination(for: .usage)
            }
            Tab("Reminders", systemImage: "bell", value: DeviceTab.reminders) {
                destination(for: .reminders)
            }
            Tab("Settings", systemImage: "gearshape", value: DeviceTab.settings) {
                destination(for: .settings)
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(.sidebar)
        .tabViewSidebarHeader { deviceSidebarHeader }
        .tabViewSidebarFooter { spotlightSidebarFooter }
        .toolbarRole(.browser)
    }

    private func destination(for tab: DeviceTab) -> some View {
        NavigationStack {
            DeviceTabContent(tab: tab)
                .navigationTitle(tab.navigationTitle(deviceName: model.device.name))
                .inlineNavTitle()
                .toolbar { DashboardToolbar(showWordmark: true) }
        }
    }

    private var deviceSidebarHeader: some View {
        Text(model.device.name)
            .font(.caption.weight(.semibold))
            .foregroundStyle(SMA.labelSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder private var spotlightSidebarFooter: some View {
        let items = model.visibleSpotlights
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.snappy) { spotlightExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Spotlight")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SMA.labelSecondary)
                            .textCase(.uppercase)
                        Spacer()
                        Text("\(items.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(SMA.accent, in: Circle())
                            .accessibilityLabel("\(items.count) spotlights")
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(SMA.accent)
                            .rotationEffect(.degrees(spotlightExpanded ? 90 : 0))
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHint(spotlightExpanded ? "Collapse Spotlight" : "Expand Spotlight")

                if spotlightExpanded {
                    ForEach(items) { item in
                        SpotlightCard(
                            item: item,
                            expanded: !collapsedSpotlights.contains(item.id),
                            onToggle: { toggleSpotlight(item) },
                            onDismiss: { model.dismissSpotlight(item) }
                        )
                        .spotlightSidebarCardStyle(kind: item.kind)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    private func toggleSpotlight(_ item: SpotlightItem) {
        withAnimation(.snappy) {
            if collapsedSpotlights.contains(item.id) {
                collapsedSpotlights.remove(item.id)
            } else {
                collapsedSpotlights.insert(item.id)
            }
        }
    }
}

private extension View {
    func spotlightSidebarCardStyle(kind: SpotlightItem.Kind) -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                SpotlightRowBackground(kind: kind)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
    }
}

#Preview {
    MainSplitView()
        .environment(AppModel())
}
