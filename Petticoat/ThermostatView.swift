import SwiftUI

/// The light-themed Environmental Control screen — the "Control" tab.
struct ControlView: View {
    @Environment(AppModel.self) private var model

    @State private var showMode = false

    private var device: Device { model.device }

    var body: some View {
        VStack(spacing: 0) {
            WeatherSummary(
                location: device.location,
                temp: device.outdoorTemp,
                high: device.outdoorHigh,
                low: device.outdoorLow
            )
            .padding(.top, 8)

            SensorAveragePill(summary: device.sensorSummary)
                .padding(.top, 20)

            Spacer()

            Text("\(device.currentTemp)")
                .font(SMA.displayTemp(size: 170, activity: device.activity))
                .foregroundStyle(SMA.tempColor(device.activity))
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HumidityLabel(humidity: device.humidity)

            Spacer()

            ModeSelectPill(systemMode: device.systemMode, fanMode: device.fanMode) {
                showMode = true
            }
            .padding(.bottom, 24)

            ControllerSection()
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 20)
        .readableWidth()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .sheet(isPresented: $showMode) {
            ModeSheet()
        }
    }
}

// MARK: - Weather

struct WeatherSummary: View {
    let location: String
    let temp: Int
    let high: Int
    let low: Int

    var body: some View {
        VStack(spacing: 6) {
            Text(location)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SMA.labelPrimary)
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(SMA.labelPrimary)
                Text("\(temp)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SMA.labelPrimary)
                VStack(alignment: .leading, spacing: 0) {
                    Text("H: \(high)")
                    Text("L: \(low)")
                }
                .font(.caption)
                .foregroundStyle(SMA.labelSecondary)
            }
        }
    }
}

// MARK: - Sensor average pill

struct SensorAveragePill: View {
    let summary: String

    var body: some View {
        VStack(spacing: 1) {
            Text("Average Of")
                .font(.caption2)
                .foregroundStyle(SMA.labelSecondary)
            Text(summary)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SMA.labelPrimary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .background(SMA.fillTertiary, in: Capsule())
    }
}

// MARK: - Humidity

struct HumidityLabel: View {
    let humidity: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "humidity.fill")
                .foregroundStyle(SMA.accent)
            Text("\(humidity)%")
                .foregroundStyle(SMA.labelSecondary)
        }
        .font(.callout)
    }
}

// MARK: - Mode selector

/// A compact, tappable summary of the current system + fan mode. Tapping it
/// opens the Mode sheet — it is NOT a toggle.
struct ModeSelectPill: View {
    var axis: Axis = .horizontal
    let systemMode: SystemMode
    let fanMode: FanMode
    let action: () -> Void

    var body: some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: 10))
            : AnyLayout(VStackLayout(spacing: 10))

        Button(action: action) {
            layout {
                SystemModeIcon(mode: systemMode, size: 24)
                separator
                FanModeIcon(mode: fanMode, size: 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(SMA.fillTertiary, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Short divider between the system and fan icons — orientation follows the axis.
    private var separator: some View {
        Capsule()
            .fill(SMA.labelSecondary.opacity(0.35))
            .frame(
                width: axis == .horizontal ? 1 : 18,
                height: axis == .horizontal ? 18 : 1
            )
    }
}

/// The reusable range display + steppers. At rest it shows "low · high";
/// once the user adjusts, it becomes a toggle that picks which bound to change.
/// Shared by the Control tab and the dashboard thermostat card.
struct SetpointStepper: View {
    let low: Int
    let high: Int
    let onAdjust: (SetpointBound, Int) -> Void

    @State private var editing: SetpointBound?

    var body: some View {
        HStack(spacing: 12) {
            if let editing {
                SetpointToggle(low: low, high: high, selected: editing) { self.editing = $0 }
            } else {
                HStack(spacing: 8) {
                    Text("\(low)")
                    Image(systemName: "circle.fill").font(.system(size: 4))
                        .foregroundStyle(SMA.labelSecondary)
                    Text("\(high)")
                }
                .font(.title3.weight(.semibold))
                .foregroundStyle(SMA.labelPrimary)
            }

            VStack(spacing: 8) {
                stepper("plus", delta: 1)
                stepper("minus", delta: -1)
            }
        }
        .animation(.snappy, value: editing)
    }

    private func stepper(_ symbol: String, delta: Int) -> some View {
        Button {
            let bound = editing ?? .low
            editing = bound
            onAdjust(bound, delta)
        } label: {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(SMA.labelPrimary)
                .frame(width: 32, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SetpointToggle: View {
    let low: Int
    let high: Int
    let selected: SetpointBound
    let onSelect: (SetpointBound) -> Void

    var body: some View {
        HStack(spacing: 4) {
            segment(value: low, bound: .low)
            segment(value: high, bound: .high)
        }
        .padding(4)
        .background(SMA.fillTertiary, in: Capsule())
    }

    private func segment(value: Int, bound: SetpointBound) -> some View {
        Button { onSelect(bound) } label: {
            Text("\(value)")
                .font(.title3.weight(.semibold))
                .foregroundStyle(selected == bound ? SMA.labelPrimary : SMA.labelSecondary)
                .frame(width: 48, height: 38)
                .background { if selected == bound { Capsule().fill(SMA.card) } }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mode-aware controller

/// The bottom controller section. Renders per `ControlMode`. In schedule mode it is a
/// horizontally swipeable pager of period controllers — only the current period is
/// editable; upcoming periods are read-only previews. The status control opens a
/// placeholder sheet.
struct ControllerSection: View {
    @Environment(AppModel.self) private var model
    @State private var showStatus = false
    @State private var page: Int? = 0

    private var device: Device { model.device }
    private var pageCount: Int { model.upcomingPeriods.count + 1 }

    var body: some View {
        Group {
            if model.controlMode == .schedule {
                scheduleController
            } else {
                VStack(spacing: 10) {
                    singleCard
                    footer
                }
            }
        }
        .sheet(isPresented: $showStatus) { ControllerStatusSheet(mode: model.controlMode) }
    }

    // MARK: Non-schedule single card

    private var singleCard: some View {
        HStack(spacing: 14) {
            leading
            Spacer(minLength: 8)
            SetpointStepper(low: device.keepMin, high: device.keepMax) { bound, delta in
                model.adjustKeep(bound, by: delta)
            }
        }
        .frame(height: 64)
        .controllerCard()
    }

    // MARK: Schedule pager

    private var scheduleController: some View {
        VStack(spacing: 10) {
            Text("Schedule: \(device.scheduleName)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(SMA.labelSecondary)

            GeometryReader { geo in
                // Full-bleed (cancels the screen's 20pt content inset) so the current
                // card matches the non-schedule card's width and neighbours peek in the
                // screen margins.
                let cardWidth = max(0, geo.size.width - 40)
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        currentPeriodCard.frame(width: cardWidth).id(0)
                        ForEach(Array(model.upcomingPeriods.enumerated()), id: \.element.id) { index, period in
                            periodCard(period).frame(width: cardWidth).id(index + 1)
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 20, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $page, anchor: .center)
                .scrollIndicators(.hidden)
                .scrollClipDisabled()
            }
            .padding(.horizontal, -20)
            .frame(height: 92)

            HStack(spacing: 12) {
                scheduleFooter
                Spacer()
                pageDots
            }
            .padding(.horizontal, 16)
        }
        .animation(.snappy, value: page)
    }

    /// Current period — editable setpoint.
    private var currentPeriodCard: some View {
        HStack(spacing: 14) {
            profileChip(symbol: model.activeProfile.symbol, colorHex: model.activeProfile.colorHex, name: model.activeProfile.name)
            Spacer(minLength: 8)
            SetpointStepper(low: device.keepMin, high: device.keepMax) { bound, delta in
                model.adjustKeep(bound, by: delta)
            }
        }
        .frame(height: 64)
        .controllerCard()
    }

    /// Upcoming period — read-only preview (no setpoint control).
    private func periodCard(_ period: TimelinePeriod) -> some View {
        HStack(spacing: 14) {
            profileChip(symbol: period.symbol, colorHex: period.colorHex, name: period.name)
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text("\(period.heatTo)")
                Image(systemName: "circle.fill").font(.system(size: 4))
                Text("\(period.coolTo)")
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(SMA.labelSecondary)
            .monospacedDigit()
        }
        .frame(height: 64)
        .controllerCard()
    }

    private func profileChip(symbol: String, colorHex: UInt, name: String) -> some View {
        Button { showStatus = true } label: {
            HStack(spacing: 8) {
                ProfileIcon(symbol: symbol, colorHex: colorHex, size: 30)
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelPrimary)
            }
        }
        .buttonStyle(.plain)
    }

    private var pageDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<pageCount, id: \.self) { i in
                Capsule()
                    .fill(i == (page ?? 0) ? SMA.accent : SMA.fillTertiary)
                    .frame(width: i == (page ?? 0) ? 16 : 6, height: 6)
            }
        }
    }

    // MARK: Leading element (single-card modes)

    @ViewBuilder private var leading: some View {
        switch model.controlMode {
        case .standard:
            Text("Keep Between")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SMA.labelSecondary)

        case .hold:
            Button { showStatus = true } label: {
                Text("Hold\n(1 Hour)")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(SMA.destructive)
                    .frame(width: 78, height: 56)
                    .background(SMA.destructive.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

        case .activity:
            profileChip(symbol: model.activeProfile.symbol, colorHex: model.activeProfile.colorHex, name: model.activeProfile.name)

        case .vacation:
            Button { showStatus = true } label: {
                VStack(spacing: 2) {
                    Image(systemName: "airplane").font(.body.weight(.semibold))
                    Text("Vacation").font(.caption2.weight(.semibold))
                }
                .foregroundStyle(SMA.accent)
                .frame(width: 78, height: 56)
                .background(SMA.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

        case .schedule:
            EmptyView()
        }
    }

    @ViewBuilder private var footer: some View {
        switch model.controlMode {
        case .standard, .schedule:
            EmptyView()
        case .hold, .activity:
            untilLabel(device.holdUntil)
        case .vacation:
            Text("Until your vacation ends")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
        }
    }

    private func untilLabel(_ text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "location.fill").font(.caption2)
            Text("Until \(text)")
        }
        .font(.footnote)
        .foregroundStyle(SMA.labelSecondary)
    }

    /// Footer for the schedule pager: the current period shows when it ends
    /// ("Until …"); upcoming periods show when they begin ("Starts …"). The location
    /// pin appears on the current period only when geofenced auto home/away is on —
    /// signalling the period can end early if the fence is crossed.
    private var scheduleFooter: some View {
        let index = page ?? 0
        let isCurrent = index == 0
        // The pin only means something when the geofence can move the schedule.
        let icon = isCurrent
            ? (device.geofenceEnabled ? "location.fill" : "clock")
            : "clock"
        // "… or Away" only holds when the geofence can trigger the change.
        let until = device.geofenceEnabled
            ? device.holdUntil
            : device.holdUntil.replacingOccurrences(of: " or Away", with: "")
        let text = isCurrent
            ? "Until \(until)"
            : "Starts \(model.upcomingPeriods[index - 1].startText)"
        return HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(SMA.labelSecondary)
    }
}

private extension View {
    /// The shared full-width glass controller card treatment.
    func controllerCard() -> some View {
        self
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(in: .rect(cornerRadius: 24))
    }
}

/// Status sheet opened by the controller status control. Summarizes the current
/// control mode (Hold / Activity / Vacation / Schedule) and offers a
/// "Resume Schedule" action where relevant.
struct ControllerStatusSheet: View {
    let mode: ControlMode
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    Image(systemName: symbol)
                        .font(.system(size: 40))
                        .foregroundStyle(SMA.accent)
                    Text(headline)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(SMA.labelPrimary)
                        .multilineTextAlignment(.center)
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(SMA.labelSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                VStack(spacing: 0) {
                    ForEach(Array(details.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider().overlay(SMA.separator) }
                        LabeledContent(row.0, value: row.1)
                            .foregroundStyle(SMA.labelPrimary)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                    }
                }
                .background(SMA.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                if mode == .hold || mode == .vacation {
                    Button("Resume Schedule") {
                        model.resumeSchedule()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(SMA.accent)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(title)
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var headline: String {
        switch mode {
        case .hold:     "Temporary Hold"
        case .activity: "Running \(model.activeProfile.name)"
        case .vacation: "Vacation Hold"
        case .schedule: "Following Your Schedule"
        case .standard: "Manual Control"
        }
    }

    private var summary: String {
        switch mode {
        case .hold:     "You've adjusted the temperature, overriding the schedule until the next change."
        case .activity: "This activity profile is setting your comfort range."
        case .vacation: "Holding an energy-saving range while you're away."
        case .schedule: "Your thermostat is following the \(model.device.scheduleName) schedule."
        case .standard: "The schedule is off. Your set temperatures hold until you change them."
        }
    }

    private var details: [(String, String)] {
        let keep = "\(model.device.keepMin)° – \(model.device.keepMax)°"
        switch mode {
        case .hold:
            return [("Holding Range", keep), ("Until", model.device.holdUntil)]
        case .activity:
            let p = model.activeProfile
            return [("Profile", p.name), ("Heat To", "\(p.heatTo)°"), ("Cool To", "\(p.coolTo)°")]
        case .vacation:
            return [("Range", keep), ("Resumes", "When you return")]
        case .schedule:
            let next = model.upcomingPeriods.first
            return [("Schedule", model.device.scheduleName),
                    ("Current Range", keep),
                    ("Up Next", next.map { "\($0.name) · \($0.startText)" } ?? "—")]
        case .standard:
            return [("Range", keep)]
        }
    }

    private var title: String {
        switch mode {
        case .hold:     "Hold"
        case .activity: "Activity Profile"
        case .vacation: "Vacation"
        case .schedule: "Schedule"
        case .standard: "Controller"
        }
    }

    private var symbol: String {
        switch mode {
        case .hold:     "hand.raised.fill"
        case .activity: "person.2.fill"
        case .vacation: "airplane"
        case .schedule: "calendar"
        case .standard: "thermostat.medium"
        }
    }
}

#Preview {
    NavigationStack {
        ControlView()
    }
    .environment(AppModel())
}
