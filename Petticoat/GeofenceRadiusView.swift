import SwiftUI
import MapKit
import CoreLocation

// MARK: - Geofence radius control
//
// The Auto Home/Away geofence radius, built on the iOS 26+ MapKit-for-SwiftUI
// APIs (`Map(position:)` + `MapCircle`). A fixed home coordinate is used (the
// device's stated location), so no Core Location permission or entitlement is
// needed for this prototype.

/// Distance unit for the geofence radius.
enum DistanceUnit: String, CaseIterable, Identifiable {
    case miles, kilometers
    var id: String { rawValue }

    var label: String { self == .miles ? "Miles" : "Kilometers" }
    /// Meters in one unit, used to size the map circle.
    var meters: Double { self == .miles ? 1609.344 : 1000 }
    var range: ClosedRange<Int> { self == .miles ? 1...10 : 1...16 }

    /// "3 Miles" / "1 Kilometer" — singular when the value is 1.
    func valueLabel(_ v: Int) -> String {
        let word: String
        switch self {
        case .miles:      word = v == 1 ? "Mile" : "Miles"
        case .kilometers: word = v == 1 ? "Kilometer" : "Kilometers"
        }
        return "\(v) \(word)"
    }
}

struct GeofenceRadiusView: View {
    @Environment(AppModel.self) private var model
    @Binding var radius: Int
    @Binding var unit: DistanceUnit

    /// St. Louis, MO — matches the sample device's location.
    private let home = CLLocationCoordinate2D(latitude: 38.6270, longitude: -90.1994)
    @State private var camera: MapCameraPosition = .automatic

    private var radiusMeters: Double { Double(radius) * unit.meters }

    var body: some View {
        List {
            Section {
                Map(position: $camera, interactionModes: []) {
                    Annotation("", coordinate: home) {
                        Circle()
                            .fill(SMA.accent)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 2)
                    }
                    MapCircle(center: home, radius: radiusMeters)
                        .foregroundStyle(SMA.accent.opacity(0.20))
                        .stroke(SMA.accent.opacity(0.85), lineWidth: 2)
                }
                .frame(height: 176)
                .listRowInsets(EdgeInsets())

                Stepper(value: $radius, in: unit.range) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Radius")
                            .foregroundStyle(SMA.labelPrimary)
                        Text(unit.valueLabel(radius))
                            .font(.subheadline)
                            .foregroundStyle(SMA.accent)
                    }
                }
            }

            Section {
                Picker("Units", selection: $unit) {
                    ForEach(DistanceUnit.allCases) { u in
                        Text(u.label).tag(u)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .groupedListChrome()
        .navigationTitle("Radius")
        .inlineNavTitle()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.setShowHelp(true) } label: { Image(systemName: "questionmark.bubble") }
                    .accessibilityLabel("Help and Support")
            }
        }
        .onAppear { reframe() }
        .onChange(of: radius) { _, _ in reframe() }
        .onChange(of: unit) { _, newUnit in
            // Keep the value inside the new unit's range, then refit the map.
            radius = min(max(radius, newUnit.range.lowerBound), newUnit.range.upperBound)
            reframe()
        }
    }

    /// Frames the map so the radius circle fills most of the map row.
    private func reframe() {
        let span = radiusMeters * 2.6
        withAnimation(.snappy) {
            camera = .region(MKCoordinateRegion(center: home,
                                                latitudinalMeters: span,
                                                longitudinalMeters: span))
        }
    }
}

#Preview {
    @Previewable @State var radius = 3
    @Previewable @State var unit: DistanceUnit = .miles
    return NavigationStack {
        GeofenceRadiusView(radius: $radius, unit: $unit)
    }
}
