import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showControl = false
    /// Spotlight cards shown in their abbreviated form. Empty by default, so every
    /// card starts expanded; the header chevron collapses/expands them all at once,
    /// and tapping a card toggles just that one.
    @State private var collapsedSpotlights: Set<UUID> = []

    var body: some View {
        List {
            // Section order is configurable from Account › Organize Dashboard.
            ForEach(model.dashboardSectionOrder) { section in
                switch section {
                case .thermostats: thermostatSection
                case .spotlight:   spotlightSection
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(16)
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $showControl) { DeviceTabView() }
        .toolbar { DashboardToolbar() }
    }

    /// Thermostat cards (or the onboarding welcome card when there are none).
    @ViewBuilder private var thermostatSection: some View {
        if model.devices.isEmpty {
            SpotlightCard(item: .welcome, expanded: true, onToggle: {}, onDismiss: {})
                .spotlightCardStyle(kind: .promotional)
        } else {
            ForEach(model.devices) { device in
                DashboardThermostatCard(device: device, showControl: $showControl)
            }
        }
    }

    /// Spotlight cards (respecting hidden state). The header chevron expands/collapses
    /// them all at once; tapping a card toggles just that one.
    @ViewBuilder private var spotlightSection: some View {
        let items = model.visibleSpotlights
        if !items.isEmpty {
            // One section so the inter-card gap is set by the row insets (tight),
            // not the larger between-section spacing. Cards keep their own surface.
            Section {
                ForEach(items) { item in
                    SpotlightCard(
                        item: item,
                        expanded: !collapsedSpotlights.contains(item.id),
                        onToggle: { toggleSpotlight(item) },
                        onDismiss: { model.dismissSpotlight(item) }
                    )
                    .spotlightCardStyle(kind: item.kind)
                }
            } header: {
                SpotlightHeader(
                    count: items.count,
                    allExpanded: collapsedSpotlights.isEmpty,
                    onToggle: toggleAllSpotlights
                )
            }
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

    /// Header chevron: collapse every card when all are expanded, else expand all.
    private func toggleAllSpotlights() {
        withAnimation(.snappy) {
            if collapsedSpotlights.isEmpty {
                collapsedSpotlights = Set(model.spotlights.map(\.id))
            } else {
                collapsedSpotlights.removeAll()
            }
        }
    }
}

/// The shared dashboard toolbar (sensi wordmark + plus/help/account). Reused by the
/// compact `DashboardView` and the iPad `MainSplitView` sidebar.
struct DashboardToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model
    var showWordmark = true

    var body: some ToolbarContent {
        if showWordmark {
            ToolbarItem(placement: .topBarLeading) {
                SensiWordmark(color: SMA.labelPrimary, size: 20)
                    .fixedSize()
            }
            .sharedBackgroundVisibility(.hidden)
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { model.showAddDevice = true } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel("Add a Device")
            Button { model.showHelp = true } label: {
                Image(systemName: "questionmark.bubble")
            }
            .accessibilityLabel("Help and Support")
            Button { model.showAccount = true } label: {
                Image(systemName: "person.crop.circle")
            }
            .accessibilityLabel("Account")
        }
    }
}

// MARK: - Thermostat card

struct DashboardThermostatCard: View {
    @Environment(AppModel.self) private var model

    /// The device this card represents.
    let device: Device
    /// Drives the push to the device Control screen. Owned by DashboardView so the
    /// navigationDestination lives on the List, not inside a List row.
    @Binding var showControl: Bool
    @State private var showMode = false
    /// Inline sensor disclosure — reveals the participating-sensor selection in place.
    @State private var sensorsExpanded = false

    var body: some View {
        Section {
            HStack(spacing: 14) {
                ModeSelectPill(axis: .vertical, systemMode: device.systemMode, fanMode: device.fanMode) {
                    model.selectDevice(device.id)
                    showMode = true
                }

                Button {
                    model.selectDevice(device.id)
                    showControl = true
                } label: {
                    HStack(spacing: 8) {
                        DisplayTemp(value: device.currentTemp, size: 46, activity: device.activity)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(device.name) controls")

                SetpointStepper(low: device.keepMin, high: device.keepMax,
                                mode: device.systemMode, showsLabel: true) { bound, delta in
                    model.adjustKeep(bound, by: delta, in: device.id)
                }
            }
            .listRowBackground(SMA.card)
            .listRowSeparator(.hidden)

            if sensorsExpanded && model.showSensorsOnDashboard {
                ForEach(device.sensors) { sensor in
                    SensorSelectRow(sensor: sensor) { model.toggleSensor(sensor, in: device.id) }
                        .listRowBackground(SMA.card)
                }
            }
        } header: {
            Group {
                if model.showSensorsOnDashboard {
                    // Tappable header discloses the participating-sensor selection.
                    Button {
                        withAnimation(.snappy) { sensorsExpanded.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Text(device.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(SMA.labelPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SMA.accent)
                                .rotationEffect(.degrees(sensorsExpanded ? 90 : 0))
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                        .accessibilityAddTraits(.isHeader)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(device.name)
                    .accessibilityHint(sensorsExpanded ? "Collapse sensors" : "Choose participating sensors")
                } else {
                    Text(device.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            .textCase(nil)
        } footer: {
            HStack(spacing: 4) {
                Image(systemName: footer.icon)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(footer.text)
            }
            .font(.footnote)
            .foregroundStyle(SMA.labelSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .textCase(nil)
        }
        .sheet(isPresented: $showMode) {
            ModeSheet()
        }
    }

    /// The footer mirrors the schedule settings. On a schedule it counts down to the
    /// next setpoint; the pin means the geofence can end the period early via auto
    /// home/away (any preset other than Away is treated as Home).
    private var footer: (icon: String, text: String) {
        let geofenced = device.geofenceEnabled
        let isAway = model.activeProfile.name.lowercased() == "away"
        let presence = isAway ? "Home" : "Away"

        switch model.controlMode {
        case .schedule:
            return geofenced
                ? ("location.fill", "Until next setpoint or \(presence)")
                : ("clock", "Until next setpoint")
        case .hold, .activity:
            return geofenced
                ? ("location.fill", "Until \(device.holdUntil)")
                : ("clock", "Until \(device.holdUntil.replacingOccurrences(of: " or Away", with: ""))")
        case .vacation:
            return ("airplane", "Until your vacation ends")
        case .standard:
            return ("thermostat.medium", "Held until you change it")
        }
    }
}

/// One paired room sensor in the dashboard card, presented as a selection: tapping
/// the row toggles whether it participates in the averaged temperature. Temperature
/// and humidity are shown as plain numbers; the battery icon shifts green → orange →
/// red as the charge falls.
struct SensorSelectRow: View {
    let sensor: RoomSensor
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                Image(systemName: sensor.participating ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(sensor.participating ? SMA.accent : SMA.labelSecondary)
                    .accessibilityHidden(true)
                Text(sensor.name)
                    .foregroundStyle(SMA.labelPrimary)
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    // Battery first (only for battery-powered models), then humidity, then temp.
                    if let level = sensor.battery {
                        Image(systemName: RoomSensor.batterySymbol(level))
                            .foregroundStyle(RoomSensor.batteryColor(level))
                            .accessibilityLabel("Battery \(level) percent")
                    }
                    Text("\(sensor.humidity)%")
                    Text("\(sensor.temp)°")
                }
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
                .monospacedDigit()
            }
            .padding(.vertical, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(sensor.participating ? [.isSelected] : [])
        .accessibilityHint("Toggles whether this sensor participates in the average")
    }
}

// MARK: - Spotlight

struct SpotlightHeader: View {
    let count: Int
    let allExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Text("Spotlight")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SMA.labelPrimary)
                Spacer()
                Text("\(count)")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(SMA.accent, in: Circle())
                    .accessibilityLabel("\(count) spotlights")
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.accent)
                    .rotationEffect(.degrees(allExpanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityHint(allExpanded ? "Collapse all spotlights" : "Expand all spotlights")
    }
}

/// A dashboard spotlight card. The three kinds share one layout — hero image, title,
/// body, an "Expires:" subline, a separator, then an action button with an overflow
/// menu in the corner. Promotional cards use the filled brand surface and stay
/// expanded; generic/partner cards are white and collapse to hero + title until
/// tapped.
struct SpotlightCard: View {
    @Environment(AppModel.self) private var model
    let item: SpotlightItem
    let expanded: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void
    @State private var showDetail = false

    private var kind: SpotlightItem.Kind { item.kind }
    private var isOpen: Bool { expanded }

    var body: some View {
        Group {
            if isOpen { expandedContent } else { collapsedContent }
        }
        .sheet(isPresented: $showDetail) { SpotlightDetailView(item: item) }
    }

    /// Hero + full title, body, subline, separator, and the CTA / overflow row.
    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                hero
                Text(item.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(bodyColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !item.subline.isEmpty {
                    Text(item.subline)
                        .font(.footnote)
                        .foregroundStyle(sublineColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            Divider().overlay(separatorColor)

            HStack {
                Button { primaryAction() } label: {
                    Text(item.actionLabel ?? kind.defaultActionLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(kind.buttonLabelColor)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(kind.buttonTint, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                overflow
            }
        }
    }

    /// Compact form: hero, a smaller headline, and a one-line body that truncates
    /// with the overflow icon sitting on its trailing baseline.
    private var collapsedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            hero
            Text(item.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(titleColor)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(bodyColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                overflow
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onToggle() }
    }

    private var hero: some View {
        Image(item.heroImage ?? kind.defaultHero)
            .resizable()
            .scaledToFit()
            .frame(height: 32)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    private var overflow: some View {
        Menu {
            if item.startsInstall {
                Button("Get Help", systemImage: "questionmark.circle") { model.showHelp = true }
            } else {
                if !isOpen {
                    Button("Learn More", systemImage: "arrow.up.right") { showDetail = true }
                }
                Button("Dismiss", systemImage: "xmark", role: .destructive) { onDismiss() }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.weight(.bold))
                .foregroundStyle(kind.accent)
                .frame(width: 26, height: 26)
                .overlay(Circle().stroke(kind.accent, lineWidth: 1.5))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options")
    }

    private func primaryAction() {
        if item.startsInstall { model.showAddDevice = true } else { showDetail = true }
    }

    private var titleColor: Color { kind.isFilled ? .white : SMA.labelPrimary }
    private var bodyColor: Color { kind.isFilled ? .white.opacity(0.75) : SMA.labelSecondary }
    private var sublineColor: Color { kind.isFilled ? .white.opacity(0.35) : SMA.labelSecondary.opacity(0.5) }
    private var separatorColor: Color { kind.isFilled ? .white.opacity(0.25) : SMA.separator }
}

/// The list-row fill behind a spotlight card: the teal brand surface for the filled
/// promotional card, the standard white card for the rest.
struct SpotlightRowBackground: View {
    let kind: SpotlightItem.Kind

    var body: some View {
        if kind.isFilled {
            SMA.brandTeal
                .overlay(
                    LinearGradient(colors: [.clear, .black.opacity(0.04)],
                                   startPoint: .top, endPoint: .bottom)
                )
        } else {
            SMA.card
        }
    }
}

private extension View {
    /// Renders a spotlight card as a self-contained rounded surface inside a clear
    /// list row, so all cards can live in one reorderable section.
    func spotlightCardStyle(kind: SpotlightItem.Kind) -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                SpotlightRowBackground(kind: kind)
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
            .listRowBackground(Color.clear)
            // Full-bleed width; tight vertical gap between stacked cards.
            .listRowInsets(EdgeInsets(top: 5, leading: 0, bottom: 5, trailing: 0))
            .listRowSeparator(.hidden)
    }
}

// MARK: - Spotlight detail & Add device sheets

/// Full detail for a spotlight promo, opened by "Learn More". Local content only.
struct SpotlightDetailView: View {
    let item: SpotlightItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(SMA.orange)
                            .accessibilityHidden(true)
                        Text(item.provider)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(SMA.brandNavy)
                    }

                    Text(item.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)

                    Text(item.body)
                        .font(.body)
                        .foregroundStyle(SMA.labelPrimary)

                    Text("Offer valid until: \(item.validUntil)")
                        .font(.footnote)
                        .foregroundStyle(SMA.labelSecondary)

                    Spacer(minLength: 8)

                    Button {
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(SMA.orange)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(item.provider)
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(SMA.labelPrimary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}

#Preview("With thermostat") {
    NavigationStack {
        DashboardView()
    }
    .environment(AppModel())
}

#Preview("No thermostat") {
    let model = AppModel()
    model.devices = []
    return NavigationStack {
        DashboardView()
    }
    .environment(model)
}
