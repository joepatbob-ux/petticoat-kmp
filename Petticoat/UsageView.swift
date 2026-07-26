import SwiftUI

// MARK: - Usage
//
// The Usage device tab: HVAC runtime broken down by mode (cooling / heating / aux heat /
// fan) per day (Recent) or per month (Monthly Archive). Each row shows a proportional
// mode bar; tapping a row expands the per-mode durations. Prototype-local sample data.

enum UsageMode: String, CaseIterable, Identifiable {
    case cool, heat, aux, fan
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .cool: SMA.coolingBlue
        case .heat: SMA.heatingOrange
        case .aux:  SMA.auxRed
        case .fan:  SMA.fanPurple
        }
    }
    /// Column heading in the expanded breakdown.
    var detailLabel: String {
        switch self {
        case .cool: "Cooling"
        case .heat: "Heating"
        case .aux:  "AUX Heat"
        case .fan:  "Fan Only"
        }
    }
    /// Short legend label.
    var legendLabel: String {
        switch self {
        case .cool: "Cool"
        case .heat: "Heat"
        case .aux:  "AUX Heat"
        case .fan:  "Fan Only"
        }
    }
}

struct UsageEntry: Identifiable {
    let id = UUID()
    let title: String
    /// Minutes of runtime per mode.
    let minutes: [UsageMode: Int]
    /// Total minutes in the period (day = 1440), for the bar's remainder.
    var capacity: Int = 1440
    var insufficient: Bool = false
}

struct UsagePeriod: Identifiable {
    let id = UUID()
    let name: String
    let entries: [UsageEntry]
}

enum UsageRange: String, CaseIterable, Identifiable {
    case recent, monthly
    var id: String { rawValue }
    var label: String { self == .recent ? "Recent" : "Monthly Archive" }
    var periods: [UsagePeriod] { self == .recent ? UsageSample.recent : UsageSample.monthly }
}

struct UsageView: View {
    @Environment(AppModel.self) private var model
    @State private var range: UsageRange = .recent
    @State private var expanded: Set<UUID> = []

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

            ForEach(range.periods) { period in
                Section {
                    ForEach(period.entries) { entry in
                        UsageEntryRow(
                            entry: entry,
                            isExpanded: expanded.contains(entry.id),
                            onToggle: { toggle(entry.id) },
                            onLearnMore: { model.showHelp = true }
                        )
                    }
                    UsageLegend()
                        .listRowSeparator(.hidden)
                } header: {
                    Text(period.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(SMA.labelPrimary)
                        .textCase(nil)
                }
            }
        }
        .groupedListChrome()
        .animation(.snappy, value: expanded)
        .animation(.snappy, value: range)
    }

    private func toggle(_ id: UUID) {
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
    }
}

/// One day/month row: title, proportional mode bar, and an expandable breakdown (or an
/// "insufficient data" state).
private struct UsageEntryRow: View {
    let entry: UsageEntry
    let isExpanded: Bool
    let onToggle: () -> Void
    let onLearnMore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(entry.title)
                .foregroundStyle(SMA.labelPrimary)
                .frame(height: 44, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            if entry.insufficient {
                UsageBar(minutes: [:], capacity: entry.capacity)
                HStack {
                    Text("Insufficient data")
                        .font(.callout)
                        .foregroundStyle(SMA.labelSecondary)
                    Spacer()
                    Button("Learn More", action: onLearnMore)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 8)
            } else {
                UsageBar(minutes: entry.minutes, capacity: entry.capacity)
                if isExpanded {
                    UsageBreakdown(minutes: entry.minutes)
                        .padding(.top, 10)
                }
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { if !entry.insufficient { onToggle() } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(entry.insufficient ? [] : .isButton)
        .accessibilityHint(entry.insufficient ? "" : (isExpanded ? "Collapse breakdown" : "Expand breakdown"))
    }
}

/// The stacked, proportional runtime bar (cool / heat / aux / fan + idle remainder).
private struct UsageBar: View {
    let minutes: [UsageMode: Int]
    let capacity: Int

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(UsageMode.allCases) { mode in
                    let m = minutes[mode] ?? 0
                    if m > 0 {
                        Rectangle()
                            .fill(mode.color)
                            .frame(width: geo.size.width * CGFloat(m) / CGFloat(max(1, capacity)))
                    }
                }
                Rectangle().fill(SMA.fillTertiary)   // idle remainder fills the rest
            }
        }
        .frame(height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The four-column per-mode duration breakdown shown when a row is expanded.
private struct UsageBreakdown: View {
    let minutes: [UsageMode: Int]

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ForEach(UsageMode.allCases) { mode in
                VStack(alignment: .leading, spacing: 0) {
                    Text(mode.detailLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(mode.color)
                    Text(durationText(minutes[mode] ?? 0))
                        .font(.footnote)
                        .foregroundStyle(SMA.labelSecondary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// The mode legend shown at the bottom of each section.
private struct UsageLegend: View {
    var body: some View {
        HStack(spacing: 12) {
            ForEach(UsageMode.allCases) { mode in
                HStack(spacing: 3) {
                    Circle().fill(mode.color).frame(width: 8, height: 8)
                    Text(mode.legendLabel)
                        .font(.caption)
                        .foregroundStyle(SMA.labelPrimary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .accessibilityHidden(true)
    }
}

/// Formats minutes as "16h 52m" (or "52m" / "16h").
private func durationText(_ minutes: Int) -> String {
    let h = minutes / 60
    let m = minutes % 60
    if h == 0 { return "\(m)m" }
    return m == 0 ? "\(h)h" : "\(h)h \(m)m"
}

// MARK: - Sample data

private enum UsageSample {
    static let recent: [UsagePeriod] = [
        UsagePeriod(name: "June", entries: [
            UsageEntry(title: "Sunday, 27th",   minutes: [.cool: 92,  .heat: 148, .aux: 34, .fan: 210]),
            UsageEntry(title: "Saturday, 26th", minutes: [.cool: 140, .heat: 60,  .aux: 0,  .fan: 180]),
            UsageEntry(title: "Friday, 25th",   minutes: [.cool: 60,  .heat: 220, .aux: 80, .fan: 120]),
            UsageEntry(title: "Thursday, 24th", minutes: [:], insufficient: true),
        ]),
        UsagePeriod(name: "May", entries: [
            UsageEntry(title: "Saturday, 31st", minutes: [.cool: 200, .heat: 40,  .aux: 0,  .fan: 150]),
            UsageEntry(title: "Friday, 30th",   minutes: [.cool: 120, .heat: 120, .aux: 20, .fan: 90]),
        ]),
    ]

    static let monthly: [UsagePeriod] = [
        UsagePeriod(name: "2025", entries: [
            UsageEntry(title: "June",  minutes: [.cool: 3200, .heat: 2100, .aux: 400, .fan: 5000], capacity: 43200),
            UsageEntry(title: "May",   minutes: [.cool: 2600, .heat: 3100, .aux: 600, .fan: 4200], capacity: 43200),
            UsageEntry(title: "April", minutes: [.cool: 1200, .heat: 5200, .aux: 1400, .fan: 3800], capacity: 43200),
            UsageEntry(title: "March", minutes: [:], capacity: 43200, insufficient: true),
        ]),
    ]
}

#Preview {
    NavigationStack {
        UsageView()
            .navigationTitle("Usage")
            .inlineNavTitle()
    }
    .environment(AppModel())
}
