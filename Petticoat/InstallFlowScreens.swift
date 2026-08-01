import SwiftUI
import UIKit

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
    /// Reference photos captured on the "Take Photo of Your Wiring" step, if any.
    var wiringPhotos: [UIImage] = []
    let onHelp: () -> Void
    let onAdvance: () -> Void

    @State private var showPhoto = false

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

                    if !wiringPhotos.isEmpty { referencePhotoChip }

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
        .fullScreenCover(isPresented: $showPhoto) {
            WiringPhotoViewer(photos: wiringPhotos)
        }
    }

    /// Tappable stack of the wiring photos captured earlier, so the user can
    /// compare their terminal block against them while selecting.
    private var referencePhotoChip: some View {
        Button { showPhoto = true } label: {
            HStack(spacing: 12) {
                PhotoStackThumbnail(photos: wiringPhotos, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(wiringPhotos.count > 1 ? "Your Wiring Photos" : "Your Wiring Photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(SMA.labelPrimary)
                    Text("Tap to compare with your terminals")
                        .font(.caption)
                        .foregroundStyle(SMA.labelSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(SMA.labelSecondary)
            }
            .padding(10)
            .background(SMA.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .accessibilityLabel("View your wiring ^[\(wiringPhotos.count) photo](inflect: true)")
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

// MARK: - Label Your Wires

/// Illustrates the old thermostat's terminal block with a labeled sticker on every
/// wire the user picked in the wire-picker step. Each picked terminal becomes a
/// column — a blue wire-label sticker (top), the terminal screw, and the lettered
/// terminal tile (bottom) — packed edge to edge so the screw housings read as one
/// continuous strip, mirroring a real terminal block.
struct LabelWiresContent: View {
    let step: InstallStep
    let selection: Set<String>
    let onHelp: () -> Void
    let onAdvance: () -> Void

    /// Picked terminals in the canonical wire-picker order.
    private var terminals: [String] {
        WirePickerContent.terminalOrder.filter { selection.contains($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    WireBlockCard(header: "Wire Labels", footer: "Old Thermostat", terminals: terminals)
                    StepHeadline(title: step.title, detail: step.body)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: step.link, onLink: onHelp,
                             primary: "Continue", onPrimary: onAdvance)
        }
    }
}

// MARK: - Connect the Wires

/// The thermostat's terminal backplate, laid out per model to match the physical
/// device: Touch 2 / Classic / Lite use vertical terminal blocks flanking the
/// body; Touch uses a single horizontal row beneath the body. Wires picked
/// earlier are shown plugged into their terminals and labeled.
struct ConnectWiresContent: View {
    let model: ThermostatModel
    let step: InstallStep
    let selection: Set<String>
    let onHelp: () -> Void
    let onAdvance: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 36) {
                    TerminalBackplate(model: model, selection: selection)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)
                    StepHeadline(title: step.title, detail: step.body)
                }
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: step.link, onLink: onHelp,
                             primary: "Continue", onPrimary: onAdvance)
        }
    }
}

/// Per-model terminal backplate. Terminal sets, arrangement and style follow the
/// Figma "Connect the Wires" references for each model.
private struct TerminalBackplate: View {
    let model: ThermostatModel
    let selection: Set<String>
    enum Side { case left, right }

    private struct Layout {
        enum Arrangement { case blocks, row }
        enum Style { case push, screw }
        var arrangement: Arrangement
        var style: Style
        var left: [String]
        var right: [String]    // empty → single block (Lite)
    }

    private var layout: Layout {
        switch model {
        case .touch2:  return Layout(arrangement: .blocks, style: .push,
                                     left: ["RC", "RH", "C", "O/B", "Y", "G"],
                                     right: ["W2", "Y2", "W/E", "ACC-", "ACC+"])
        case .classic: return Layout(arrangement: .blocks, style: .screw,
                                     left: ["RC", "RH", "O/B", "G", "W/E", "C"],
                                     right: ["L", "Y2", "W2"])
        case .lite:    return Layout(arrangement: .blocks, style: .screw,
                                     left: ["R", "O/B", "Y", "G", "W/E", "C"],
                                     right: [])
        case .touch:   return Layout(arrangement: .row, style: .push,
                                     left: ["G", "O/B", "W2", "L", "W/E", "Y", "Y2", "C", "RC", "RH"],
                                     right: [])
        }
    }

    private var terminalAsset: String {
        layout.style == .push ? "install.terminal" : "install.terminalScrew.push"
    }

    // install.terminal / install.terminalScrew.push are 100×30; install.wirePlug is 38×30.
    private let termW: CGFloat = 128    // vertical-block terminal length
    private let termH: CGFloat = 38     // vertical-block terminal thickness
    private let gap: CGFloat = 3
    private let plugW: CGFloat = 40
    private let bodyW: CGFloat = 48

    private func isConnected(_ t: String) -> Bool {
        selection.contains(t) || (t == "O/B" && selection.contains("O"))
    }

    /// Whether the terminal art must be mirrored so its opening faces inward.
    /// Push art opens to the right natively; screw art opens to the left.
    private func flipped(_ side: Side) -> Bool {
        switch (layout.style, side) {
        case (.push, .right), (.screw, .left): return true
        default: return false
        }
    }

    var body: some View {
        Group {
            switch layout.arrangement {
            case .blocks: blocksBody
            case .row:    rowBody
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let on = (layout.left + layout.right).filter(isConnected)
        return "Thermostat terminal block. Wires connected: \(on.isEmpty ? "none" : on.joined(separator: ", "))"
    }

    // MARK: Vertical blocks (Touch 2 / Classic / Lite)

    private var blocksBody: some View {
        HStack(alignment: .center, spacing: 14) {
            block(layout.left, side: .left)
            centerBody.zIndex(-1)   // body sits behind the blocks so wires read on top
            if !layout.right.isEmpty { block(layout.right, side: .right) }
        }
        .fixedSize()
    }

    private var centerBody: some View {
        let count = CGFloat(layout.left.count)
        let h = count * termH + (count - 1) * gap
        return RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color(hex: 0x1E1E20))
            .frame(width: bodyW, height: h)
    }

    private func block(_ terminals: [String], side: Side) -> some View {
        VStack(spacing: gap) {
            ForEach(terminals, id: \.self) { horizontalTerminal($0, side: side) }
        }
        // Wires overlay a parallel column so each plug aligns to its terminal row
        // and pokes out of the inner (opening) edge toward the body.
        .overlay(alignment: side == .left ? .trailing : .leading) {
            VStack(spacing: gap) {
                ForEach(terminals, id: \.self) { t in
                    plug(t, flip: side == .right)
                        .frame(width: plugW, height: termH)
                        .opacity(isConnected(t) ? 1 : 0)
                }
            }
            .offset(x: side == .left ? plugW - 8 : -(plugW - 8))
        }
    }

    /// One terminal lying horizontally, opening facing inward. Screw-style art
    /// carries its letter on the outer label tab; push-style over the housing.
    private func horizontalTerminal(_ t: String, side: Side) -> some View {
        Image(terminalAsset)
            .resizable()
            .scaledToFit()
            .frame(width: termW, height: termH)
            .scaleEffect(x: flipped(side) ? -1 : 1, y: 1)
            .overlay {
                Text(t)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .offset(x: side == .left ? -termW * 0.24 : termW * 0.24)
            }
    }

    /// The blue wire-plug label art plugged into a terminal, carrying its letter.
    private func plug(_ t: String, flip: Bool) -> some View {
        Image("install.wirePlug")
            .resizable()
            .scaledToFit()
            .frame(width: plugW, height: termH)
            .scaleEffect(x: flip ? -1 : 1, y: 1)
            .overlay {
                Text(t)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 2)
            }
    }

    // MARK: Horizontal row (Touch)

    private let rowLen: CGFloat = 92      // terminal length (vertical when rotated)
    private let rowThick: CGFloat = 30    // terminal thickness (cell width)
    private let rowGap: CGFloat = 2

    private var rowBody: some View {
        let n = CGFloat(layout.left.count)
        let stripW = n * rowThick + (n - 1) * rowGap
        return ZStack(alignment: .top) {
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: 0x1E1E20))
                    .frame(width: stripW + 28, height: 42)
                    .zIndex(-1)
                HStack(spacing: rowGap) {
                    ForEach(layout.left, id: \.self) { verticalTerminal($0) }
                }
            }
            // Wires drop from the body into the top (opening) of connected terminals.
            HStack(spacing: rowGap) {
                ForEach(layout.left, id: \.self) { t in
                    plug(t, flip: false)
                        .rotationEffect(.degrees(90))
                        .frame(width: rowThick, height: plugW)
                        .opacity(isConnected(t) ? 1 : 0)
                }
            }
            .offset(y: 30)
        }
        .fixedSize()
    }

    /// A terminal standing vertically (opening at top) for the Touch row.
    private func verticalTerminal(_ t: String) -> some View {
        Image(terminalAsset)
            .resizable()
            .scaledToFit()
            .frame(width: rowLen, height: rowThick)
            .rotationEffect(.degrees(-90))   // opening (right) rotates to the top
            .frame(width: rowThick, height: rowLen)
            .overlay(alignment: .bottom) {
                Text(t)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.bottom, rowLen * 0.16)
            }
    }
}

// MARK: - Wire block illustration

/// One picked wire rendered as a column: a sticker-labeled wire chip above its
/// lettered terminal screw. Shared by the Label Your Wires and Connect the Wires
/// steps so both read as the same physical terminal block.
private struct WireColumn: View {
    let terminal: String
    let width: CGFloat

    /// Intrinsic aspect ratios of the two flattened art assets.
    private let labelAspect = 256.0 / 128.0    // install.wireLabel
    private let terminalAspect = 400.0 / 120.0 // install.terminalScrew

    var body: some View {
        VStack(spacing: 0) {
            Image("install.wireLabel")
                .resizable()
                .frame(width: width, height: width * labelAspect)
                .overlay(letter.position(x: width / 2, y: width * labelAspect * 0.484))
            Image("install.terminalScrew")
                .resizable()
                .frame(width: width, height: width * terminalAspect)
                .overlay(letter.position(x: width / 2, y: width * terminalAspect * 0.81))
        }
    }

    private var letter: some View {
        Text(terminal)
            .font(.system(size: width * 0.34, weight: .semibold))
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .foregroundStyle(.white)
    }
}

/// A terminal-block illustration: one labeled wire column per picked terminal,
/// packed edge to edge so the screw housings read as one continuous strip,
/// mirroring a real terminal block.
private struct WireBlockCard: View {
    let header: String
    let footer: String
    let terminals: [String]

    /// Per-terminal column width: shrink to fit the full picked set across a
    /// ~320pt block, capped so a large config stays on screen and a small one
    /// doesn't balloon.
    private var columnWidth: CGFloat {
        guard !terminals.isEmpty else { return 48 }
        return min(320 / CGFloat(terminals.count), 48)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text(header)
                .font(.headline)
                .foregroundStyle(SMA.labelSecondary)

            HStack(spacing: 0) {
                ForEach(terminals, id: \.self) { WireColumn(terminal: $0, width: columnWidth) }
            }
            .fixedSize()

            Text(footer)
                .font(.title2.weight(.bold))
                .foregroundStyle(SMA.labelSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(SMA.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(footer) terminal block with labeled wires: \(terminals.joined(separator: ", "))")
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
                             primary: "Complete", onPrimary: { model.setShowAddDevice(false) })
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

// MARK: - Wiring photo stack & viewer

/// A compact stacked-photos thumbnail: shows up to three shots fanned behind each
/// other so a small pile reads as "a few photos". Used in the capture summary and
/// the wire-picker reference chip.
struct PhotoStackThumbnail: View {
    let photos: [UIImage]
    var size: CGFloat = 30

    var body: some View {
        // Most-recent photo on top; up to two older ones peek out behind it.
        let shown = Array(photos.suffix(3))
        ZStack {
            ForEach(Array(shown.enumerated()), id: \.offset) { index, image in
                let depth = CGFloat(shown.count - 1 - index)   // 0 == front
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                        .stroke(.white, lineWidth: 1))
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                    .rotationEffect(.degrees(depth * 6), anchor: .bottomLeading)
                    .offset(x: depth * 3, y: depth * -2)
            }
        }
        .frame(width: size + CGFloat(min(shown.count - 1, 2)) * 3 + 4,
               height: size + 4, alignment: .leading)
        .accessibilityHidden(true)
    }
}

/// Full-screen viewer for the captured wiring reference photos. Swipe between
/// shots (paged) and pinch- or double-tap-to-zoom to inspect fine wiring detail.
struct WiringPhotoViewer: View {
    let photos: [UIImage]
    @Environment(\.dismiss) private var dismiss
    @State private var selection = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                TabView(selection: $selection) {
                    ForEach(photos.indices, id: \.self) { i in
                        ZoomableImage(image: photos[i]).tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: photos.count > 1 ? .always : .never))
            }
            .navigationTitle(photos.count > 1 ? "Photo \(selection + 1) of \(photos.count)" : "Your Wiring Photo")
            .inlineNavTitle()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// A single pinch- and double-tap-zoomable image on a black canvas.
private struct ZoomableImage: View {
    let image: UIImage
    @GestureState private var pinch: CGFloat = 1
    @State private var scale: CGFloat = 1

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale * pinch)
            .gesture(
                MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        scale = min(max(scale * value.magnification, 1), 4)
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.snappy) { scale = scale > 1 ? 1 : 2 }
            }
    }
}
