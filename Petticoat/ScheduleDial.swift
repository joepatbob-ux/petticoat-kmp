import SwiftUI

/// A 24-hour radial clock dial for the schedule editor. Each event is drawn as a
/// colored arc from its start time to the next event's start (wrapping past
/// midnight). Tapping an arc selects that event; the selected arc is drawn thicker
/// with a rounded start cap and a flat end cap — the start is editable via the
/// draggable knob, the end isn't (it's the next event's start). Midnight is at the
/// top, noon at the bottom.
struct RadialScheduleDial: View {
    let events: [ScheduleEvent]
    let selectedID: ScheduleEvent.ID?
    let onChangeStart: (ScheduleEvent.ID, Date) -> Void
    let onSelect: (ScheduleEvent.ID) -> Void

    private let arcWidth: CGFloat = 22
    private let selectedArcWidth: CGFloat = 32
    /// Gap between adjacent arcs, as a fraction of the full circle (~a few px).
    private let gap: CGFloat = 0.008
    private let snapMinutes = 5
    private let spaceName = "scheduleDial"

    private var sortedEvents: [ScheduleEvent] { events.sorted { $0.time < $1.time } }
    private var selectedEvent: ScheduleEvent? {
        sortedEvents.first(where: { $0.id == selectedID }) ?? sortedEvents.first
    }
    private var knobDiameter: CGFloat { selectedArcWidth + 8 }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let margin = knobDiameter / 2 + 2
            let ringD = size - 2 * margin
            let radius = ringD / 2
            let center = CGPoint(x: size / 2, y: size / 2)

            ZStack {
                Circle()
                    .stroke(SMA.fillTertiary, lineWidth: arcWidth)
                    .frame(width: ringD, height: ringD)

                // Arcs, selected drawn last so its extra thickness reads at the seams.
                ForEach(arcs) { arc in
                    Circle()
                        .trim(from: arc.start, to: arc.end)
                        .stroke(Color(hex: arc.colorHex),
                                style: StrokeStyle(lineWidth: arc.selected ? selectedArcWidth : arcWidth, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .frame(width: ringD, height: ringD)
                }

                // Rounded start caps (the editable end of each arc).
                ForEach(sortedEvents) { e in
                    let w = e.id == selectedEvent?.id ? selectedArcWidth : arcWidth
                    Circle()
                        .fill(Color(hex: e.colorHex))
                        .frame(width: w, height: w)
                        .position(point(frac(e.time), radius: radius, center: center))
                }

                Text("12AM")
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .position(point(0, radius: radius - selectedArcWidth, center: center))
                Text("12PM")
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .position(point(0.5, radius: radius - selectedArcWidth, center: center))

                centerReadout

                if let sel = selectedEvent {
                    knob(for: sel, radius: radius, center: center)
                }
            }
            .frame(width: size, height: size)
            .coordinateSpace(.named(spaceName))
            .contentShape(Circle())
            .gesture(
                SpatialTapGesture(coordinateSpace: .named(spaceName))
                    .onEnded { value in selectAt(value.location, center: center, radius: radius) }
            )
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
            .frame(width: knobDiameter, height: knobDiameter)
            .overlay(Circle().stroke(Color(hex: e.colorHex), lineWidth: 4))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            .position(p)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(spaceName))
                    .onChanged { value in
                        let newTime = time(at: value.location, center: center)
                        onChangeStart(e.id, newTime)
                    }
            )
            .accessibilityHidden(true)
    }

    // MARK: - Gestures / hit testing

    /// Selects the event whose arc contains the tapped angle, if the tap landed on
    /// the ring band (ignores taps on the center readout).
    private func selectAt(_ location: CGPoint, center: CGPoint, radius: CGFloat) {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard abs(dist - radius) <= selectedArcWidth else { return }
        if let id = eventID(atFraction: fraction(of: location, center: center)) { onSelect(id) }
    }

    private func time(at location: CGPoint, center: CGPoint) -> Date {
        var minutes = Int((fraction(of: location, center: center) * 1440).rounded())
        minutes = (minutes / snapMinutes) * snapMinutes
        minutes = ((minutes % 1440) + 1440) % 1440
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    /// Angle of a point as a day fraction (0 = midnight at top, clockwise).
    private func fraction(of location: CGPoint, center: CGPoint) -> CGFloat {
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        var a = atan2(dy, dx) + .pi / 2   // shift so top (midnight) = 0
        if a < 0 { a += 2 * .pi }
        return CGFloat(a / (2 * .pi))
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
        let selected: Bool
    }

    /// One arc per event, from its start to the next event's start; the end is inset
    /// by `gap` to leave a visible gap, and the arc is split where it crosses the
    /// midnight (top) seam. Selected arcs are sorted last so they render on top.
    private var arcs: [Arc] {
        let evs = sortedEvents
        guard !evs.isEmpty else { return [] }
        var result: [Arc] = []
        for (i, e) in evs.enumerated() {
            let selected = e.id == selectedEvent?.id
            let s = frac(e.time)
            var en = frac(evs[(i + 1) % evs.count].time)
            if evs.count == 1 { en = s + 1 }          // single event fills the ring
            else if en <= s { en += 1 }               // wraps past midnight
            let ge = en - gap
            guard ge > s else { continue }
            if ge <= 1 {
                result.append(Arc(id: result.count, start: s, end: ge, colorHex: e.colorHex, selected: selected))
            } else {
                result.append(Arc(id: result.count, start: s, end: 1, colorHex: e.colorHex, selected: selected))
                let wrapEnd = ge - 1
                if wrapEnd > 0 { result.append(Arc(id: result.count, start: 0, end: wrapEnd, colorHex: e.colorHex, selected: selected)) }
            }
        }
        return result.sorted { !$0.selected && $1.selected }
    }

    private func eventID(atFraction f: CGFloat) -> ScheduleEvent.ID? {
        let evs = sortedEvents
        guard evs.count > 1 else { return evs.first?.id }
        for (i, e) in evs.enumerated() {
            let s = frac(e.time)
            var en = frac(evs[(i + 1) % evs.count].time)
            if en <= s { en += 1 }
            if (f >= s && f < en) || (f + 1 >= s && f + 1 < en) { return e.id }
        }
        return evs.last?.id
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
