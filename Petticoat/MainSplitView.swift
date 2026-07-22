import SwiftUI

/// Which sidebar entry is selected in the iPad split view.
enum SidebarItem: Hashable {
    case device
}

/// The iPad (regular width) signed-in experience: a persistent device sidebar with a
/// detail pane. The compact (iPhone) experience uses `DashboardView` in a
/// `NavigationStack` instead — see `MainView`.
struct MainSplitView: View {
    @Environment(AppModel.self) private var model
    @State private var selection: SidebarItem? = .device
    @State private var spotlightExpanded = true

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    DeviceSidebarRow(device: model.device)
                        .tag(SidebarItem.device)
                }

                // Spotlight lives inline in the sidebar under a collapsible header
                // that shows a card count. The whole area is hidden once every card
                // has been dismissed.
                if !model.spotlights.isEmpty {
                    Section(isExpanded: $spotlightExpanded) {
                        ForEach(model.spotlights) { item in
                            SpotlightSidebarCard(item: item) { model.dismissSpotlight(item) }
                                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                    } header: {
                        HStack {
                            Text("Spotlight")
                            Spacer()
                            Text("\(model.spotlights.count)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Devices")
            .toolbar { DashboardToolbar(showWordmark: true) }
        } detail: {
            NavigationStack {
                switch selection {
                case .device, .none:
                    DeviceTabView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
}

// MARK: - Sidebar rows

struct DeviceSidebarRow: View {
    let device: Device

    var body: some View {
        HStack {
            Label(device.name, image: "thermostat.fill")
            Spacer()
            Text("\(device.currentTemp)°")
                .foregroundStyle(SMA.labelSecondary)
                .monospacedDigit()
        }
    }
}

/// A compact, sidebar-native rendering of the Spotlight promo. Restyled from the
/// dashboard `SpotlightCard` to fit the narrow sidebar column.
struct SpotlightSidebarCard: View {
    let item: SpotlightItem
    var onDismiss: () -> Void = {}
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(SMA.orange)
                    .accessibilityHidden(true)
                Text(item.provider)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SMA.brandNavy)
                Spacer()
                Menu {
                    Button("Dismiss", systemImage: "xmark", role: .destructive) { onDismiss() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.labelSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
            }

            Text(item.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(item.body)
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Offer valid until: \(item.validUntil)")
                .font(.caption2)
                .foregroundStyle(SMA.labelSecondary.opacity(0.8))

            Button { showDetail = true } label: {
                Text("Learn More")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(SMA.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SMA.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .sheet(isPresented: $showDetail) { SpotlightDetailView(item: item) }
    }
}

#Preview {
    MainSplitView()
        .environment(AppModel())
}
