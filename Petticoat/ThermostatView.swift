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

            SetpointControllerCard(
                holdLabel: "Hold\n(1 Hour)",
                low: device.keepMin,
                high: device.keepMax,
                onAdjust: { bound, delta in model.adjustKeep(bound, by: delta) }
            )

            Text("Until \(device.holdUntil)")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
                .padding(.top, 10)
                .padding(.bottom, 4)
        }
        .padding(.horizontal, 20)
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
            ? AnyLayout(HStackLayout(spacing: 4))
            : AnyLayout(VStackLayout(spacing: 4))

        Button(action: action) {
            layout {
                SystemModeIcon(mode: systemMode)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(SMA.card))

                Image(systemName: "fanblades.fill")
                    .foregroundStyle(fanMode == .on ? SMA.accent : SMA.labelSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .font(.footnote)
            .padding(4)
            .background(SMA.fillTertiary, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setpoint controller (full-width, glass — used on the Control tab)

struct SetpointControllerCard: View {
    let holdLabel: String
    let low: Int
    let high: Int
    let onAdjust: (SetpointBound, Int) -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(holdLabel)
                .font(.footnote.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(SMA.destructive)
                .frame(width: 78, height: 56)
                .background(SMA.destructive.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Spacer(minLength: 8)

            SetpointStepper(low: low, high: high, onAdjust: onAdjust)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 24))
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

            VStack(spacing: 16) {
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
                .frame(width: 32, height: 28)
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

#Preview {
    NavigationStack {
        ControlView()
    }
    .environment(AppModel())
}
