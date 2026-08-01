import SwiftUI

/// The light-themed Environmental Control screen — the "Control" tab.
struct ControlView: View {
    @Environment(AppModel.self) private var model

    @State private var showMode = false
    @State private var showSensors = false

    private var device: Device { model.device }

    var body: some View {
        if device.isOffline {
            ThermostatOfflineDetail()
        } else {
            onlineBody
        }
    }

    @ViewBuilder private var onlineBody: some View {
        VStack(spacing: 0) {
            WeatherSummary(
                location: model.showWeatherLocation ? device.location : "",
                temp: model.tempUnit.format(device.outdoorTemp),
                high: model.tempUnit.format(device.outdoorHigh),
                low: model.tempUnit.format(device.outdoorLow)
            )
            .padding(.top, 8)

            Button { showSensors = true } label: {
                SensorAveragePill(summary: device.sensorSummary)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("sensorAveragePill")
            .accessibilityLabel("Sensors")
            .accessibilityHint("Opens the sensors screen")
            .padding(.top, 20)

            Spacer().frame(maxHeight: 80)

            DisplayTemp(value: model.tempUnit.convert(device.currentTemp), size: 170, activity: device.activity)

            HumidityLabel(humidity: device.humidity)

            Spacer()
                .frame(maxHeight: 40)

            ModeSelectPill(systemMode: device.systemMode, fanMode: device.fanMode) {
                showMode = true
            }
            .padding(.top, 20)
            .padding(.bottom, 36)

            ControllerSection()
                .padding(.bottom, 36)
        }
        .padding(.horizontal, 20)
        .readableWidth()
        .scrollableWhenNeeded()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SMA.groupedBackground.ignoresSafeArea())
        // Keep the editable current-period setpoints in step with the running schedule,
        // so the card matches the saved schedule on appear and across period changes.
        .task(id: model.currentPeriod?.id) { model.syncScheduleSetpoints() }
        .sheet(isPresented: $showMode) {
            ModeSheet(deviceID: device.id)
        }
        .sheet(isPresented: $showSensors) {
            NavigationStack { SensorsView() }
        }
    }
}

// MARK: - Weather

struct WeatherSummary: View {
    let location: String
    let temp: String
    let high: String
    let low: String

    var body: some View {
        VStack(spacing: 6) {
            if !location.isEmpty {
                Text(location)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelPrimary)
            }
            HStack(spacing: 12) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(SMA.labelPrimary)
                    .accessibilityHidden(true)
                Text(temp)
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
                .accessibilityHidden(true)
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
            .padding(.horizontal, axis == .horizontal ? 16 : 12)
            .padding(.vertical, axis == .horizontal ? 10 : 14)
            .background(SMA.fillTertiary, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mode: \(systemMode.label), fan: \(fanMode.label)")
        .accessibilityHint("Opens mode settings")
    }

    /// Short divider between the system and fan icons — orientation follows the axis.
    private var separator: some View {
        Capsule()
            .fill(SMA.labelSecondary.opacity(0.35))
            .frame(
                width: axis == .horizontal ? 1 : 18,
                height: axis == .horizontal ? 18 : 1
            )
            .accessibilityHidden(true)
    }
}

/// The reusable setpoint display + steppers. The numbers never move: at rest they
/// sit bare with the mode label ("Keep Between" / "Heat To" / "Cool To") floating
/// above; once the user adjusts, a selection capsule *forms around* the same numbers
/// so a bound can be picked, and it fades back out after a moment of inactivity. A
/// "Limit" caption appears below when the picked bound hits its travel limit.
/// Shared by the Control tab and the dashboard thermostat card.
struct SetpointStepper: View {
    let low: Int
    let high: Int
    var mode: SystemMode = .auto
    /// Whether to float the mode label above the numbers at rest. On the control
    /// screen this is reserved for profile-driven cards.
    var showsLabel: Bool = false
    /// Vertical gap between the +/− (or ▲/▼) buttons. Defaults to the dashboard
    /// card's spacing; the roomier Control-screen cards pass a tighter value.
    var buttonSpacing: CGFloat = 24
    let onAdjust: (SetpointBound, Int) -> Void

    @Environment(AppModel.self) private var model

    /// Non-nil while the user is actively adjusting — drives the selection capsule.
    @State private var editing: SetpointBound?
    /// The most recently adjusted bound. Outlives `editing` so the "Limit" caption
    /// can persist after the selection capsule fades out.
    @State private var lastAdjusted: SetpointBound?
    /// Bumped on every interaction to restart the inactivity fade-out.
    @State private var activity = 0

    /// Heat targets the low bound, Cool the high; Auto edits either.
    private var defaultBound: SetpointBound { mode == .cool ? .high : .low }

    var body: some View {
        HStack(spacing: 18) {
            // The digits are the only laid-out element, so they stay vertically
            // centered; the label and limit float above/below without moving them.
            numbers
                .overlay(alignment: .top) {
                    Text(mode.setpointLabel)
                        .font(.caption2)
                        .foregroundStyle(SMA.labelSecondary)
                        .fixedSize()
                        .opacity(showsLabel && editing == nil && !atLimit ? 1 : 0)
                        .offset(y: -4)
                }
                .overlay(alignment: .bottom) {
                    Text("Limit")
                        .font(.caption2)
                        .foregroundStyle(SMA.labelSecondary)
                        .fixedSize()
                        .opacity(atLimit ? 1 : 0)
                        .offset(y: 14)
                        .accessibilityHidden(!atLimit)
                }
            VStack(spacing: buttonSpacing) {
                stepper(model.stepperStyle.upSymbol(), delta: 1)
                stepper(model.stepperStyle.downSymbol(), delta: -1)
            }
            .padding(.trailing, -8)
        }
        .animation(.snappy, value: editing)
        // Restarts whenever `activity` changes; clears the selection after a pause.
        .task(id: activity) {
            guard editing != nil else { return }
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) { editing = nil }
        }
    }

    // MARK: Numbers

    @ViewBuilder private var numbers: some View {
        if mode.isRangeSetpoint {
            if model.tempUnit == .celsius {
                // Stacked layout for Celsius: decimal values are wider and stack more
                // comfortably than sitting side-by-side in the horizontal layout. The
                // dot sits between the rows, mirroring the Fahrenheit separator.
                VStack(spacing: 0) {
                    segment(value: low, bound: .low, verticalPadding: 4)
                    separator(.vertical)
                    segment(value: high, bound: .high, verticalPadding: 4)
                }
                // A rounded rect rather than a Capsule: the stack is tall enough that
                // a full capsule bulges into an oval around the numbers.
                .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .onTapGesture { flip() }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background {
                    if editing != nil {
                        RoundedRectangle(cornerRadius: 22, style: .continuous).fill(SMA.fillTertiary)
                    }
                }
            } else {
                HStack(spacing: 0) {
                    segment(value: low, bound: .low)
                    separator(.horizontal)
                    segment(value: high, bound: .high)
                }
                // Binary selection: a tap anywhere flips to the other bound.
                .contentShape(Capsule())
                .onTapGesture { flip() }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background { if editing != nil { Capsule().fill(SMA.fillTertiary) } }
            }
        } else {
            // Single-setpoint modes (Heat/Cool/AuxHeat) — no grouping container.
            segment(value: mode == .cool ? high : low, bound: defaultBound, showsBackground: false)
                .contentShape(Rectangle())
                .onTapGesture { select(defaultBound) }
        }
    }

    /// A constant-size gap between the digits: the dot at rest, an equal-size blank
    /// while editing — so the digits never shift when the dot appears/vanishes. The
    /// gap runs along the layout axis (horizontal for Fahrenheit, vertical for the
    /// stacked Celsius numbers).
    private func separator(_ axis: Axis) -> some View {
        Image(systemName: "circle.fill")
            .font(.system(size: 4))
            .foregroundStyle(SMA.labelSecondary)
            .frame(width: axis == .horizontal ? 12 : nil,
                   height: axis == .vertical ? 4 : nil)
            .opacity(editing == nil ? 1 : 0)
            .accessibilityHidden(true)
    }

    private func segment(value: Int, bound: SetpointBound, showsBackground: Bool = true, verticalPadding: CGFloat = 8) -> some View {
        let selected = editing == bound
        return Text(segmentText(value))
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(editing == nil || selected ? SMA.labelPrimary : SMA.labelSecondary)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 12)
            .padding(.vertical, verticalPadding)
            .background { if selected && showsBackground { Capsule().fill(SMA.card) } }
            .accessibilityAddTraits(selected ? [.isSelected] : [])
            .accessibilityLabel(bound == .low ? "Heat setpoint" : "Cool setpoint")
    }

    /// Always formats Celsius to one decimal place so the text width is stable
    /// across whole-degree and half-degree values (e.g. "22.0" not "22").
    private func segmentText(_ fahrenheit: Int) -> String {
        guard model.tempUnit == .celsius else { return model.tempUnit.format(fahrenheit) }
        return String(format: "%.1f", model.tempUnit.convert(fahrenheit))
    }

    /// Whether the relevant bound can no longer move in either direction. Uses the
    /// live selection while editing, falling back to the last-adjusted bound so the
    /// caption survives the selection capsule fading out.
    private var atLimit: Bool {
        guard let bound = editing ?? lastAdjusted else { return false }
        switch bound {
        case .low:  return low <= SetpointConfig.minTemp || low >= SetpointConfig.maxTemp - SetpointConfig.deadband
        case .high: return high >= SetpointConfig.maxTemp || high <= SetpointConfig.minTemp + SetpointConfig.deadband
        }
    }

    // MARK: Interaction

    private func select(_ bound: SetpointBound) {
        withAnimation(.snappy) { editing = bound }
        activity += 1
    }

    /// Starts editing (at the default bound) or, once editing, flips to the other.
    private func flip() {
        let target: SetpointBound = editing == nil ? defaultBound : (editing == .low ? .high : .low)
        withAnimation(.snappy) { editing = target }
        activity += 1
    }

    private func stepper(_ symbol: String, delta: Int) -> some View {
        Button {
            let bound = editing ?? defaultBound
            withAnimation(.snappy) { editing = bound }
            lastAdjusted = bound
            activity += 1
            onAdjust(bound, delta)
        } label: {
            Image(systemName: symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)
                .frame(width: 44, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(delta > 0 ? "Increase temperature" : "Decrease temperature")
    }
}

// MARK: - Mode-aware controller

/// Shared metrics for the controller's leading boxes so the preset switcher and the
/// hold button always match, whichever mode is showing.
private enum ControllerMetrics {
    static let boxWidth: CGFloat = 92
}

/// The active profile's icon + title, shown as a tappable chip on the schedule
/// current-period card and the activity single card. Opens the status sheet.
private struct ProfileChip: View {
    let symbol: String
    let colorHex: UInt
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                ProfileIcon(symbol: symbol, colorHex: colorHex, size: 30)
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelPrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

/// The schedule pager: the current-period card (editable) followed by read-only
/// upcoming-period previews, with a footer + page dots. Owns its own `page` scroll
/// state so scrolling churn stays inside this view instead of re-running the whole
/// `ControllerSection`. Shown for both `.schedule` and `.hold`.
private struct ScheduleControllerView: View {
    @Environment(AppModel.self) private var model
    @Binding var showStatus: Bool
    @State private var page: Int? = 0

    private var device: Device { model.device }
    private var pageCount: Int { model.upcomingPeriods.count + 1 }

    var body: some View {
        VStack(spacing: 10) {
            Text("Schedule: \(model.scheduleName)")
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
                            PeriodCard(period: period, usePresets: device.usePresets).frame(width: cardWidth).id(index + 1)
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
                if model.controlMode == .hold {
                    HStack(spacing: 4) {
                        if device.geofenceEnabled {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .accessibilityHidden(true)
                        }
                        Text("Until \(model.holdUntilText)")
                    }
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
                } else {
                    scheduleFooter
                }
                Spacer()
                PageDots(count: pageCount, current: page ?? 0)
            }
            .padding(.horizontal, 16)
        }
        .animation(.snappy, value: page)
    }

    /// Current period — editable setpoint. In hold mode the hold button overlays the
    /// leading edge; otherwise the leading shows the active preset's icon + title (when
    /// Use Presets is on) or the setpoint label.
    private var currentPeriodCard: some View {
        HStack(spacing: 14) {
            currentPeriodLeading
            Spacer(minLength: 8)
            SetpointStepper(low: device.keepMin, high: device.keepMax,
                            mode: device.systemMode,
                            showsLabel: device.usePresets || model.controlMode == .hold,
                            buttonSpacing: 10) { bound, delta in
                model.adjustKeep(bound, by: delta)
            }
        }
        .frame(minHeight: 64)
        .controllerCard()
        .overlay {
            if model.controlMode == .hold {
                HStack(spacing: 0) {
                    holdButton
                    Spacer()
                }
                .padding(4)
            }
        }
    }

    /// Leading element of the current-period card: the profile chip on a profile
    /// schedule, the setpoint label otherwise. Hold overlays its own box, so the inline
    /// leading is empty there.
    @ViewBuilder private var currentPeriodLeading: some View {
        if model.controlMode == .hold {
            EmptyView()
        } else if device.usePresets {
            let period = model.currentPeriod
            ProfileChip(symbol: period?.symbol ?? model.activeProfile.symbol,
                        colorHex: period?.colorHex ?? model.activeProfile.colorHex,
                        name: period?.name ?? model.activeProfile.name) { showStatus = true }
        } else {
            Text(device.systemMode.setpointLabel)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(SMA.labelSecondary)
        }
    }

    /// The temporary-hold button box that overlays the current period card's leading
    /// edge while in hold mode.
    private var holdButton: some View {
        Button { showStatus = true } label: {
            VStack(spacing: 3) {
                Image(systemName: "hand.raised.fill")
                    .font(.body.weight(.semibold))
                Text("Hold\n(\(model.holdDuration.label))")
                    .font(.caption2.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(SMA.destructive)
        }
        .buttonStyle(.plain)
        .frame(width: ControllerMetrics.boxWidth)
        .frame(maxHeight: .infinity)
        .background(SMA.destructive.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var scheduleFooter: some View {
        let index = page ?? 0
        let periods = model.upcomingPeriods
        // `index` tracks scroll position (0 = current period); guard the upcoming
        // subscript so a stale/settling page can never read out of range.
        let isCurrent = !(index >= 1 && index - 1 < periods.count)
        let text: String
        if isCurrent {
            text = "Until \(periods.first?.startText ?? device.holdUntil)"
        } else {
            text = periods[index - 1].startText
        }
        return HStack(spacing: 4) {
            // On the current-period line, the pin signals that auto home/away can end
            // the period early — matching the dashboard card and the hold footer.
            if isCurrent && device.geofenceEnabled {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            Text(text)
        }
        .font(.footnote)
        .foregroundStyle(SMA.labelSecondary)
    }
}

/// The bottom controller section. Renders per `ControlMode`. In schedule mode it is a
/// horizontally swipeable pager of period controllers — only the current period is
/// editable; upcoming periods are read-only previews. The status control opens a
/// placeholder sheet.
struct ControllerSection: View {
    @Environment(AppModel.self) private var model
    @State private var showStatus = false
    @State private var creatingProfile = false

    private var device: Device { model.device }

    /// Whether the non-schedule card shows the preset switcher: Use Presets is on
    /// and we're not running a schedule.
    private var showsPresetBox: Bool {
        device.usePresets && (model.controlMode == .standard || model.controlMode == .activity)
    }

    var body: some View {
        Group {
            if device.systemMode == .off {
                // Nothing to control while the system is off — no setpoint card.
                EmptyView()
            } else if model.controlMode == .schedule || model.controlMode == .hold {
                ScheduleControllerView(showStatus: $showStatus)
            } else {
                VStack(spacing: 10) {
                    singleCard
                    // Reserve one footnote line for the footer so the card stays put
                    // whether or not the current mode has a footer (a blank space
                    // holds the line and scales with Dynamic Type).
                    Text(" ")
                        .font(.footnote)
                        .overlay { footer }
                }
            }
        }
        .sheet(isPresented: $showStatus) { ControllerStatusSheet(mode: model.controlMode) }
        .sheet(isPresented: $creatingProfile) {
            EditActivityProfileView(profile: .new) { newProfile in
                model.saveProfile(newProfile)
                model.activateProfile(newProfile)
            }
        }
    }

    // MARK: Non-schedule single card

    private var singleCard: some View {
        HStack(spacing: 14) {
            // The preset box overlays the leading edge (like the hold box), so the
            // inline slot is empty while it's shown.
            if !showsPresetBox { leading }
            Spacer(minLength: 8)
            SetpointStepper(low: device.keepMin, high: device.keepMax,
                            mode: device.systemMode,
                            showsLabel: model.controlMode == .activity || showsPresetBox,
                            buttonSpacing: 10) { bound, delta in
                model.adjustKeep(bound, by: delta)
            }
        }
        .frame(minHeight: 64)
        .controllerCard()
        .overlay {
            if showsPresetBox {
                HStack { presetMenu; Spacer() }
                    .padding(4)
            }
        }
    }

    // MARK: Preset switcher

    /// The preset switcher: a button box tinted with a muted version of the active
    /// preset's color, shown on the single controller card when Use Presets is on and
    /// no schedule is running. Sized to match the hold action box — same width, and it
    /// fills the card height so it hugs the top/bottom/leading edges. The menu switches
    /// presets (entering activity mode) and offers "Create New Profile".
    private var presetMenu: some View {
        let color = Color(hex: model.activeProfile.colorHex)
        return Menu {
            ForEach(model.activityProfiles) { profile in
                Button {
                    model.activateProfile(profile)
                } label: {
                    Label(profile.name, systemImage: profile.symbol)
                }
            }
            Divider()
            Button {
                creatingProfile = true
            } label: {
                Label("Create New Profile", systemImage: "plus")
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: model.activeProfile.symbol)
                    .font(.body.weight(.semibold))
                Text(model.activeProfile.name)
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(color)
            // Fill the box so its tap target and background stretch edge to edge,
            // like the hold button (a Menu label won't stretch on its own).
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        // Sizing + background live on the Menu itself, mirroring the hold Button, so
        // the box fills the card height rather than hugging its content.
        .frame(width: ControllerMetrics.boxWidth)
        .frame(maxHeight: .infinity)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .accessibilityLabel("Preset: \(model.activeProfile.name)")
        .accessibilityHint("Switches the active preset")
    }

    // MARK: Leading element (single-card modes)

    @ViewBuilder private var leading: some View {
        switch model.controlMode {
        case .standard:
            if showsPresetBox {
                presetMenu
            } else {
                Text(device.systemMode.setpointLabel)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelSecondary)
            }

        case .hold:
            EmptyView()

        case .activity:
            if showsPresetBox {
                presetMenu
            } else {
                ProfileChip(symbol: model.activeProfile.symbol,
                            colorHex: model.activeProfile.colorHex,
                            name: model.activeProfile.name) { showStatus = true }
            }

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
        case .hold:
            HStack(spacing: 4) {
                if device.geofenceEnabled {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .accessibilityHidden(true)
                }
                Text("Until \(device.holdUntil)")
            }
            .font(.footnote)
            .foregroundStyle(SMA.labelSecondary)
        case .activity:
            untilLabel(device.holdUntil)
        case .vacation:
            Text("Until your vacation ends")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
        }
    }

    private func untilLabel(_ text: String) -> some View {
        Text("Until \(text)")
            .font(.footnote)
            .foregroundStyle(SMA.labelSecondary)
    }
}

/// Upcoming schedule period — a read-only preview card (no setpoint control).
private struct PeriodCard: View {
    @Environment(AppModel.self) private var model
    let period: TimelinePeriod
    /// On a profile schedule every period leads with its profile icon + title, matching
    /// the current-period card; otherwise it shows the period name alone.
    var usePresets: Bool

    var body: some View {
        HStack(spacing: 14) {
            if usePresets {
                HStack(spacing: 8) {
                    ProfileIcon(symbol: period.symbol, colorHex: period.colorHex, size: 30)
                    Text(period.name)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.labelPrimary)
                }
            } else {
                Text(period.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelSecondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text(model.tempUnit.format(period.heatTo))
                Image(systemName: "circle.fill").font(.system(size: 4))
                    .accessibilityHidden(true)
                Text(model.tempUnit.format(period.coolTo))
            }
            .font(.title3.weight(.semibold))
            .foregroundStyle(SMA.labelSecondary)
            .monospacedDigit()
        }
        .frame(minHeight: 64)
        .controllerCard()
    }
}

/// The page indicator beneath the schedule pager: a widened capsule marks the
/// current page. Depends only on its inputs, not the whole controller state.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? SMA.labelSecondary : SMA.fillTertiary)
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page")
        .accessibilityValue("\(current + 1) of \(count)")
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
        @Bindable var model = model
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: symbol)
                            .font(.system(size: 40))
                            .foregroundStyle(SMA.accent)
                            .accessibilityHidden(true)
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
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section {
                    if mode == .hold {
                        // The hold sheet only needs the duration control — the range and
                        // end time are already shown on the controller card.
                        Picker("Hold For", selection: Binding(
                            get: { model.holdDuration },
                            set: model.setHoldDuration
                        )) {
                            ForEach(HoldDuration.allCases) { Text($0.label).tag($0) }
                        }
                    } else {
                        ForEach(Array(details.enumerated()), id: \.offset) { _, row in
                            LabeledContent(row.0, value: row.1)
                        }
                    }
                }
                .listRowBackground(SMA.card)

                // The resume/end action lives in the form as a native row.
                if mode == .hold || mode == .vacation {
                    Section {
                        Button(role: mode == .hold ? .destructive : nil) {
                            model.resumeSchedule()
                            dismiss()
                        } label: {
                            Text(mode == .hold ? "End Hold" : "Resume Schedule")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .foregroundStyle(mode == .hold ? SMA.destructive : SMA.accent)
                    }
                    .listRowBackground(SMA.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle(title)
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
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
        case .hold:     "You've adjusted the temperature, overriding the schedule until \(model.holdUntilText)."
        case .activity: "This activity profile is setting your comfort range."
        case .vacation: "Holding an energy-saving range while you're away."
        case .schedule: "Your thermostat is following the \(model.scheduleName) schedule."
        case .standard: "The schedule is off. Your set temperatures hold until you change them."
        }
    }

    private var details: [(String, String)] {
        let keep = "\(model.device.keepMin)° – \(model.device.keepMax)°"
        switch mode {
        case .hold:
            return [("Holding Range", keep), ("Until", model.holdUntilText)]
        case .activity:
            let p = model.activeProfile
            return [("Profile", p.name), ("Heat To", "\(p.heatTo)°"), ("Cool To", "\(p.coolTo)°")]
        case .vacation:
            return [("Range", keep), ("Resumes", "When you return")]
        case .schedule:
            let next = model.upcomingPeriods.first
            return [("Schedule", model.device.scheduleName),
                    ("Current Range", keep),
                    // Program periods have no profile name (name == start time), so avoid
                    // printing the time twice.
                    ("Up Next", next.map { $0.name == $0.startText ? $0.startText : "\($0.name) · \($0.startText)" } ?? "—")]
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
