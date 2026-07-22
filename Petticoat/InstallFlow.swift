import SwiftUI

// MARK: - Models

/// The kind of screen a step renders. `standard` is the hero+title+body template;
/// the rest are the interactive/branch screen types.
enum InstallStepKind {
    case standard
    case fullBleed      // full-screen photo (Setup Complete)
    case wifiList       // pick a Wi-Fi network
    case pin            // enter security code
    case loading        // configuring… auto-advances
    case form           // enter location
    case wirePicker     // select terminals with wires
    case connectWires   // diagram of the terminals picked in the wire-picker step
    case choice         // tap a row to continue (furnace type, wire configuration)
}

/// One tappable option in a `.choice` step.
struct ChoiceOption: Identifiable {
    let id = UUID()
    let title: String
    var image: String? = nil
}

/// One screen in a device install flow.
struct InstallStep: Identifiable {
    let id = UUID()
    /// Section label shown in the top bar (e.g. "Install", "Connect", "Register").
    let stage: String
    var kind: InstallStepKind = .standard
    var hero: String = ""
    /// Big content title (also used as the section header for `.choice`).
    var title: String = ""
    var body: String? = nil
    /// Optional orange caution pill shown above the title (standard steps).
    var warning: String? = nil
    var primary: String = "Continue"
    var secondary: String? = nil
    var link: String? = nil
    /// Rows for `.choice` steps.
    var options: [ChoiceOption] = []
}

/// A device offered in the Add Device list. An empty `steps` array marks a device
/// whose guided flow isn't built yet (routes to a "coming soon" screen).
struct InstallDevice: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let thumbnail: String
    /// Bundled resource (…\.txt) of valid wire configurations for this device's
    /// wire-picker step, or nil if none.
    var wireConfigResource: String? = nil
    let steps: [InstallStep]

    var isAvailable: Bool { !steps.isEmpty }

    static let all: [InstallDevice] = [touch2, lite, touch, smartThermostat, roomSensor]

    /// The fully-built flow: Install (with branch screens) → Connect → Register.
    static let touch2 = InstallDevice(
        name: "Touch 2",
        subtitle: "Smart Room Thermostat",
        thumbnail: "install.device.touch2",
        wireConfigResource: "WireConfigsTouchTwo",
        steps: [
            // ── Install ──────────────────────────────────────────────
            InstallStep(
                stage: "Getting Started", hero: "install.hero.gettingStarted", title: "Sensi Touch 2",
                body: "Is this thermostat already mounted on the wall?",
                primary: "Not Yet Mounted", secondary: "Already Mounted"),
            InstallStep(
                stage: "Install", hero: "install.hero.gatherTools", title: "Gather Your Tools",
                body: "Before we begin, you'll need to gather the following tools: Phillips and/or Flathead Screwdriver, Drill with 3/16 (4 mm) bit, Wire Cutter. You may also need needle-nose pliers.",
                link: "Installation Overview"),
            InstallStep(
                stage: "Install", hero: "install.hero.turnOffPower", title: "Turn Off Power",
                body: "Turn off the power to your heating and air conditioning system by using your fuse box or the switch next to your furnace.",
                link: "How to Turn Off Power"),
            InstallStep(
                stage: "Install", hero: "install.hero.removeExisting", title: "Remove Existing Thermostat",
                body: "Remove your old thermostat from the wall, leaving the wires connected for now.",
                warning: "Do not disconnect your wires yet",
                link: "How to Remove the Old Thermostat"),
            InstallStep(
                stage: "Install", hero: "install.hero.photoWiring", title: "Take Photo of Your Wiring",
                body: "Take a photo of your existing thermostat wiring in case you need it for reference later. The photo will be saved to your camera roll.",
                secondary: "Take Photo Now"),
            InstallStep(
                stage: "Install", kind: .wirePicker, title: "Pick Terminals with Wires Attached",
                link: "How to Pick Your Wires"),
            InstallStep(
                stage: "Install", hero: "install.hero.labelWires", title: "Label Your Wires",
                body: "Using the provided wire label stickers, carefully label your wires by removing one wire at a time from the terminal and applying a label sticker.",
                link: "If My Labels Don't Match"),
            InstallStep(
                stage: "Install", kind: .choice, title: "Furnace Type",
                link: "Identify Furnace Type",
                options: [ChoiceOption(title: "Gas"), ChoiceOption(title: "Electric"), ChoiceOption(title: "Boiler")]),
            InstallStep(
                stage: "Install", kind: .choice, title: "Wire Configuration",
                options: [
                    ChoiceOption(title: "I have one \"R\" wire", image: "install.hero.jumperOneR"),
                    ChoiceOption(title: "I have two \"R\" wires", image: "install.hero.jumperTwoR"),
                ]),
            InstallStep(
                stage: "Install", hero: "install.hero.jumperTwoR", title: "Pull Any Jumper Wires",
                body: "If your old thermostat has a jumper wire linking two terminals (for example R and RC), remove it now. Your Sensi thermostat manages this connection internally, so jumpers are no longer needed.",
                warning: "Remove jumpers before disconnecting",
                link: "How to Identify a Jumper Wire"),
            InstallStep(
                stage: "Install", hero: "install.hero.removeBase", title: "Disconnect Wires and Remove Base",
                link: "How to Remove Old Thermostat Base"),
            InstallStep(
                stage: "Install", hero: "install.hero.installNewBase", title: "Install New Thermostat Base",
                body: "Mount the thermostat base securely using the supplied screws and, if needed, drill holes and insert anchors for added support.",
                link: "How to Install New Thermostat Base"),
            InstallStep(
                stage: "Install", kind: .connectWires, title: "Connect the Wires",
                body: "Press the paddle underneath the terminal corresponding to the wire label sticker and insert the wire into the opening.",
                link: "How to Connect the Wires"),
            InstallStep(
                stage: "Install", hero: "install.hero.attachBase", title: "Attach Thermostat to Base",
                body: "Securely attach the thermostat to the baseplate."),
            InstallStep(
                stage: "Install", hero: "install.hero.turnOnPower", title: "Turn On Power",
                body: "Turn the power to the heating or air conditioning system back on."),
            // ── Connect ──────────────────────────────────────────────
            InstallStep(
                stage: "Connect", hero: "install.hero.wifiSetup", title: "Wi-Fi Setup",
                body: "On the thermostat, tap the Menu Button in the top-left corner."),
            InstallStep(
                stage: "Connect", kind: .wifiList, title: "Select Wi-Fi"),
            InstallStep(
                stage: "Connect", kind: .pin, hero: "install.hero.pinDevice", title: "Enter Security Code",
                body: "Please enter the Security Code on the screen of your Sensi Thermostat."),
            // ── Register ─────────────────────────────────────────────
            InstallStep(
                stage: "Register", kind: .loading, title: "Configuring your thermostat…",
                body: "This will advance automatically once registration is complete."),
            InstallStep(
                stage: "Register", kind: .form, title: "Thermostat Location"),
            InstallStep(
                stage: "Setup Complete", kind: .fullBleed, hero: "install.hero.setupComplete",
                title: "You've successfully set up and registered your Sensi Thermostat!"),
        ])

    static let lite = InstallDevice(name: "Lite", subtitle: "Smart Thermostat", thumbnail: "install.device.lite", steps: [])
    static let touch = InstallDevice(name: "Touch", subtitle: "Smart Thermostat", thumbnail: "install.device.touch", steps: [])
    static let smartThermostat = InstallDevice(name: "Smart Thermostat", subtitle: "Wi-Fi Thermostat", thumbnail: "install.device.smartThermostat", steps: [])
    static let roomSensor = InstallDevice(name: "Room Sensor", subtitle: "Temperature & Occupancy", thumbnail: "install.device.roomSensor", steps: [])
}

// MARK: - Add Device list

/// Entry point for adding a device, presented as a sheet from the dashboard. Each
/// row drills into that device's guided install flow.
struct AddDeviceView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(InstallDevice.all) { device in
                    Section {
                        NavigationLink {
                            destination(for: device)
                        } label: {
                            DeviceRow(device: device)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(SMA.groupedBackground.ignoresSafeArea())
            .listRowBackground(SMA.card)
            .foregroundStyle(SMA.labelPrimary)
            .navigationTitle("Add Device")
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

    @ViewBuilder
    private func destination(for device: InstallDevice) -> some View {
        if device.isAvailable {
            InstallFlowView(device: device)
        } else {
            PlaceholderDetail(title: "\(device.name) Setup")
        }
    }
}

private struct DeviceRow: View {
    let device: InstallDevice

    var body: some View {
        HStack(spacing: 14) {
            Image(device.thumbnail)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .foregroundStyle(SMA.labelPrimary)
                Text(device.subtitle)
                    .font(.footnote)
                    .foregroundStyle(SMA.labelSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Install flow engine

/// Data-driven guided install flow. Walks `device.steps` with a custom top bar
/// (back · stage · progress · help) and renders the appropriate screen per kind.
struct InstallFlowView: View {
    let device: InstallDevice
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var showHelp = false
    /// Terminals chosen in the wire-picker step; read back by the Connect the Wires step.
    @State private var wireSelection: Set<String> = []

    private var step: InstallStep { device.steps[index] }
    private var progress: Double { Double(index + 1) / Double(device.steps.count) }

    var body: some View {
        Group {
            if step.kind == .fullBleed {
                fullBleedContent
            } else {
                VStack(spacing: 0) {
                    InstallTopBar(stage: step.stage, progress: progress,
                                  index: index, count: device.steps.count,
                                  onBack: back, onHelp: { showHelp = true })
                    stepContent
                        .id(index)
                }
                .background(SMA.groupedBackground.ignoresSafeArea())
            }
        }
        .navigationBarBackButtonHidden(true)
        .hideNavBar()
        .animation(.snappy, value: index)
        .sheet(isPresented: $showHelp) { HelpSupportView() }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step.kind {
        case .standard:   standardContent
        case .wifiList:   WifiListContent(step: step, onAdvance: advance)
        case .pin:        PinContent(step: step, onAdvance: advance)
        case .loading:    LoadingContent(step: step, onAdvance: advance)
        case .form:       FormContent(step: step, onAdvance: advance)
        case .wirePicker: WirePickerContent(step: step, configResource: device.wireConfigResource, selection: $wireSelection, onHelp: { showHelp = true }, onAdvance: advance)
        case .connectWires: ConnectWiresContent(step: step, selection: wireSelection, onHelp: { showHelp = true }, onAdvance: advance)
        case .choice:     ChoiceContent(step: step, onHelp: { showHelp = true }, onAdvance: advance)
        case .fullBleed:  EmptyView()
        }
    }

    // MARK: Standard step

    private var standardContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    Image(step.hero)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .padding(.top, 8)
                        .accessibilityHidden(true)

                    StepHeadline(title: step.title, detail: step.body, warning: step.warning)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }

            InstallButtonBar(link: step.link, onLink: { showHelp = true },
                             secondary: step.secondary, onSecondary: advance,
                             primary: step.primary, onPrimary: advance)
        }
    }

    // MARK: Full-bleed "Setup Complete" step

    private var fullBleedContent: some View {
        ZStack {
            Image(step.hero)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            LinearGradient(colors: [.black.opacity(0.35), .clear, .black.opacity(0.7)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                InstallTopBar(stage: step.stage, progress: progress,
                              index: index, count: device.steps.count,
                              onBack: finish, onHelp: { showHelp = true },
                              closeStyle: true, onLight: true)
                Spacer()
                VStack(spacing: 20) {
                    Text(step.title)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button { finish() } label: {
                        Text(step.primary).font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(SMA.accent)
                }
                .padding(20)
            }
        }
    }

    // MARK: Navigation

    private func advance() {
        if index < device.steps.count - 1 { index += 1 } else { finish() }
    }

    private func back() {
        if index > 0 { index -= 1 } else { dismiss() }
    }

    /// Finish the flow by closing the whole Add Device sheet.
    private func finish() {
        model.showAddDevice = false
    }
}

#Preview {
    AddDeviceView()
        .environment(AppModel())
}
