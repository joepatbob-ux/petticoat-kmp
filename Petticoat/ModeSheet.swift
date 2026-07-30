import SwiftUI

/// Bottom sheet for adjusting system mode, fan mode, and circulation.
/// Presented by tapping the mode pill on the Control tab / dashboard card.
struct ModeSheet: View {
    /// The device whose settings are being edited. Passed explicitly so the sheet
    /// binds directly to a device by ID — no call to `selectDevice` needed, which
    /// avoids the model cascade that dismissed the sheet on first open.
    let deviceID: Device.ID

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showWheel = false
    private let circulateOptions = ["17% (10min)", "33% (15min)", "50% (20min)", "67% (25min)"]

    private var device: Device {
        model.devices.first { $0.id == deviceID } ?? model.device
    }

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            List {
                Section("System") {
                    SystemModeSelector(selected: $model[deviceID: deviceID, \.systemMode])
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section("Fan") {
                    FanModeSelector(selected: $model[deviceID: deviceID, \.fanMode])
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                // Fan On runs for a chosen duration — no per-hour amount, unlike Circulate.
                if device.fanMode == .on {
                    Section {
                        DurationPicker(title: "Run For", selection: $model[deviceID: deviceID, \.fanHoldDuration])
                    } footer: {
                        Text(fanRunFooter)
                    }
                    .listRowBackground(SMA.card)
                }

                // Circulation only applies when the fan is on Auto — running the fan
                // On continuously supersedes it, so the settings are hidden then.
                if device.fanMode != .on {
                    Section {
                        Toggle("Circulate Fan", isOn: $model[deviceID: deviceID, \.circulateFan])
                            .tint(Color(hex: 0x34C759))

                        // The amount and duration only apply while circulation is on.
                        if device.circulateFan {
                            Button {
                                withAnimation(.snappy) { showWheel.toggle() }
                            } label: {
                                HStack {
                                    Text("Amount Per Hour")
                                        .foregroundStyle(SMA.labelPrimary)
                                    Spacer()
                                    Text(device.circulateAmount)
                                        .font(.subheadline)
                                        .foregroundStyle(SMA.labelPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(SMA.fillTertiary, in: Capsule())
                                }
                            }
                            .buttonStyle(.plain)

                            if showWheel {
                                Picker("Amount Per Hour", selection: $model[deviceID: deviceID, \.circulateAmount]) {
                                    ForEach(circulateOptions, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 160)
                            }

                            DurationPicker(title: "Run For", selection: $model[deviceID: deviceID, \.circulateHoldDuration])
                        }
                    } footer: {
                        if device.circulateFan {
                            Text(circulateRunFooter)
                        }
                    }
                    .listRowBackground(SMA.card)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .navigationTitle("Mode")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    /// Describes when a timed Fan On run ends (and that it reverts to Auto), or that
    /// it stays on until Auto is reselected for an indefinite run.
    private var fanRunFooter: String {
        if let end = device.fanHoldDuration.endTimeText() {
            return "Fan runs until \(end), then returns to Auto."
        }
        return "Fan stays on until you set it back to Auto."
    }

    /// Describes when circulation stops for a timed run, or that it runs until the
    /// toggle is turned off for an indefinite run.
    private var circulateRunFooter: String {
        if let end = device.circulateHoldDuration.endTimeText() {
            return "Circulates until \(end)."
        }
        return "Circulates until turned off."
    }
}

// MARK: - Duration picker

/// A labeled menu picker for a `HoldDuration` (Indefinite / 1–12 Hours). Shared by
/// the Fan On and Circulate rows in the Mode sheet.
struct DurationPicker: View {
    let title: String
    @Binding var selection: HoldDuration

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(HoldDuration.allCases) { Text($0.label).tag($0) }
        }
        .pickerStyle(.menu)
        .tint(SMA.labelSecondary)
        .foregroundStyle(SMA.labelPrimary)
    }
}

// MARK: - System mode

struct SystemModeSelector: View {
    @Binding var selected: SystemMode

    var body: some View {
        PillSegmentedSelector(items: SystemMode.allCases, selection: $selected, label: \.label) { mode in
            SystemModeIcon(mode: mode, size: 30)
        }
    }
}

/// Icon representing a system mode, rendered from the custom multicolor art.
/// Each asset carries light/dark appearance variants, so no tinting is applied.
/// Shared by the selector and the mode pill.
struct SystemModeIcon: View {
    let mode: SystemMode
    var size: CGFloat = 28

    var body: some View {
        Image(mode.iconName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - Fan mode

struct FanModeSelector: View {
    @Binding var selected: FanMode

    var body: some View {
        PillSegmentedSelector(items: FanMode.allCases, selection: $selected, label: \.label) { mode in
            FanModeIcon(mode: mode, size: 30)
        }
    }
}

/// Icon representing a fan mode, rendered from the custom art (Auto carries an
/// "A" badge). Shared by the selector and the mode pill.
struct FanModeIcon: View {
    let mode: FanMode
    var size: CGFloat = 28

    var body: some View {
        Image(mode.iconName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

#Preview {
    let model = AppModel()
    Color.clear.sheet(isPresented: .constant(true)) {
        ModeSheet(deviceID: model.device.id).environment(model)
    }
}
