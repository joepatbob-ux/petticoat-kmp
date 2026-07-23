import SwiftUI

/// A 24-hour radial clock dial for the schedule editor. Each event is drawn as a
/// colored arc from its start time to the next event's start (wrapping past
/// midnight). The selected event gets a draggable knob that sets its start time,
/// with a live readout in the center. Midnight is at the top, noon at the bottom.
struct RadialScheduleDial: View {
    let events: [ScheduleEvent]
    let selectedID: ScheduleEvent.ID?
    let onChangeStart: (ScheduleEvent.ID, Date) -> Void

    private let ringWidth: CGFloat = 24
    /// White gap between adjacent arcs, as a fraction of the full circle.
    private let gap: CGFloat = 0.006
    private let snapMinutes = 5
    private let spaceName = "scheduleDial"

    private var sortedEvents: [ScheduleEvent] { events.sorted { $0.time < $1.time } }
    private var selectedEvent: ScheduleEvent? {
        sortedEvents.first(where: { $0.id == selectedID }) ?? sortedEvents.first
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let ringD = size - ringWidth
            let radius = ringD / 2
            let center = CGPoint(x: size / 2, y: size / 2)

            ZStack {
                Circle()
                    .stroke(SMA.fillTertiary, lineWidth: ringWidth)
                    .frame(width: ringD, height: ringD)

                ForEach(arcs) { arc in
                    Circle()
                        .trim(from: arc.start, to: arc.end)
                        .stroke(Color(hex: arc.colorHex),
                                style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringD, height: ringD)
                }

                Text("12AM")
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .position(point(0, radius: radius - ringWidth, center: center))
                Text("12PM")
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .position(point(0.5, radius: radius - ringWidth, center: center))

                centerReadout

                if let sel = selectedEvent {
                    knob(for: sel, radius: radius, center: center)
                }
            }
            .frame(width: size, height: size)
            .coordinateSpace(.named(spaceName))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dialAccessibilityLabel)
    }

    // MARK: - Center readout

    private var centerReadout: some View {
        VStack(spacing: 3) {
            if let e = selectedEvent {
                Text("\(e.name.uppercased()) START")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(SMA.labelSecondary)
                Text(e.timeText)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(SMA.labelPrimary)
                    .monospacedDigit()
                if let end = endsAt(e) {
                    Text("ends at \(end)")
                        .font(.caption2)
                        .foregroundStyle(SMA.labelSecondary)
                }
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Knob

    private func knob(for e: ScheduleEvent, radius: CGFloat, center: CGPoint) -> some View {
        let p = point(frac(e.time), radius: radius, center: center)
        return Circle()
            .fill(.white)
            .frame(width: ringWidth + 10, height: ringWidth + 10)
            .overlay(Circle().stroke(Color(hex: e.colorHex), lineWidth: 4))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .position(p)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(spaceName))
                    .onChanged { value in
                        let dx = Double(value.location.x - center.x)
                        let dy = Double(value.location.y - center.y)
                        // atan2 gives angle from +x (3 o'clock); shift so top (midnight) = 0.
                        var a = atan2(dy, dx) + .pi / 2
                        if a < 0 { a += 2 * .pi }
                        let f = a / (2 * .pi)
                        var minutes = Int((f * 1440).rounded())
                        minutes = (minutes / snapMinutes) * snapMinutes
                        minutes = ((minutes % 1440) + 1440) % 1440
                        let newTime = Calendar.current.date(
                            bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? e.time
                        onChangeStart(e.id, newTime)
                    }
            )
            .accessibilityHidden(true)
    }

    // MARK: - Geometry

    /// A time as a fraction of the day, 0 = midnight (top), increasing clockwise.
    private func frac(_ date: Date) -> CGFloat {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        let m = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        return CGFloat(m) / 1440
    }

    /// Point on a circle of the given radius at fraction `f` (0 = top, clockwise).
    private func point(_ f: CGFloat, radius r: CGFloat, center: CGPoint) -> CGPoint {
        let a = Double(f) * 2 * .pi - .pi / 2
        return CGPoint(x: center.x + r * CGFloat(cos(a)), y: center.y + r * CGFloat(sin(a)))
    }

    private struct Arc: Identifiable {
        let id: Int
        let start: CGFloat
        let end: CGFloat
        let colorHex: UInt
    }

    /// One arc per event, from its start to the next event's start, inset by `gap`
    /// and split into two pieces where it crosses the midnight (top) seam.
    private var arcs: [Arc] {
        let evs = sortedEvents
        guard !evs.isEmpty else { return [] }
        var result: [Arc] = []
        for (i, e) in evs.enumerated() {
            let s = frac(e.time)
            var en = frac(evs[(i + 1) % evs.count].time)
            if evs.count == 1 { en = s + 1 }          // single event fills the ring
            else if en <= s { en += 1 }               // wraps past midnight
            let gs = s + gap
            let ge = en - gap
            guard ge > gs else { continue }
            if ge <= 1 {
                result.append(Arc(id: result.count, start: gs, end: ge, colorHex: e.colorHex))
            } else {
                result.append(Arc(id: result.count, start: min(gs, 1), end: 1, colorHex: e.colorHex))
                let wrapEnd = ge - 1
                if wrapEnd > 0 { result.append(Arc(id: result.count, start: 0, end: wrapEnd, colorHex: e.colorHex)) }
            }
        }
        return result
    }

    private func endsAt(_ e: ScheduleEvent) -> String? {
        let evs = sortedEvents
        guard evs.count > 1, let i = evs.firstIndex(where: { $0.id == e.id }) else { return nil }
        return evs[(i + 1) % evs.count].timeText
    }

    private var dialAccessibilityLabel: String {
        guard let e = selectedEvent else { return "Schedule dial" }
        return "\(e.name) starts at \(e.timeText)"
    }
}
