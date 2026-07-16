import SwiftUI

/// Bottom sheet for adjusting system mode, fan mode, and circulation.
/// Presented by tapping the mode pill on the Control tab / dashboard card.
struct ModeSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        SheetSectionHeader("System")
                        SystemModeSelector(selected: $model.device.systemMode)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        SheetSectionHeader("Fan")
                        FanModeSelector(selected: $model.device.fanMode)
                    }
                    CirculateCard(
                        circulate: $model.device.circulateFan,
                        amount: $model.device.circulateAmount
                    )
                }
                .padding(20)
            }
        }
        .background(SMA.groupedBackground.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

private struct SheetSectionHeader: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(SMA.labelSecondary)
    }
}

// MARK: - System mode

struct SystemModeSelector: View {
    @Binding var selected: SystemMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SystemMode.allCases) { mode in
                Button { selected = mode } label: {
                    VStack(spacing: 6) {
                        SystemModeIcon(mode: mode)
                            .font(.footnote)
                        Text(mode.label)
                            .font(.caption2)
                            .foregroundStyle(SMA.labelPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background {
                        if selected == mode {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SMA.card)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SMA.fillTertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: selected)
    }
}

/// Icon(s) representing a system mode. Shared by the selector and the mode pill.
struct SystemModeIcon: View {
    let mode: SystemMode

    var body: some View {
        switch mode {
        case .cool:
            Image(systemName: "snowflake").foregroundStyle(SMA.accent)
        case .heat:
            Image(systemName: "flame.fill").foregroundStyle(SMA.tempOrange)
        case .auxHeat:
            Image(systemName: "flame.fill").foregroundStyle(SMA.destructive)
        case .auto:
            HStack(spacing: 2) {
                Image(systemName: "snowflake").foregroundStyle(SMA.accent)
                Image(systemName: "flame.fill").foregroundStyle(SMA.tempOrange)
            }
        case .off:
            Image(systemName: "stop.circle.fill").foregroundStyle(SMA.labelPrimary)
        }
    }
}

// MARK: - Fan mode

struct FanModeSelector: View {
    @Binding var selected: FanMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(FanMode.allCases) { mode in
                Button { selected = mode } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "fanblades.fill")
                            .foregroundStyle(selected == mode ? SMA.accent : SMA.labelSecondary)
                        Text(mode.label)
                            .font(.caption2)
                            .foregroundStyle(SMA.labelPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background {
                        if selected == mode {
                            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(SMA.card)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(SMA.fillTertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.snappy, value: selected)
    }
}

// MARK: - Circulate

struct CirculateCard: View {
    @Binding var circulate: Bool
    @Binding var amount: String
    @State private var showWheel = false

    private let options = ["17% (10min)", "33% (15min)", "50% (20min)", "67% (25min)"]

    var body: some View {
        VStack(spacing: 0) {
            Toggle("Circulate Fan", isOn: $circulate)
                .tint(Color(hex: 0x34C759))
                .foregroundStyle(SMA.labelPrimary)
                .padding(16)

            Divider().overlay(SMA.separator).padding(.leading, 16)

            Button {
                withAnimation(.snappy) { showWheel.toggle() }
            } label: {
                HStack {
                    Text("Amount Per Hour")
                        .foregroundStyle(SMA.labelPrimary)
                    Spacer()
                    Text(amount)
                        .font(.subheadline)
                        .foregroundStyle(SMA.labelPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(SMA.fillTertiary, in: Capsule())
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            .disabled(!circulate)

            if showWheel {
                Picker("Amount Per Hour", selection: $amount) {
                    ForEach(options, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)
            }
        }
        .cardStyle()
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        ModeSheet().environment(AppModel())
    }
}
