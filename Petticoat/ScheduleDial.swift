import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A 24-hour radial clock dial for the schedule editor. Each event is drawn as a
/// colored arc from its start time to the next event's start (wrapping past
/// midnight), with evenly rounded ends. Tapping an arc selects that event; the
/// selected arc is drawn thicker — its start is editable via the draggable grip, the
/// end isn't (it's the next event's start). Press-and-hold an arc to pick it up, then
/// drag it around the ring: it keeps its own duration and, on drop, is inserted at the
/// finger — breaking whichever event encloses it into a kept head and a copied tail, so
/// that activity resumes after the inserted one (every piece stays ≥ the minimum length).
/// Tapping the time in the center opens manual entry. Hour ticks are dots on top of the arcs, with "M"
/// (midnight) at the top and "N" (noon) at the bottom.
struct RadialScheduleDial: View {
    let events: [ScheduleEvent]
    let selectedID: ScheduleEvent.ID?
    let onChangeStart: (ScheduleEvent.ID, Date) -> Void
    let onSelect: (ScheduleEvent.ID) -> Void
    /// Tapping the start time in the center asks the host to present manual entry.
    let onRequestManualTime: (ScheduleEvent.ID) -> Void
    /// Insert-by-breaking on drop: (draggedID, its new start, the event being broken,
    /// the tail copy's start). The host moves the dragged event and inserts a copy of the
    /// broken event so its activity resumes after the inserted one.
    let onBreak: (ScheduleEvent.ID, Date, ScheduleEvent.ID, Date) -> Void

    /// Neutral background band; drawn thicker than the arcs so they sit inset within it.
    private let trackWidth: CGFloat = 48
    private let arcWidth: CGFloat = 26
    private let selectedArcWidth: CGFloat = 40
    /// Gap between adjacent arcs, as a fraction of the full circle (~a few px).
    private let gap: CGFloat = 0.006
    /// Fixed corner radius applied to every arc corner, so all arcs round identically.
    private let cornerRadius: CGFloat = 11
    private let snapMinutes = 15
    private let hourMarkerOpacity: CGFloat = 0.62
    private let hourMarkerFadeFraction: CGFloat = 0.018
    private let gripMarkerFadeFraction: CGFloat = 0.024
    private let gripTickSpreadFraction: CGFloat = 0.005
    /// Visual floor for a period: the scrubber can't drag a period shorter than an hour,
    /// so arcs stay large enough to read. Manual time entry bypasses this and still
    /// allows 15-minute granularity for finer sub-hour periods.
    private let minDurationMinutes = 60
    private let spaceName = "scheduleDial"

    // MARK: - Drag-to-reorder state
    /// The event currently "picked up" by a press-and-hold, or nil when nothing is being
    /// dragged. While set, that event's arc floats under the finger and its neighbors
    /// swap around it instead of following the model's normal layout.
    @State private var draggingID: ScheduleEvent.ID?
    /// Angular offset (day fractions) between the finger and the dragged arc's start at
    /// pickup, so the arc doesn't jump when grabbed away from its leading edge.
    @State private var grabOffset: CGFloat = 0
    /// The dragged arc's live start position (day fraction) following the finger.
    @State private var proposedStart: CGFloat = 0

    private var sortedEvents: [ScheduleEvent] { events.sorted { $0.time < $1.time } }
    private var selectedEvent: ScheduleEvent? {
        sortedEvents.first(where: { $0.id == selectedID }) ?? sortedEvents.first
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let margin = trackWidth / 2 + 8
            let ringD = size - 2 * margin
            let radius = ringD / 2
            let center = CGPoint(x: size / 2, y: size / 2)
            let arcs = arcSegments()
            let gripFraction = selectedEvent.map { frac($0.time) + knobInsetFraction(radius: radius) }

            ZStack {
                Circle()
                    .stroke(SMA.fillTertiary, lineWidth: trackWidth)
                    .frame(width: ringD, height: ringD)

                // Arcs with evenly rounded ends. The corner radius is fixed (not
                // thickness-relative) so every arc rounds identically regardless of width.
                // A picked-up arc floats with a drop shadow. Hit testing is handled by the
                // single gesture on the whole dial (below), which figures out the touched
                // arc from the press location — more reliable inside a List than per-arc
                // gestures on stacked, full-size shapes.
                ForEach(arcs) { arc in
                    ArcBand(startFraction: arc.start, endFraction: arc.end, radius: radius,
                            thickness: arc.thickness, cornerRadius: cornerRadius)
                        .fill(Color(hex: arc.colorHex).opacity(arc.opacity))
                        .frame(width: size, height: size)
                        .shadow(color: .black.opacity(arc.floating ? 0.45 : 0),
                                radius: arc.floating ? 9 : 0, y: arc.floating ? 3 : 0)
                        .allowsHitTesting(false)
                }

                // Hour ticks on top of the arcs: a dot at each hour, with M (midnight)
                // at the top and N (noon) at the bottom in place of those two dots.
                ForEach(0..<24, id: \.self) { h in
                    if h != 0 && h != 12 {
                        let opacity = markerOpacity(at: CGFloat(h) / 24, arcs: arcs, gripFraction: gripFraction)
                        Circle()
                            .fill(.white.opacity(opacity))
                            .frame(width: 3, height: 3)
                            .offset(y: -radius)
                            .rotationEffect(.degrees(Double(h) / 24 * 360))
                    }
                }
                Text("M")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(markerOpacity(at: 0, arcs: arcs, gripFraction: gripFraction, minimumOpacity: 0.35)))
                    .position(x: center.x, y: center.y - radius)
                Text("N")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white.opacity(markerOpacity(at: 0.5, arcs: arcs, gripFraction: gripFraction, minimumOpacity: 0.35)))
                    .position(x: center.x, y: center.y + radius)

                // A tiny event icon at each arc's start. The selected arc shows the
                // draggable grip in its place (below); every other arc shows its icon, and
                // a dragged arc's icon travels with it. Icons don't take touches — selection
                // still goes through the dial's tap gesture.
                ForEach(sortedEvents) { e in
                    let showsGrip = (e.id == selectedEvent?.id && draggingID == nil)
                    if !showsGrip {
                        // The dragged icon must sit at the arc's rendered start — the
                        // previewed break gap (floatStart) when over a breakable arc, else
                        // the finger — so the icon and its arc never drift apart.
                        let base = (e.id == draggingID) ? (proposedBreak?.floatStart ?? proposedStart) : frac(e.time)
                        let f = base + knobInsetFraction(radius: radius)
                        let dimmed = draggingID != nil && e.id != draggingID
                        Image(systemName: e.symbol)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white.opacity(dimmed ? dimmedOpacity : 1))
                            .position(point(f, radius: radius, center: center))
                            .allowsHitTesting(false)
                    }
                }

                centerReadout

                // The start grip is only for fine-tuning a start time; hide it while an
                // arc is being dragged as a whole so the two gestures don't overlap.
                if let sel = selectedEvent, draggingID == nil {
                    knob(for: sel, radius: radius, center: center)
                }
            }
            .frame(width: size, height: size)
            .coordinateSpace(.named(spaceName))
            .contentShape(Circle())
            // Tap selects immediately. It runs simultaneously with the reorder gesture so
            // it doesn't wait for the long-press to fail first — long-press is only for
            // picking up and rearranging arcs.
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .named(spaceName))
                    .onEnded { value in selectAt(value.location, center: center, radius: radius) }
            )
            .gesture(reorderGesture(center: center, radius: radius))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(dialAccessibilityLabel)
    }

    // MARK: - Center readout

    private var centerReadout: some View {
        VStack(spacing: 3) {
            if let e = selectedEvent {
                Image(systemName: e.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color(hex: e.colorHex))
                    .frame(width: 44, height: 44)
                Text("\(e.name.uppercased()) START")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(SMA.labelSecondary)
                    .frame(height: 14)
                Button {
                    onRequestManualTime(e.id)
                } label: {
                    Text(e.timeText)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(SMA.labelPrimary)
                        .monospacedDigit()
                        .frame(height: 40)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Start time \(e.timeText)")
                .accessibilityHint("Enter a start time")
                Text(endsAt(e).map { "ends at \($0)" } ?? "")
                    .font(.caption2)
                    .foregroundStyle(SMA.labelSecondary)
                    .frame(height: 14)
            }
        }
        .multilineTextAlignment(.center)
    }

    // MARK: - Knob

    private func knob(for e: ScheduleEvent, radius: CGFloat, center: CGPoint) -> some View {
        // Tuck the grip forward from the start edge so it clears the rounded corner and
        // sits fully inside the arc band instead of straddling the edge. The drag maps the
        // pointer back by the same inset, so grabbing the grip doesn't jump the time.
        let inset = knobInsetFraction(radius: radius)
        let f = frac(e.time) + inset
        let p = point(f, radius: radius, center: center)
        return ZStack {
            ForEach([-gripTickSpreadFraction, gripTickSpreadFraction], id: \.self) { offset in
                let tickFraction = f + offset
                Capsule()
                    .fill(.white)
                    .frame(width: 3.5, height: 18)
                    .rotationEffect(.degrees(Double(tickFraction) * 360))
                    .position(point(tickFraction, radius: radius, center: center))
            }

            Circle()
                .fill(.white.opacity(0.001))
                .frame(width: 46, height: 46)
                .contentShape(Circle())
                .position(p)
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .named(spaceName))
                        .onChanged { value in
                            let newTime = time(at: value.location, center: center, for: e, insetFraction: inset)
                            onChangeStart(e.id, newTime)
                        }
                )
        }
        .frame(width: center.x * 2, height: center.y * 2)
        .accessibilityHidden(true)
    }

    // MARK: - Drag-to-reorder

    /// Press-and-hold anywhere on the ring band to pick up the arc under the finger, then
    /// drag it around the ring. The arc keeps its own duration and floats under the finger;
    /// on release it is inserted at the drop point, breaking the enclosing event into a
    /// kept head + a copied tail (see `commitBreak`).
    private func reorderGesture(center: CGPoint, radius: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.28)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(spaceName)))
            .onChanged { value in
                if case .second(true, let drag?) = value {
                    if draggingID == nil {
                        beginDrag(at: drag.startLocation, center: center, radius: radius)
                    }
                    updateDrag(at: drag.location, center: center)
                }
            }
            .onEnded { _ in endDrag() }
    }

    private func beginDrag(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        // Only pick up if the hold landed on the ring band, over an actual arc.
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = (dx * dx + dy * dy).squareRoot()
        guard abs(dist - radius) <= selectedArcWidth,
              let id = eventID(atFraction: fraction(of: location, center: center)) else { return }
        onSelect(id)
        let start = eventStartFraction(id)
        let f = fraction(of: location, center: center)
        grabOffset = f - start
        proposedStart = normalize(f - grabOffset)
        // Animate the lift + dim of the other arcs; the arc position itself tracks the
        // finger unanimated so it stays glued to the touch.
        withAnimation(.easeOut(duration: 0.14)) { draggingID = id }
        haptic()
    }

    private func updateDrag(at location: CGPoint, center: CGPoint) {
        guard draggingID != nil else { return }
        let f = fraction(of: location, center: center)
        proposedStart = normalize(f - grabOffset)
    }

    private func endDrag() {
        commitBreak()
        // Drop animation; if nothing was committed the arc glides back to its origin.
        withAnimation(.snappy(duration: 0.25)) { draggingID = nil }
    }

    /// On drop, insert the dragged event at the finger position by breaking whichever
    /// event now encloses it into a kept head + a copied tail, preserving the dragged
    /// event's own length and keeping every resulting piece ≥ `minDurationMinutes`.
    /// Does nothing (the arc glides home) when there isn't room or it barely moved.
    private func commitBreak() {
        guard let id = draggingID else { return }
        let evs = sortedEvents
        guard evs.count >= 2, let s = evs.first(where: { $0.id == id }),
              let iS = evs.firstIndex(where: { $0.id == id }) else { return }

        // Ignore near-stationary drops so a plain press-and-release doesn't reshuffle.
        guard circularDistance(normalize(proposedStart), frac(s.time)) >= 0.01 else { return }

        // The dragged event's own length (minutes), preserved through the move.
        let durS = cwDistance(dayMinutes(s.time), dayMinutes(evs[(iS + 1) % evs.count].time))

        // Snap the finger position to the minute grid.
        var startMin = Int((normalize(proposedStart) * 1440).rounded())
        startMin = (((startMin / snapMinutes) * snapMinutes) % 1440 + 1440) % 1440

        // The partition as it looks with the dragged event lifted out (its previous
        // neighbor fills the vacated slot), so we break the event that truly encloses it.
        let others = evs.filter { $0.id != id }.sorted { $0.time < $1.time }
        guard let placement = DialMath.breakPlacement(fingerMin: startMin, durS: durS,
                                                       others: others.map { dayMinutes($0.time) },
                                                       minLen: minDurationMinutes),
              placement.newStart != dayMinutes(s.time),
              let broken = others.first(where: { dayMinutes($0.time) == placement.brokenStart }) else { return }

        onBreak(id, minutesToDate(placement.newStart), broken.id, minutesToDate(placement.tailStart))
    }

    private func eventStartFraction(_ id: ScheduleEvent.ID) -> CGFloat {
        guard let e = events.first(where: { $0.id == id }) else { return 0 }
        return frac(e.time)
    }

    /// Wrap a day fraction into [0, 1).
    private func normalize(_ f: CGFloat) -> CGFloat { f - floor(f) }

    private func minutesToDate(_ minutes: Int) -> Date {
        let m = ((minutes % 1440) + 1440) % 1440
        return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
    }

    private func haptic() {
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        #endif
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

    private func time(at location: CGPoint, center: CGPoint, for e: ScheduleEvent, insetFraction: CGFloat) -> Date {
        var f = fraction(of: location, center: center) - insetFraction
        f -= floor(f)   // wrap into 0..<1
        var minutes = Int((f * 1440).rounded())
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
    private func cwDistance(_ a: Int, _ b: Int) -> Int { DialMath.cwDistance(a, b) }

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

    private func knobInsetFraction(radius: CGFloat) -> CGFloat {
        radius > 0 ? (cornerRadius + 5) / (2 * .pi * radius) : 0
    }

    private func markerOpacity(
        at fraction: CGFloat,
        arcs: [Arc],
        gripFraction: CGFloat?,
        minimumOpacity: CGFloat = 0
    ) -> CGFloat {
        let nearestEdge = arcs.reduce(CGFloat.greatestFiniteMagnitude) { nearest, arc in
            min(nearest, circularDistance(fraction, arc.start), circularDistance(fraction, arc.end))
        }
        let edgeFade = min(max(nearestEdge / hourMarkerFadeFraction, 0), 1)
        let gripFade: CGFloat
        if let gripFraction {
            let distanceFromGrip = circularDistance(fraction, gripFraction)
            gripFade = min(max(distanceFromGrip / gripMarkerFadeFraction, 0), 1)
        } else {
            gripFade = 1
        }
        return max(minimumOpacity, hourMarkerOpacity * edgeFade) * gripFade
    }

    private func circularDistance(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
        let d = abs((a - b) - floor(a - b))
        return min(d, 1 - d)
    }

    private struct Arc: Identifiable {
        let id: String
        let start: CGFloat
        let end: CGFloat
        let colorHex: UInt
        let thickness: CGFloat
        let opacity: Double
        /// True for the solid arc that's picked up and floating under the finger.
        let floating: Bool
        /// Stacking priority: higher renders on top.
        let z: Int
    }

    /// Opacity applied to the arcs that aren't being dragged, so the picked-up arc stands
    /// out while moving.
    private let dimmedOpacity: Double = 0.3

    /// Geometry (day fractions) of the live break preview while dragging: the enclosing
    /// event split into a kept head + a copied tail, with the dragged arc between them.
    private struct BreakPreview {
        let brokenID: ScheduleEvent.ID
        let headStart: CGFloat
        let floatStart: CGFloat
        let tailStart: CGFloat
        let tailEnd: CGFloat
    }

    /// The break that would result from dropping right now — nil when the finger isn't
    /// over a breakable arc or there's no room for head + dragged + tail (each ≥ min).
    /// Continuous (not 15-min snapped) so the preview tracks the finger smoothly; the
    /// actual commit in `commitBreak` snaps to the grid.
    private var proposedBreak: BreakPreview? {
        guard let id = draggingID else { return nil }
        let evs = sortedEvents
        guard evs.count >= 2, let iS = evs.firstIndex(where: { $0.id == id }) else { return nil }
        let durS = cwDistance(dayMinutes(evs[iS].time), dayMinutes(evs[(iS + 1) % evs.count].time))
        let fingerMin = Int((Double(normalize(proposedStart)) * 1440).rounded())
        let others = evs.filter { $0.id != id }.sorted { $0.time < $1.time }
        guard let placement = DialMath.breakPlacement(fingerMin: fingerMin, durS: durS,
                                                       others: others.map { dayMinutes($0.time) },
                                                       minLen: minDurationMinutes),
              let broken = others.first(where: { dayMinutes($0.time) == placement.brokenStart }) else { return nil }
        let tX = CGFloat(placement.brokenStart)
        return BreakPreview(
            brokenID: broken.id,
            headStart: tX / 1440,
            floatStart: (tX + CGFloat(placement.head)) / 1440,
            tailStart: (tX + CGFloat(placement.head + durS)) / 1440,
            tailEnd: (tX + CGFloat(placement.length)) / 1440
        )
    }

    /// One arc per event, from its start to the next event's start; the end is inset
    /// by `gap` to leave a visible gap. `end` may exceed 1 when the arc wraps past
    /// midnight — `ArcBand` renders it as one continuous band.
    ///
    /// While dragging, the others dim in place, the enclosing event splits into a dimmed
    /// head + copied tail (see `proposedBreak`), and the solid dragged arc floats in the
    /// gap between them — a live preview of the drop. Higher-`z` arcs render on top.
    private func arcSegments() -> [Arc] {
        let evs = sortedEvents
        guard !evs.isEmpty else { return [] }
        let dragging = draggingID != nil
        let preview = proposedBreak
        var result: [Arc] = []
        for (i, e) in evs.enumerated() {
            let selected = e.id == selectedEvent?.id
            let s = frac(e.time)
            var en = frac(evs[(i + 1) % evs.count].time)
            if evs.count == 1 { en = frac(e.time) + 1 }   // single event fills the ring
            else if en <= s { en += 1 }               // wraps past midnight
            let ge = en - gap

            if e.id == draggingID {
                // Solid dragged arc: snapped into the previewed break gap, or glued to the
                // finger when no break is possible.
                let fs = preview?.floatStart ?? proposedStart
                let fe = preview.map { $0.tailStart - gap } ?? (fs + (en - s) - gap)
                result.append(Arc(id: "\(e.id)-float", start: fs, end: fe,
                                  colorHex: e.colorHex, thickness: selectedArcWidth, opacity: 1,
                                  floating: true, z: 3))
            } else if let preview, e.id == preview.brokenID {
                // The enclosing event previews its split: kept head + copied tail.
                result.append(Arc(id: "\(e.id)-head", start: preview.headStart, end: preview.floatStart - gap,
                                  colorHex: e.colorHex, thickness: arcWidth, opacity: dimmedOpacity,
                                  floating: false, z: 0))
                result.append(Arc(id: "\(e.id)-tail", start: preview.tailStart, end: preview.tailEnd - gap,
                                  colorHex: e.colorHex, thickness: arcWidth, opacity: dimmedOpacity,
                                  floating: false, z: 0))
            } else {
                guard ge > s else { continue }
                let thickness = (selected && !dragging) ? selectedArcWidth : arcWidth
                result.append(Arc(id: "\(e.id)", start: s, end: ge, colorHex: e.colorHex,
                                  thickness: thickness, opacity: dragging ? dimmedOpacity : 1,
                                  floating: false, z: (selected && !dragging) ? 2 : 0))
            }
        }
        return result.sorted { $0.z < $1.z }
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
/// clockwise), centered on `radius` with the given `thickness`. All four corners round
/// by the same `cornerRadius`. `endFraction` may exceed `startFraction` by more than 1
/// to wrap the seam.
private struct ArcBand: Shape {
    var startFraction: CGFloat
    var endFraction: CGFloat
    var radius: CGFloat
    var thickness: CGFloat
    var cornerRadius: CGFloat

    /// Animate the arc's endpoints so a swap or drop glides into place.
    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(startFraction, endFraction) }
        set {
            startFraction = newValue.first
            endFraction = newValue.second
        }
    }

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
