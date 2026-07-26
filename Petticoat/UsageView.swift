import SwiftUI
import Charts

// MARK: - Usage
//
// The Usage device tab: HVAC runtime over a selected range, split into heating and
// cooling, with a summary. Prototype-local sample data — no Figma was provided for
// this screen, so it's a native proposal using Swift Charts.

enum UsageRange: String, CaseIterable, Identifiable {
    case week, month
    var id: String { rawValue }
    var label: String { self == .week ? "This Week" : "This Month" }

    var days: [UsageBucket] {
        switch self {
        case .week:  return UsageBucket.week
        case .month: return UsageBucket.month
        }
    }
}

/// One bar in the runtime chart: a labeled period with heating + cooling hours.
struct UsageBucket: Identifiable {
    let id = UUID()
    let label: String
    let heating: Double
    let cooling: Double
    var total: Double { heating + cooling }

    static let week: [UsageBucket] = [
        .init(label: "Mon", heating: 2.5, cooling: 1.0),
        .init(label: "Tue", heating: 3.0, cooling: 0.5),
        .init(label: "Wed", heating: 1.5, cooling: 2.0),
        .init(label: "Thu", heating: 0.5, cooling: 3.5),
        .init(label: "Fri", heating: 1.0, cooling: 3.0),
        .init(label: "Sat", heating: 2.0, cooling: 2.5),
        .init(label: "Sun", heating: 2.5, cooling: 1.5),
    ]

    static let month: [UsageBucket] = [
        .init(label: "W1", heating: 14, cooling: 9),
        .init(label: "W2", heating: 11, cooling: 12),
        .init(label: "W3", heating: 8,  cooling: 16),
        .init(label: "W4", heating: 10, cooling: 13),
    ]
}

struct UsageView: View {
    @State private var range: UsageRange = .week

    private var buckets: [UsageBucket] { range.days }
    private var totalHeating: Double { buckets.reduce(0) { $0 + $1.heating } }
    private var totalCooling: Double { buckets.reduce(0) { $0 + $1.cooling } }
    private var total: Double { totalHeating + totalCooling }

    var body: some View {
        List {
            Section {
                Picker("Range", selection: $range) {
                    ForEach(UsageRange.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Runtime") {
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Hours", bucket.heating)
                    )
                    .foregroundStyle(by: .value("Mode", "Heating"))

                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Hours", bucket.cooling)
                    )
                    .foregroundStyle(by: .value("Mode", "Cooling"))
                }
                .chartForegroundStyleScale(["Heating": SMA.tempOrange, "Cooling": SMA.accent])
                .chartYAxisLabel("Hours")
                .frame(height: 220)
                .padding(.vertical, 8)
            }

            Section("Summary") {
                LabeledContent("Total Runtime", value: hoursText(total))
                LabeledContent("Heating") {
                    Label(hoursText(totalHeating), systemImage: "flame.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(SMA.tempOrange)
                }
                LabeledContent("Cooling") {
                    Label(hoursText(totalCooling), systemImage: "snowflake")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(SMA.accent)
                }
                LabeledContent("Daily Average", value: hoursText(total / Double(max(1, buckets.count))))
            }
        }
        .groupedListChrome()
        .animation(.snappy, value: range)
    }

    /// Formats a fractional hours value as "3h 30m" (or "45m" under an hour).
    private func hoursText(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

#Preview {
    NavigationStack {
        UsageView()
            .navigationTitle("Usage")
            .inlineNavTitle()
    }
    .environment(AppModel())
}
