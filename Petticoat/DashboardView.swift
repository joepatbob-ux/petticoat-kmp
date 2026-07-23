import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var showControl = false
    /// Which spotlight cards are expanded. Each expands independently — no stack.
    @State private var expandedSpotlights: Set<UUID> = []

    var body: some View {
        List {
            if model.hasThermostat {
                DashboardThermostatCard(showControl: $showControl)
            } else {
                // No thermostat yet: lead with the filled onboarding spotlight.
                Section {
                    WelcomeSpotlightCard(item: .welcome)
                        .listRowBackground(WelcomeCardBackground())
                }
            }

            if !model.spotlights.isEmpty {
                // Each spotlight is its own card. Tapping one expands just that card;
                // the others stay collapsed. The "Spotlight" title rides on the first.
                ForEach(Array(model.spotlights.enumerated()), id: \.element.id) { index, item in
                    Section {
                        SpotlightRow(
                            item: item,
                            expanded: expandedSpotlights.contains(item.id),
                            onToggle: { toggleSpotlight(item) },
                            onDismiss: { model.dismissSpotlight(item) }
                        )
                        .listRowBackground(SMA.card)
                    } header: {
                        if index == 0 { SpotlightHeader(count: model.spotlights.count) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationDestination(isPresented: $showControl) { DeviceTabView() }
        .toolbar { DashboardToolbar() }
    }

    private func toggleSpotlight(_ item: SpotlightItem) {
        withAnimation(.snappy) {
            if expandedSpotlights.contains(item.id) {
                expandedSpotlights.remove(item.id)
            } else {
                expandedSpotlights.insert(item.id)
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

    /// Drives the push to the device Control screen. Owned by DashboardView so the
    /// navigationDestination lives on the List, not inside a List row (which made
    /// an embedded NavigationLink hijack the header's tap).
    @Binding var showControl: Bool
    @State private var showMode = false
    /// Inline sensor disclosure. Expanding reveals the participating-sensor
    /// selection in place; it does not drill into the device — tapping the
    /// temperature body does that.
    @State private var sensorsExpanded = false

    private var device: Device { model.device }

    var body: some View {
        Section {
            HStack(spacing: 14) {
                ModeSelectPill(axis: .vertical, systemMode: device.systemMode, fanMode: device.fanMode) {
                    showMode = true
                }

                // Tapping the temperature body drills into the Control screen. The
                // mode pill and stepper flanking it keep their own actions.
                Button {
                    showControl = true
                } label: {
                    HStack(spacing: 8) {
                        Text("\(device.currentTemp)")
                            .font(SMA.displayTemp(size: 46, activity: device.activity))
                            .foregroundStyle(SMA.tempColor(device.activity))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open \(device.name) controls")

                SetpointStepper(low: device.keepMin, high: device.keepMax,
                                mode: device.systemMode, showsLabel: true) { bound, delta in
                    model.adjustKeep(bound, by: delta)
                }
            }
            .listRowBackground(SMA.card)
            .listRowSeparator(.hidden)

            if sensorsExpanded {
                ForEach(device.sensors) { sensor in
                    SensorSelectRow(sensor: sensor) { model.toggleSensor(sensor) }
                        .listRowBackground(SMA.card)
                }
            }
        } header: {
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
            .textCase(nil)
            .accessibilityLabel(device.name)
            .accessibilityHint(sensorsExpanded ? "Collapse sensors" : "Choose participating sensors")
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

    var body: some View {
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
        }
        .textCase(nil)
    }
}

/// A single spotlight card that expands in place. Collapsed, it shows the provider
/// and title with a chevron; expanded, it reveals the full promo body and actions.
/// Tapping the header row toggles the card; the overflow menu and Learn More are
/// independent controls.
struct SpotlightRow: View {
    let item: SpotlightItem
    let expanded: Bool
    let onToggle: () -> Void
    let onDismiss: () -> Void
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Tapping the header expands/collapses this card. The provider logo
            // (an SVG asset) will sit ahead of the text once it's added.
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.provider)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(SMA.brandNavy)
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SMA.labelPrimary)
                        .lineLimit(expanded ? nil : 1)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(expanded ? "Collapse spotlight" : "Expand spotlight")

            if expanded {
                Text(item.body)
                    .font(.subheadline)
                    .foregroundStyle(SMA.labelSecondary)

                Text("Offer valid until: \(item.validUntil)")
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary.opacity(0.8))

                Divider().overlay(SMA.separator)
            }

            // Bottom action row: Learn More when open, overflow menu in the corner.
            HStack {
                if expanded {
                    Button("Learn More") { showDetail = true }
                        .font(.subheadline.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(SMA.orange)
                }
                Spacer()
                Menu {
                    if !expanded {
                        Button("Learn More", systemImage: "arrow.up.right") { showDetail = true }
                    }
                    Button("Dismiss", systemImage: "xmark", role: .destructive) { onDismiss() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showDetail) { SpotlightDetailView(item: item) }
    }
}

/// The filled onboarding spotlight shown when no thermostat has been added. Unlike
/// the promo cards it doesn't collapse — it always shows its message and a prominent
/// "Get Started" action, with the overflow menu in the bottom corner.
struct WelcomeSpotlightCard: View {
    @Environment(AppModel.self) private var model
    let item: SpotlightItem

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.title.weight(.bold))
                    .foregroundStyle(.white)
                Text(item.body)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Divider().overlay(Color.white.opacity(0.25))

            HStack {
                Button { model.showAddDevice = true } label: {
                    Text(item.actionLabel ?? "Get Started")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SMA.brandTeal)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(.white, in: Capsule())
                }
                .buttonStyle(.plain)
                Spacer()
                Menu {
                    Button("Get Help", systemImage: "questionmark.circle") { model.showHelp = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
            }
        }
        .padding(.vertical, 4)
    }
}

/// The teal fill (with the design's subtle bottom shade) behind the welcome card.
struct WelcomeCardBackground: View {
    var body: some View {
        SMA.brandTeal
            .overlay(
                LinearGradient(colors: [.clear, .black.opacity(0.04)],
                               startPoint: .top, endPoint: .bottom)
            )
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
    model.hasThermostat = false
    return NavigationStack {
        DashboardView()
    }
    .environment(model)
}
