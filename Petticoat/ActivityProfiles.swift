import SwiftUI

// MARK: - Model

struct ActivityProfile: Identifiable, Hashable {
    let id: UUID
    var name: String
    var symbol: String
    var colorHex: UInt
    var heatTo: Int
    var coolTo: Int
    var subtitle: String

    init(
        id: UUID = UUID(),
        name: String,
        symbol: String,
        colorHex: UInt,
        heatTo: Int,
        coolTo: Int,
        subtitle: String
    ) {
        self.id = id
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.heatTo = heatTo
        self.coolTo = coolTo
        self.subtitle = subtitle
    }

    var rangeText: String { "\(heatTo) · \(coolTo)" }

    static let samples: [ActivityProfile] = [
        .init(name: "Away",    symbol: "figure.walk",     colorHex: 0x30B0C7, heatTo: 62, coolTo: 83, subtitle: "3 Sensors"),
        .init(name: "Home",    symbol: "house.fill",      colorHex: 0xFF9500, heatTo: 70, coolTo: 75, subtitle: "Thermostat"),
        .init(name: "Sleep",   symbol: "bed.double.fill", colorHex: 0xAF52DE, heatTo: 62, coolTo: 78, subtitle: "3 Sensors"),
        .init(name: "Workout", symbol: "dumbbell.fill",   colorHex: 0xFF3B30, heatTo: 62, coolTo: 78, subtitle: "3 Sensors"),
    ]

    /// A blank profile for the "create new" sheet. Computed so each new profile
    /// gets a fresh `id` — otherwise a shared constant id makes `saveProfile`
    /// overwrite the previously-created profile instead of appending.
    static var new: ActivityProfile {
        ActivityProfile(name: "", symbol: "house.fill", colorHex: 0xFF3B30, heatTo: 68, coolTo: 76, subtitle: "3 Sensors")
    }
}

// MARK: - Activity Profiles list

/// The Presets area: a list of activity profiles you can create, edit, and reorder.
struct ActivityProfilesList: View {
    @Environment(AppModel.self) private var model
    @State private var editing: ActivityProfile?
    @State private var creatingNew = false

    var body: some View {
        List {
            Section {
                ForEach(model.activityProfiles) { profile in
                    Button {
                        editing = profile
                    } label: {
                        HStack(spacing: 12) {
                            ProfileIcon(symbol: profile.symbol, colorHex: profile.colorHex, size: 30)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(profile.name)
                                    .foregroundStyle(SMA.labelPrimary)
                                Text(profile.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(SMA.labelSecondary)
                            }
                            Spacer()
                            Text(profile.rangeText)
                                .foregroundStyle(SMA.labelSecondary)
                                .monospacedDigit()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    // Tapping the row opens the editor; swipe covers Duplicate / Delete
                    // (icon-only — titles are too wide). Replaces the nested overflow menu,
                    // whose tap was swallowed by the row button.
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { model.deleteProfile(profile) } label: {
                            Image(systemName: "trash")
                        }
                        .accessibilityLabel("Delete \(profile.name)")

                        Button { model.duplicateProfile(profile) } label: {
                            Image(systemName: "plus.square.on.square")
                        }
                        .tint(SMA.accent)
                        .accessibilityLabel("Duplicate \(profile.name)")
                    }
                }
            } footer: {
                Text("Profiles set the temperature range and sensors used for each part of your day.")
            }
        }
        .groupedListChrome()
        .navigationTitle("Activity Profiles")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { creatingNew = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(item: $editing) { profile in
            EditActivityProfileView(profile: profile, onSave: model.saveProfile)
        }
        .sheet(isPresented: $creatingNew) {
            EditActivityProfileView(profile: .new, onSave: model.saveProfile)
        }
    }

}

/// A profile's colored circular icon.
struct ProfileIcon: View {
    let symbol: String
    let colorHex: UInt
    var size: CGFloat = 30

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex), in: Circle())
            .accessibilityHidden(true)
    }
}

// MARK: - Edit Activity Profile

struct EditActivityProfileView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var profile: ActivityProfile
    @State private var editingName = false
    let onSave: (ActivityProfile) -> Void

    init(profile: ActivityProfile, onSave: @escaping (ActivityProfile) -> Void) {
        _profile = State(initialValue: profile)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 10) {
                        ProfileIcon(symbol: profile.symbol, colorHex: profile.colorHex, size: 64)
                        Text(profile.name.isEmpty ? "New Profile" : profile.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(SMA.labelPrimary)
                        // Plain button (not a NavigationLink) so it stays centered with
                        // no row chevron; navigation is driven programmatically below.
                        Button { editingName = true } label: {
                            Text("Edit")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(SMA.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    Stepper(value: $profile.coolTo, in: 50...95) {
                        LabeledContent("Cool to", value: "\(profile.coolTo)")
                    }
                    Stepper(value: $profile.heatTo, in: 45...90) {
                        LabeledContent("Heat to", value: "\(profile.heatTo)")
                    }
                } header: {
                    Text("Setpoints")
                } footer: {
                    Text("Your system will use this range to determine the proper set point for your heating and cooling mode.")
                }

                Section {
                    NavigationLink {
                        PlaceholderDetail(title: "Participating Sensors")
                    } label: {
                        LabeledContent("Participating Sensors", value: "3 of 4")
                    }
                }
            }
            .groupedListChrome()
            .navigationDestination(isPresented: $editingName) {
                ProfileNameView(name: $profile.name, symbol: $profile.symbol, colorHex: $profile.colorHex)
            }
            .navigationTitle("Edit Activity Profile")
            .inlineNavTitle()
            .presentationDragIndicator(.visible)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    EditorCancelButton { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    EditorSaveButton { onSave(profile); dismiss() }
                }
            }
        }
    }
}

// MARK: - Profile Name (name + color + icon)

struct ProfileNameView: View {
    @Binding var name: String
    @Binding var symbol: String
    @Binding var colorHex: UInt

    private let colors: [UInt] = [0x30B0C7, 0x5856D6, 0xAF52DE, 0xFF3B30, 0xFF9500, 0x34C759]
    private let symbols = [
        "house.fill", "dumbbell.fill", "briefcase.fill", "book.fill", "fork.knife", "moon.zzz.fill",
        "figure.walk", "tv.fill", "cup.and.saucer.fill", "wineglass.fill", "paintpalette.fill", "bed.double.fill",
        "pawprint.fill", "gamecontroller.fill", "car.fill", "airplane", "leaf.fill", "flame.fill",
    ]
    private let grid = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        List {
            Section {
                TextField("Name", text: $name)
            }

            Section {
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { c in
                        Button { colorHex = c } label: {
                            ZStack {
                                Circle().fill(Color(hex: c))
                                if colorHex == c {
                                    Circle().fill(SMA.card).frame(width: 13, height: 13)
                                }
                            }
                            .frame(width: 34, height: 34)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("Color")
                        .accessibilityAddTraits(colorHex == c ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)

                LazyVGrid(columns: grid, spacing: 12) {
                    ForEach(symbols, id: \.self) { s in
                        Button { symbol = s } label: {
                            Image(systemName: s)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(symbol == s ? .white : Color(hex: colorHex))
                                .frame(width: 42, height: 42)
                                .background(Circle().fill(symbol == s ? Color(hex: colorHex) : SMA.fillTertiary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(s)
                        .accessibilityAddTraits(symbol == s ? [.isSelected] : [])
                    }
                }
                .padding(.vertical, 4)
                .listRowSeparator(.hidden)
            }
        }
        .groupedListChrome()
        .navigationTitle("Profile Name")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        ActivityProfilesList()
    }
    .environment(AppModel())
}
