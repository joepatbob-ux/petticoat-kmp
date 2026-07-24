import SwiftUI

// MARK: - Shared chrome

/// The shared bottom action bar: optional help link, optional secondary button,
/// and a primary button that can be gated with `primaryEnabled`.
struct InstallButtonBar: View {
    var link: String? = nil
    var onLink: () -> Void = {}
    var secondary: String? = nil
    var onSecondary: () -> Void = {}
    var primary: String
    var primaryEnabled: Bool = true
    var onPrimary: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let link {
                Button(link) { onLink() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SMA.accent)
            }
            if let secondary {
                Button { onSecondary() } label: {
                    Text(secondary).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .tint(SMA.accent)
            }
            Button { onPrimary() } label: {
                Text(primary).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(SMA.accent)
            .disabled(!primaryEnabled)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// Centered caution pill (optional) + title + body (optional), shared by the
/// standard and Connect the Wires steps.
struct StepHeadline: View {
    let title: String
    var detail: String? = nil
    var warning: String? = nil

    var body: some View {
        VStack(spacing: 12) {
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(SMA.tempOrange)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(SMA.tempOrange.opacity(0.12), in: Capsule())
            }
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(SMA.labelSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
    }
}

// MARK: - Select Wi-Fi

struct WifiListContent: View {
    let step: InstallStep
    let onAdvance: () -> Void
    @State private var selected: String?

    private let networks: [(name: String, locked: Bool)] = [
        ("Family WiFi", true), ("House Internet", false), ("Net 1", true), ("Net 2", false),
    ]

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section("Networks") {
                    ForEach(networks, id: \.name) { net in
                        Button { selected = net.name } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selected == net.name ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(selected == net.name ? SMA.accent : SMA.labelSecondary)
                                Text(net.name).foregroundStyle(SMA.labelPrimary)
                                Spacer()
                                if net.locked {
                                    Image(systemName: "lock.fill")
                                        .font(.footnote)
                                        .foregroundStyle(SMA.labelSecondary)
                                        .accessibilityLabel("Secured")
                                }
                                Image(systemName: "wifi").foregroundStyle(SMA.labelSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected == net.name ? [.isSelected] : [])
                    }
                }
                Section {
                    Button("Other Network") {}.foregroundStyle(SMA.accent)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)

            InstallButtonBar(secondary: "Scan Again", onSecondary: { selected = nil },
                             primary: "Continue", primaryEnabled: selected != nil, onPrimary: onAdvance)
        }
        .background(SMA.groupedBackground)
    }
}

// MARK: - Enter Security Code

struct PinContent: View {
    let step: InstallStep
    let onAdvance: () -> Void
    @State private var code = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(step.hero)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    TextField("Security Code", text: $code)
                        .textFieldStyle(.plain)
                        .padding()
                        .background(SMA.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)

                    if let body = step.body {
                        Text(body)
                            .font(.footnote)
                            .foregroundStyle(SMA.labelSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.bottom, 16)
            }

            InstallButtonBar(primary: "Continue",
                             primaryEnabled: !code.trimmingCharacters(in: .whitespaces).isEmpty,
                             onPrimary: onAdvance)
        }
    }
}

// MARK: - Configuring (loading)

struct LoadingContent: View {
    let step: InstallStep
    let onAdvance: () -> Void
    @State private var animate = false

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle().fill(SMA.accent.opacity(0.15)).frame(width: 120, height: 120)
                    .scaleEffect(animate ? 1.1 : 0.75)
                Circle().fill(SMA.accent.opacity(0.3)).frame(width: 72, height: 72)
                    .scaleEffect(animate ? 1.15 : 0.85)
                Circle().fill(SMA.accent).frame(width: 26, height: 26)
            }
            .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)

            VStack(spacing: 8) {
                Text(step.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(SMA.labelPrimary)
                    .multilineTextAlignment(.center)
                if let body = step.body {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(SMA.labelSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { animate = true }
        .task {
            try? await Task.sleep(for: .seconds(2.5))
            onAdvance()
        }
    }
}

// MARK: - Enter Location (form)

struct FormContent: View {
    let step: InstallStep
    let onAdvance: () -> Void
    @State private var address1 = ""
    @State private var address2 = ""
    @State private var zip = ""
    @State private var city = ""
    @State private var state = ""
    @State private var country = ""

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section(step.title) {
                    TextField("Address 1", text: $address1)
                    TextField("Address 2 (Optional)", text: $address2)
                    TextField("Zipcode", text: $zip)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("Country", text: $country)
                }
                Section {
                    LabeledContent("Timezone", value: "Americas/Chicago")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .listRowBackground(SMA.card)

            InstallButtonBar(secondary: "Locate Me", onSecondary: fillSampleAddress,
                             primary: "Continue", onPrimary: onAdvance)
        }
        .background(SMA.groupedBackground)
    }

    private func fillSampleAddress() {
        address1 = "123 Main St"
        zip = "63101"
        city = "St. Louis"
        state = "MO"
        country = "USA"
    }
}

// MARK: - Wire configuration data

/// Loads and caches the valid wire configurations bundled per device. Each line of
/// the resource is a comma-separated, sorted terminal set (one valid config).
final class WireConfigStore {
    static let shared = WireConfigStore()
    private var cache: [String: [Set<String>]] = [:]

    func configs(resource: String) -> [Set<String>] {
        if let cached = cache[resource] { return cached }
        var sets: [Set<String>] = []
        if let url = Bundle.main.url(forResource: resource, withExtension: "txt"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            sets = text.split(whereSeparator: \.isNewline).map { line in
                Set(line.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
            }
        }
        cache[resource] = sets
        return sets
    }
}

// MARK: - Wire Picker

/// Terminal selector whose validity is driven entirely by the device's enumerated
/// valid configurations: a terminal disables when no valid config could still
/// contain it given the current selection, and Continue enables only when the
/// selection exactly matches a valid configuration.
struct WirePickerContent: View {
    let step: InstallStep
    let configResource: String?
    @Binding var selection: Set<String>
    let onHelp: () -> Void
    let onAdvance: () -> Void

    /// 4-column layout matching the design (the "Other" catch-all is omitted since
    /// it never appears in a valid configuration). Shared so the Connect the Wires
    /// diagram can present the selection in the same canonical order.
    static let terminalOrder = ["R", "W", "Y", "G", "RH", "W1", "Y1", "O", "RC", "W/E",
                                "Y2", "B", "C", "W2", "L", "O/B", "X", "E", "AUX"]
    private var terminals: [String] { WirePickerContent.terminalOrder }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    private var configs: [Set<String>] {
        configResource.map { WireConfigStore.shared.configs(resource: $0) } ?? []
    }
    /// Configs still reachable given the current selection.
    private var candidates: [Set<String>] { configs.filter { $0.isSuperset(of: selection) } }
    /// Terminals that appear in at least one reachable config (selectable set).
    private var allowed: Set<String> { candidates.reduce(into: Set<String>()) { $0.formUnion($1) } }
    /// The selection exactly matches a valid configuration.
    private var isValid: Bool { !selection.isEmpty && configs.contains(selection) }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(terminals, id: \.self) { t in
                            terminalChip(t)
                        }
                    }
                    .padding(16)
                    .background(SMA.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)

                    Text(step.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    statusLine
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: step.link, onLink: onHelp,
                             primary: "Continue", primaryEnabled: isValid, onPrimary: onAdvance)
        }
    }

    private func terminalChip(_ t: String) -> some View {
        let on = selection.contains(t)
        let enabled = allowed.contains(t)   // selected chips are always in `allowed`
        return Button {
            if on { selection.remove(t) } else { selection.insert(t) }
        } label: {
            TerminalTile(label: t, isOn: on, isEnabled: enabled)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .accessibilityLabel("Terminal \(t)")
        .accessibilityAddTraits(on ? [.isSelected] : [])
    }

    @ViewBuilder
    private var statusLine: some View {
        if isValid {
            Label("Valid wiring configuration", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(hex: 0x34C759))
        } else if !selection.isEmpty {
            Text("Keep selecting the terminals with wires attached.")
                .font(.footnote)
                .foregroundStyle(SMA.labelSecondary)
                .multilineTextAlignment(.center)
        }
    }
}

/// A single terminal tile, shared by the wire picker (interactive, state-styled)
/// and the Connect the Wires diagram (read-only, always shown as selected).
struct TerminalTile: View {
    let label: String
    let isOn: Bool
    var isEnabled: Bool = true

    var body: some View {
        Text(label)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isOn ? .white : (isEnabled ? SMA.accent : SMA.labelSecondary))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isOn ? SMA.accent : SMA.card)
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isOn ? SMA.accent : (isEnabled ? SMA.accent : SMA.separator), lineWidth: 1.5))
            )
    }
}

// MARK: - Connect the Wires

/// A dynamic illustration of the thermostat's terminal block: every available
/// terminal is shown as a slot, and the terminals picked in the wire-picker step
/// get a wire (in its conventional HVAC color) plugged in and labeled.
struct ConnectWiresContent: View {
    let step: InstallStep
    let selection: Set<String>
    let onHelp: () -> Void
    let onAdvance: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)
    private var terminals: [String] { WirePickerContent.terminalOrder }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(terminals, id: \.self) { t in
                            terminalCell(t)
                        }
                    }
                    .padding(16)
                    .background(SMA.fillTertiary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)

                    StepHeadline(title: step.title, detail: step.body)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: step.link, onLink: onHelp,
                             primary: "Continue", onPrimary: onAdvance)
        }
    }

    /// One terminal slot; connected terminals show a colored wire stub above the tile.
    private func terminalCell(_ t: String) -> some View {
        let connected = selection.contains(t)
        return VStack(spacing: 3) {
            Capsule()
                .fill(Self.wireColor(t))
                .frame(width: 7, height: 16)
                .overlay(Capsule().stroke(SMA.separator, lineWidth: 0.5))
                .opacity(connected ? 1 : 0)          // reserve space so tiles stay aligned
                .accessibilityHidden(true)
            TerminalTile(label: t, isOn: connected, isEnabled: connected)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(connected ? "Terminal \(t), wire connected" : "Terminal \(t), empty")
    }

    /// Conventional HVAC wire colors so the illustration reads like real wiring.
    static func wireColor(_ t: String) -> Color {
        switch t {
        case "R", "RC", "RH":             return Color(hex: 0xE0392B)   // red
        case "W", "W1", "W2", "W/E", "E": return Color(hex: 0xD8DCE0)   // white (tinted for contrast)
        case "Y", "Y1", "Y2":             return Color(hex: 0xF2C300)   // yellow
        case "G":                         return Color(hex: 0x34A853)   // green
        case "C", "B":                    return Color(hex: 0x2F6FE0)   // blue
        case "O", "O/B":                  return Color(hex: 0xF08A24)   // orange
        default:                          return SMA.labelSecondary     // aux/misc
        }
    }
}

// MARK: - Choice (furnace type, wire configuration)

struct ChoiceContent: View {
    let step: InstallStep
    let onHelp: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        List {
            Section(step.title) {
                ForEach(step.options) { option in
                    Button { onAdvance() } label: {
                        HStack(spacing: 14) {
                            if let image = option.image {
                                Image(image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 56, height: 56)
                                    .accessibilityHidden(true)
                            }
                            Text(option.title).foregroundStyle(SMA.labelPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(SMA.labelSecondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            if let link = step.link {
                Section {
                    Button(link) { onHelp() }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SMA.accent)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .listRowBackground(SMA.card)
        .background(SMA.groupedBackground)
    }
}

// MARK: - Remote Sensor pairing sheet

/// The Remote Sensor pairs through a single guided screen — device image, numbered
/// instructions, and a Complete button — rather than the multi-step install flow.
struct RoomSensorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var showHelp = false

    private let instructions = [
        "On your thermostat, select the Menu button in the top-left corner.",
        "Select Remote Sensors.",
        "Tap Add Sensor in the upper-right corner of the screen.",
        "Follow the on-screen step-by-step guided instructions.",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 18) {
                    Image("install.device.sensor")
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    Text("Connect Your Room Sensor")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    VStack(spacing: 0) {
                        ForEach(Array(instructions.enumerated()), id: \.offset) { index, text in
                            RoomSensorStepRow(number: index + 1, text: text)
                            if index < instructions.count - 1 {
                                Divider().padding(.leading, 52)
                            }
                        }
                    }
                    .background(SMA.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: "Learn More About Sensors", onLink: { showHelp = true },
                             primary: "Complete", onPrimary: { model.showAddDevice = false })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SMA.groupedBackground.ignoresSafeArea())
        .navigationTitle("Add Sensor")
        .inlineNavTitle()
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Back")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showHelp = true } label: {
                    Image(systemName: "questionmark.bubble")
                }
                .accessibilityLabel("Help and Support")
            }
        }
        .sheet(isPresented: $showHelp) { HelpSupportView() }
    }
}

/// A numbered instruction row for the Remote Sensor sheet.
private struct RoomSensorStepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(SMA.accent, in: Circle())
            Text(text)
                .font(.body)
                .foregroundStyle(SMA.labelPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Step \(number). \(text)")
    }
}
