import SwiftUI

/// Bottom sheet for adjusting system mode, fan mode, and circulation.
/// Presented by tapping the mode pill on the Control tab / dashboard card.
struct ModeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var showWheel = false
    private let circulateOptions = ["17% (10min)", "33% (15min)", "50% (20min)", "67% (25min)"]

    var body: some View {
        @Bindable var model = model
        VStack(spacing: 0) {
            HStack {
                Text("Mode")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(SMA.labelPrimary)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SMA.labelSecondary)
                        .padding(8)
                        .background(SMA.fillTertiary, in: Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)

            List {
                Section("System") {
                    SystemModeSelector(selected: $model.device.systemMode)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section("Fan") {
                    FanModeSelector(selected: $model.device.fanMode)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                }

                Section {
                    Toggle("Circulate Fan", isOn: $model.device.circulateFan)
                        .tint(Color(hex: 0x34C759))

                    Button {
                        withAnimation(.snappy) { showWheel.toggle() }
                    } label: {
                        HStack {
                            Text("Amount Per Hour")
                                .foregroundStyle(SMA.labelPrimary)
                            Spacer()
                            Text(model.device.circulateAmount)
                                .font(.subheadline)
                                .foregroundStyle(SMA.labelPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(SMA.fillTertiary, in: Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.device.circulateFan)

                    if showWheel {
                        Picker("Amount Per Hour", selection: $model.device.circulateAmount) {
                            ForEach(circulateOptions, id: \.self) { Text($0).tag($0) }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 160)
                    }
                }
                .listRowBackground(SMA.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .foregroundStyle(SMA.labelPrimary)
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
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
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ModeSheet().environment(AppModel())
    }
}
