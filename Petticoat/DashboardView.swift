import SwiftUI

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @State private var spotlightExpanded = true
    @State private var showControl = false

    var body: some View {
        List {
            DashboardThermostatCard(showControl: $showControl)

            if !model.spotlights.isEmpty {
                // The header + lead card live in a stable Section; the remaining cards
                // are separate Sections that animate out when the section collapses.
                // Collapsed, the lead card becomes a stack of the cards behind it.
                Section {
                    if spotlightExpanded {
                        SpotlightCard(item: model.spotlights[0]) {
                            model.dismissSpotlight(model.spotlights[0])
                        }
                        .listRowBackground(SMA.card)
                    } else {
                        SpotlightStack(items: model.spotlights) { model.dismissSpotlight($0) }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    SpotlightHeader(count: model.spotlights.count, expanded: $spotlightExpanded)
                }

                if spotlightExpanded {
                    ForEach(Array(model.spotlights.dropFirst())) { item in
                        Section {
                            SpotlightCard(item: item) { model.dismissSpotlight(item) }
                                .listRowBackground(SMA.card)
                        }
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
    /// Inline sensor list disclosure. Expanding reveals the paired sensors in place;
    /// it does not drill into the device — tapping the temperature body does that.
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

                SetpointStepper(low: device.keepMin, high: device.keepMax) { bound, delta in
                    model.adjustKeep(bound, by: delta)
                }
            }
            .listRowBackground(SMA.card)

            if sensorsExpanded {
                ForEach(device.sensors) { sensor in
                    SensorRow(sensor: sensor)
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
                    Text(device.sensorSummary)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.labelSecondary)
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
            .accessibilityLabel("\(device.name), \(device.sensorSummary)")
            .accessibilityHint(sensorsExpanded ? "Collapse sensor list" : "Expand sensor list")
        } footer: {
            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text("Until \(device.holdUntil)")
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
}

/// One paired room sensor in the dashboard card's expandable list.
struct SensorRow: View {
    let sensor: RoomSensor

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: sensor.participating ? "sensor.fill" : "sensor")
                .foregroundStyle(sensor.participating ? SMA.accent : SMA.labelSecondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(sensor.name)
                    .foregroundStyle(SMA.labelPrimary)
                Text(sensor.participating ? "Participating" : "Not participating")
                    .font(.caption)
                    .foregroundStyle(SMA.labelSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 10) {
                Label("\(sensor.temp)°", systemImage: "thermometer.medium")
                Label("\(sensor.humidity)%", systemImage: "humidity.fill")
            }
            .font(.footnote)
            .foregroundStyle(SMA.labelSecondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Spotlight

struct SpotlightHeader: View {
    let count: Int
    @Binding var expanded: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
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
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
    }
}

/// Collapsed presentation of the Spotlight section: the top card shown with the
/// remaining cards peeking behind it as a stack. Tapping expands the section.
struct SpotlightStack: View {
    let items: [SpotlightItem]
    let onDismiss: (SpotlightItem) -> Void

    private var peek: CGFloat { items.count > 2 ? 14 : (items.count > 1 ? 7 : 0) }

    var body: some View {
        SpotlightAbbrevCard(item: items[0]) { onDismiss(items[0]) }
            .background {
                ZStack {
                    if items.count > 2 {
                        cardSurface.padding(.horizontal, 20).offset(y: -14)
                    }
                    if items.count > 1 {
                        cardSurface.padding(.horizontal, 10).offset(y: -7)
                    }
                    cardSurface
                }
            }
            // Breathing room so the top peeks and drop shadow aren't clipped by the row.
            .padding(.top, peek + 10)
            .padding([.horizontal, .bottom], 12)
    }

    private var cardSurface: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(SMA.card)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
}

/// Abbreviated spotlight card for the collapsed stack: provider + title only, with an
/// overflow menu (Learn More / Dismiss). Kept short so the stack stays compact.
struct SpotlightAbbrevCard: View {
    let item: SpotlightItem
    let onDismiss: () -> Void
    @State private var showDetail = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .foregroundStyle(SMA.orange)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.provider)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(SMA.brandNavy)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SMA.labelPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Menu {
                Button("Learn More", systemImage: "arrow.up.right") { showDetail = true }
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
        .padding(14)
        .sheet(isPresented: $showDetail) { SpotlightDetailView(item: item) }
    }
}

struct SpotlightCard: View {
    let item: SpotlightItem
    var onDismiss: () -> Void = {}
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(SMA.orange)
                    .accessibilityHidden(true)
                Text(item.provider)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(SMA.brandNavy)
            }

            Text(item.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)

            Text(item.body)
                .font(.subheadline)
                .foregroundStyle(SMA.labelSecondary)

            Text("Offer valid until: \(item.validUntil)")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary.opacity(0.8))

            Divider().overlay(SMA.separator)

            HStack {
                Button("Learn More") { showDetail = true }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(SMA.orange)
                Spacer()
                Menu {
                    Button("Dismiss", systemImage: "xmark", role: .destructive) { onDismiss() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                        .frame(width: 26, height: 26)
                        .overlay(Circle().stroke(SMA.accent, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("More options")
            }
        }
        .sheet(isPresented: $showDetail) { SpotlightDetailView(item: item) }
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

#Preview {
    NavigationStack {
        DashboardView()
    }
    .environment(AppModel())
}
