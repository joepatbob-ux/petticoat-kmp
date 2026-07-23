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

    /// Neutral background band; drawn thicker than the arcs so they sit inset within it.
    private let trackWidth: CGFloat = 46
    private let arcWidth: CGFloat = 24
    private let selectedArcWidth: CGFloat = 36
    /// Gap between adjacent arcs, as a fraction of the full circle (~a few px).
    private let gap: CGFloat = 0.006
    /// Corner radius on the arcs' flat ends.
    private let cornerRadius: CGFloat = 4
    private let snapMinutes = 15
    /// Shortest allowed period; a dragged start can't crowd its neighbors past this.
    private let minDurationMinutes = 30
    private let spaceName = "scheduleDial"

    private var sortedEvents: [ScheduleEvent] { events.sorted { $0.time < $1.time } }
    private var selectedEvent: ScheduleEvent? {
        sortedEvents.first(where: { $0.id == selectedID }) ?? sortedEvents.first
    }
    /// The white scrubber dot nests inside the selected arc's start cap.
    private var knobDiameter: CGFloat { selectedArcWidth - 12 }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let margin = trackWidth / 2 + 6
            let ringD = size - 2 * margin
            let radius = ringD / 2
            let center = CGPoint(x: size / 2, y: size / 2)
            // Push the selected arc's rounded start forward by its cap radius so a
            // gap still shows between it and the previous arc's (flat) end.
            let capInset = radius > 0 ? (selectedArcWidth / 2) / (2 * .pi * radius) : 0

            ZStack {
                Circle()
                    .stroke(SMA.fillTertiary, lineWidth: trackWidth)
                    .frame(width: ringD, height: ringD)

                // Hour marks sitting within the band: a dot every 6 hours, a thin line otherwise.
                ForEach(0..<24, id: \.self) { h in
                    let major = h % 6 == 0
                    Group {
                        if major {
                            Circle()
                                .fill(SMA.labelSecondary.opacity(0.55))
                                .frame(width: 4, height: 4)
                        } else {
                            Capsule()
                                .fill(SMA.labelSecondary.opacity(0.3))
                                .frame(width: 1.5, height: 8)
                        }
                    }
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(h) / 24 * 360))
                }

                // Arcs with softly rounded ends; selected drawn last so it reads on top.
                ForEach(arcSegments(capInset: capInset)) { arc in
                    ArcBand(startFraction: arc.start, endFraction: arc.end, radius: radius,
                            thickness: arc.selected ? selectedArcWidth : arcWidth, cornerRadius: cornerRadius)
                        .fill(Color(hex: arc.colorHex))
                        .frame(width: size, height: size)
                }

                // Only the selected arc gets a full rounded start cap.
                if let sel = selectedEvent {
                    Circle()
                        .fill(Color(hex: sel.colorHex))
                        .frame(width: selectedArcWidth, height: selectedArcWidth)
                        .position(point(frac(sel.time) + capInset, radius: radius, center: center))
                }

                centerReadout

                if let sel = selectedEvent {
                    knob(for: sel, radius: radius, center: center, capInset: capInset)
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

    private func knob(for e: ScheduleEvent, radius: CGFloat, center: CGPoint, capInset: CGFloat) -> some View {
        let p = point(frac(e.time) + capInset, radius: radius, center: center)
        return Circle()
            .fill(.white)
            .frame(width: knobDiameter, height: knobDiameter)
            .shadow(color: .black.opacity(0.25), radius: 2)
            .frame(width: 44, height: 44)          // larger, transparent drag target
            .contentShape(Circle())
            .position(p)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(spaceName))
                    .onChanged { value in
                        let newTime = time(at: value.location, center: center, for: e)
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

    private func time(at location: CGPoint, center: CGPoint, for e: ScheduleEvent) -> Date {
        var minutes = Int((fraction(of: location, center: center) * 1440).rounded())
        minutes = (minutes / snapMinutes) * snapMinutes
        minutes = ((minutes % 1440) + 1440) % 1440
        minutes = clampedStartMinutes(minutes, for: e)
        return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: Date()) ?? Date()
    }

    /// Clamp a proposed start (minutes since midnight) so the dragged event and its
    /// previous neighbor each keep at least `minDurationMinutes`.
    private func clampedStartMinutes(_ proposed: Int, for e: ScheduleEvent) -> Int {
        let evs = sortedEvents
        guard evs.count > 1, let idx = evs.firstIndex(where: { $0.id == e.id }) else { return proposed }
        let prev = dayMinutes(evs[(idx - 1 + evs.count) % evs.count].time)
        let next = dayMinutes(evs[(idx + 1) % evs.count].time)
        let span = evs.count == 2 ? 1440 : cwDistance(prev, next)   // room between neighbors
        let lo = minDurationMinutes
        let hi = span - minDurationMinutes
        guard hi >= lo else { return (prev + span / 2) % 1440 }     // no room; sit in the middle
        let d = min(max(cwDistance(prev, proposed), lo), hi)
        return (prev + d) % 1440
    }

    private func dayMinutes(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Clockwise distance in minutes from `a` to `b` around the 24h ring.
    private func cwDistance(_ a: Int, _ b: Int) -> Int { ((b - a) % 1440 + 1440) % 1440 }

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
    /// by `gap` to leave a visible gap. `end` may exceed 1 when the arc wraps past
    /// midnight — `ArcBand` renders it as one continuous band. The selected arc's
    /// start is pushed forward by `capInset` so its rounded start cap still clears
    /// the previous arc. Selected arcs are sorted last so they render on top.
    private func arcSegments(capInset: CGFloat) -> [Arc] {
        let evs = sortedEvents
        guard !evs.isEmpty else { return [] }
        var result: [Arc] = []
        for (i, e) in evs.enumerated() {
            let selected = e.id == selectedEvent?.id
            let s = frac(e.time) + (selected ? capInset : 0)
            var en = frac(evs[(i + 1) % evs.count].time)
            if evs.count == 1 { en = frac(e.time) + 1 }   // single event fills the ring
            else if en <= s { en += 1 }               // wraps past midnight
            let ge = en - gap
            guard ge > s else { continue }
            result.append(Arc(id: i, start: s, end: ge, colorHex: e.colorHex, selected: selected))
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

/// A filled annular-sector "band" between two day fractions (0 = midnight at top,
/// clockwise), centered on `radius` with the given `thickness` and lightly rounded
/// corners. `endFraction` may exceed `startFraction` by more than 1 to wrap the seam.
private struct ArcBand: Shape {
    var startFraction: CGFloat
    var endFraction: CGFloat
    var radius: CGFloat
    var thickness: CGFloat
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let ro = radius + thickness / 2
        let ri = max(radius - thickness / 2, 0.1)
        let a0 = Double(startFraction) * 2 * .pi - .pi / 2
        var a1 = Double(endFraction) * 2 * .pi - .pi / 2
        if a1 <= a0 { a1 += 2 * .pi }

        let r = min(Double(cornerRadius), Double(thickness) / 2 - 0.5)
        let half = (a1 - a0) / 2 - 0.0001
        let insetO = min(half, r / Double(ro))
        let insetI = min(half, r / Double(ri))

        func p(_ radius: CGFloat, _ ang: Double) -> CGPoint {
            CGPoint(x: c.x + radius * CGFloat(cos(ang)), y: c.y + radius * CGFloat(sin(ang)))
        }

        var path = Path()
        path.move(to: p(ro, a0 + insetO))
        path.addArc(center: c, radius: ro, startAngle: .radians(a0 + insetO), endAngle: .radians(a1 - insetO), clockwise: false)
        path.addQuadCurve(to: p(ro - CGFloat(r), a1), control: p(ro, a1))
        path.addLine(to: p(ri + CGFloat(r), a1))
        path.addQuadCurve(to: p(ri, a1 - insetI), control: p(ri, a1))
        path.addArc(center: c, radius: ri, startAngle: .radians(a1 - insetI), endAngle: .radians(a0 + insetI), clockwise: true)
        path.addQuadCurve(to: p(ri + CGFloat(r), a0), control: p(ri, a0))
        path.addLine(to: p(ro - CGFloat(r), a0))
        path.addQuadCurve(to: p(ro, a0 + insetO), control: p(ro, a0))
        path.closeSubpath()
        return path
    }
}
