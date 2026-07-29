import SwiftUI

// MARK: - Sensors
//
// The Sensors screen: the device's averaged temperature/humidity, the thermostat's
// built-in sensor, and the paired room sensors you can include in the average or
// drill into for details. Presented from the control screen's sensor pill.

struct SensorsView: View {
    @Environment(AppModel.self) private var model

    /// The sensor drilled into (drives the pushed detail).
    @State private var detailSensor: RoomSensor?

    private var device: Device { model.device }
    /// Wired sensors (the thermostat itself) have no battery; battery-powered ones are
    /// the room sensors.
    private var wiredSensors: [RoomSensor] { device.sensors.filter { $0.battery == nil } }
    private var roomSensors: [RoomSensor] { device.sensors.filter { $0.battery != nil } }
    /// How many sensors currently feed the average — at least one must, so when it's down
    /// to one that sensor's toggle locks on.
    private var participatingCount: Int { device.sensors.filter { $0.participating }.count }
    private func lockedOn(_ sensor: RoomSensor) -> Bool { sensor.participating && participatingCount <= 1 }

    var body: some View {
        List {
            Section {
                HStack(spacing: 16) {
                    SensorMetricTile(value: "\(device.currentTemp)", label: "Temperature")
                    SensorMetricTile(value: "\(device.humidity)%", label: "Humidity")
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section("Thermostat") {
                ForEach(wiredSensors) { sensor in
                    SensorRow(sensor: sensor, showsDrillIn: false, lockedOn: lockedOn(sensor),
                              onToggle: { model.toggleSensor(sensor, in: device.id) },
                              onDrill: {})
                }
            }

            Section {
                ForEach(roomSensors) { sensor in
                    SensorRow(sensor: sensor, showsDrillIn: true, lockedOn: lockedOn(sensor),
                              onToggle: { model.toggleSensor(sensor, in: device.id) },
                              onDrill: { detailSensor = sensor })
                }
            } header: {
                Text("Sensors")
            } footer: {
                Text("Select what sensors you would like Sensi to use for occupancy and your displayed temperature average.")
            }
        }
        .groupedListChrome()
        .navigationTitle("Sensors")
        .navigationDestination(item: $detailSensor) { sensor in
            SensorDetailView(sensor: sensor)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.showHelp = true } label: { Image(systemName: "questionmark.bubble") }
                    .accessibilityLabel("Help and Support")
            }
        }
    }
}

/// One of the two big rounded readout tiles at the top of the Sensors screen.
private struct SensorMetricTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(SMA.labelPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(SMA.labelSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(SMA.fillTertiary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label) \(value)")
    }
}

/// A selectable sensor row: the leading checkmark toggles participation in the average;
/// room sensors additionally drill into their details.
private struct SensorRow: View {
    let sensor: RoomSensor
    let showsDrillIn: Bool
    /// The last participating sensor can't be deselected (the average needs a source), so
    /// its toggle is disabled.
    var lockedOn: Bool = false
    let onToggle: () -> Void
    let onDrill: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: sensor.participating ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    // A locked-on (disabled) check reads as disabled grey rather
                    // than the active accent, since it can't be toggled off.
                    .foregroundStyle(lockedOn ? SMA.labelSecondary
                                              : (sensor.participating ? SMA.accent : SMA.labelSecondary))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .disabled(lockedOn)
            .accessibilityLabel("\(sensor.name) participates in average")
            .accessibilityAddTraits(sensor.participating ? [.isSelected] : [])
            .accessibilityHint(lockedOn ? "At least one sensor must feed the average" : "")

            Button(action: showsDrillIn ? onDrill : onToggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(sensor.name)
                            .foregroundStyle(SMA.labelPrimary)
                        Text("\(sensor.temp) (\(sensor.humidity)% Humidity)")
                            .font(.footnote)
                            .foregroundStyle(SMA.labelSecondary)
                    }
                    Spacer(minLength: 8)
                    if let level = sensor.battery {
                        Image(systemName: RoomSensor.batterySymbol(level))
                            .foregroundStyle(RoomSensor.batteryColor(level))
                            .accessibilityLabel("Battery \(level) percent")
                    }
                    if showsDrillIn {
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(SMA.labelSecondary)
                            .accessibilityHidden(true)   // decorative; the row is already a labeled button
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(showsDrillIn ? "Opens sensor details" : "")
        }
    }
}

// MARK: - Sensor Details

struct SensorDetailView: View {
    @Environment(AppModel.self) private var model
    let sensor: RoomSensor
    @State private var name: String

    init(sensor: RoomSensor) {
        self.sensor = sensor
        _name = State(initialValue: sensor.name)
    }

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
                    .onChange(of: name) { _, _ in commitName() }
                    .onSubmit(commitName)
            }

            Section("Sensor Information") {
                LabeledContent("Temperature", value: "\(sensor.temp)")
                LabeledContent("Humidity", value: "\(sensor.humidity)%")
                LabeledContent("Signal Strength", value: "Good")
                LabeledContent("Battery Health", value: batteryHealth)
                LabeledContent("Sensor ID", value: "1234567890ABCDEF")
                LabeledContent("Firmware Version", value: "12345")
            }
        }
        .groupedListChrome()
        .navigationTitle("Sensor Details")
        .inlineNavTitle()
        .onDisappear(perform: commitName)
    }

    /// Persists the edited name back to the model (on submit and when leaving).
    private func commitName() {
        model.renameSensor(sensor.id, to: name, in: model.device.id)
    }

    private var batteryHealth: String {
        guard let level = sensor.battery else { return "Wired" }
        switch level {
        case 50...:   return "Good"
        case 20..<50: return "Fair"
        default:      return "Replace Soon"
        }
    }
}

#Preview {
    NavigationStack {
        SensorsView()
    }
    .environment(AppModel())
}
