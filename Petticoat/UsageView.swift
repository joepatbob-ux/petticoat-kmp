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
    /// Bound from the tab container so the Recent/Monthly toggle lives in the nav header.
    @Binding var range: UsageRange
    @State private var expanded: Set<UUID> = []

    var body: some View {
        List {
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
                    // Labels are high-contrast (not mode-colored); the section legend
                    // carries the color↔mode mapping. Keeps WCAG contrast on white.
                    Text(mode.detailLabel)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SMA.labelPrimary)
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
//
// Prototype runtime history, generated with a seasonal HVAC profile (cooling peaks in
// summer, heating + aux heat in winter, fan year-round) so the bars read realistically.
// Anchored to "today" and computed once: the daily list covers the current + previous
// month, and the Monthly Archive covers the trailing 13 months (back to the install
// month, which shows the insufficient-data state).

private enum UsageSample {
    static let recent: [UsagePeriod] = buildRecent()
    static let monthly: [UsagePeriod] = buildMonthly()

    private static let cal = Calendar.current
    private static let now = Date()

    private static let monthName: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("LLLL"); return f
    }()
    private static let weekdayName: DateFormatter = {
        let f = DateFormatter(); f.setLocalizedDateFormatFromTemplate("EEEE"); return f
    }()
    private static let ordinal: NumberFormatter = {
        let f = NumberFormatter(); f.numberStyle = .ordinal; return f
    }()

    /// Stable per-day pseudo-random value in 0..<1 (so the bars don't reshuffle each launch).
    private static func rand(_ seed: Int, _ salt: Int) -> Double {
        var x = UInt64(bitPattern: Int64((seed &* 73_856_093) ^ (salt &* 19_349_663)))
        x = (x ^ (x >> 30)) &* 0xbf58476d1ce4e5b9
        x = (x ^ (x >> 27)) &* 0x94d049bb133111eb
        x ^= x >> 31
        return Double(x % 10_000) / 10_000
    }

    /// Runtime minutes per mode for one day, shaped by the season.
    private static func dailyMinutes(for date: Date) -> [UsageMode: Int] {
        let month = cal.component(.month, from: date)
        let year = cal.component(.year, from: date)
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let seed = year * 1000 + dayOfYear
        // 1 at mid-July, 0 at mid-January.
        let summer = (cos(Double(month - 7) / 12 * 2 * .pi) + 1) / 2
        let winter = 1 - summer
        let cool = pow(summer, 1.6) * 340 * (0.7 + 0.6 * rand(seed, 1))
        let heat = pow(winter, 1.6) * 320 * (0.7 + 0.6 * rand(seed, 2))
        // Aux (emergency) heat only kicks in on the coldest stretch.
        let aux  = max(0, winter - 0.62) / 0.38 * 150 * (0.4 + 0.9 * rand(seed, 3))
        let fan  = 90 + summer * 120 + 60 * rand(seed, 4)
        return [.cool: Int(cool.rounded()), .heat: Int(heat.rounded()),
                .aux: Int(aux.rounded()), .fan: Int(fan.rounded())]
    }

    private static func dayTitle(_ date: Date) -> String {
        let day = cal.component(.day, from: date)
        let ord = ordinal.string(from: NSNumber(value: day)) ?? "\(day)"
        return "\(weekdayName.string(from: date)), \(ord)"
    }

    /// Current month to date, then the previous month in full — newest day first.
    private static func buildRecent() -> [UsagePeriod] {
        var periods: [UsagePeriod] = []
        for monthOffset in 0...1 {
            guard let anchor = cal.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let year = cal.component(.year, from: anchor)
            let month = cal.component(.month, from: anchor)
            let daysInMonth = cal.range(of: .day, in: .month, for: anchor)?.count ?? 30
            let lastDay = monthOffset == 0 ? cal.component(.day, from: now) : daysInMonth
            var entries: [UsageEntry] = []
            for day in stride(from: lastDay, through: 1, by: -1) {
                guard let date = cal.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                // A single data gap to exercise the insufficient state.
                let gap = monthOffset == 1 && day == 12
                entries.append(UsageEntry(title: dayTitle(date),
                                          minutes: gap ? [:] : dailyMinutes(for: date),
                                          insufficient: gap))
            }
            periods.append(UsagePeriod(name: monthName.string(from: anchor), entries: entries))
        }
        return periods
    }

    /// The trailing 13 months, grouped by year (newest first). The oldest is the install
    /// month, shown as insufficient history.
    private static func buildMonthly() -> [UsagePeriod] {
        let curYear = cal.component(.year, from: now)
        let curMonth = cal.component(.month, from: now)
        let curDay = cal.component(.day, from: now)
        var byYear: [(year: Int, entries: [UsageEntry])] = []
        for monthOffset in 0..<13 {
            guard let anchor = cal.date(byAdding: .month, value: -monthOffset, to: now) else { continue }
            let year = cal.component(.year, from: anchor)
            let month = cal.component(.month, from: anchor)
            let daysInMonth = cal.range(of: .day, in: .month, for: anchor)?.count ?? 30
            let lastDay = (year == curYear && month == curMonth) ? curDay : daysInMonth
            var total: [UsageMode: Int] = [:]
            for day in 1...lastDay {
                guard let date = cal.date(from: DateComponents(year: year, month: month, day: day)) else { continue }
                let m = dailyMinutes(for: date)
                for mode in UsageMode.allCases { total[mode, default: 0] += m[mode] ?? 0 }
            }
            let install = monthOffset == 12
            let entry = UsageEntry(title: monthName.string(from: anchor),
                                   minutes: install ? [:] : total,
                                   capacity: daysInMonth * 1440, insufficient: install)
            if let idx = byYear.firstIndex(where: { $0.year == year }) {
                byYear[idx].entries.append(entry)
            } else {
                byYear.append((year, [entry]))
            }
        }
        return byYear.map { UsagePeriod(name: "\($0.year)", entries: $0.entries) }
    }
}

#Preview {
    @Previewable @State var range: UsageRange = .recent
    NavigationStack {
        UsageView(range: $range)
            .navigationTitle("Usage")
            .inlineNavTitle()
    }
    .environment(AppModel())
}

