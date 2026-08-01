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
/// While it floats, its two neighbors grow to fill the vacated span (meeting at its
/// midpoint) and the floating arc carves its span out of whatever arc it sits over,
/// previewing the split live.
/// Dropping near an existing boundary instead snaps flush against it, reordering the event
/// between two arcs without splitting either (see `DialMath.breakPlacement`).
/// Tapping the time in the center opens manual entry. Hour ticks are dots on top of the arcs, with "M"
/// (midnight) at the top and "N" (noon) at the bottom.
struct RadialScheduleDial: View {
    let events: [ScheduleEvent]
    let selectedID: ScheduleEvent.ID?
    let onChangeStart: (ScheduleEvent.ID, Date) -> Void
    let onSelect: (ScheduleEvent.ID) -> Void
    /// Commits a pickup-and-move drop: `moves` are start-time changes to apply (the
    /// dragged event, plus the enclosing event when a boundary snap pushes it aside);
    /// `tailCopy` — present when the drop broke an event's interior — is a new event to
    /// insert so the broken activity resumes after the dropped one.
    let onCommitDrop: (_ moves: [(id: ScheduleEvent.ID, time: Date)], _ tailCopy: ScheduleEvent?) -> Void
    /// Tapping the start time in the center asks the host to present manual entry.
    let onRequestManualTime: (ScheduleEvent.ID) -> Void
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
    /// The one-hour floor on every piece a dial gesture produces — grip drags, drops, and
    /// splits all stop so no arc renders shorter than an hour (big enough to grab), while
    /// movement itself still steps the 15-minute grid. Drag-only: manual entry may set
    /// finer sub-hour periods.
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

    /// `proposedStart` snapped to the 15-minute grid (matching `commitBreak`), but without
    /// boundary-snap, so the floating arc tracks the finger accurately during drag.
    private var gridSnappedStart: CGFloat {
        let raw = Int((normalize(proposedStart) * 1440).rounded())
        let snapped = (((raw / snapMinutes) * snapMinutes) % 1440 + 1440) % 1440
        return CGFloat(snapped) / 1440
    }

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
                    // Each icon sits at its arc's rendered start — the float for the dragged
                    // event, the (possibly grown or trimmed) head piece for the others. An
                    // event whose arc is fully covered by the float shows no icon.
                    if !showsGrip,
                       let base = arcs.first(where: { $0.id == "\(e.id)" || $0.id == "\(e.id)-float" })?.start {
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
                    updateDrag(at: drag.location, center: center, radius: radius)
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

    private func updateDrag(at location: CGPoint, center: CGPoint, radius: CGFloat) {
        guard draggingID != nil else { return }
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = (dx * dx + dy * dy).squareRoot()
        // Ignore positions deep inside the ring — a near-center touch maps to a
        // rapidly-changing angle and would produce wild snaps on release.
        // Anything past 55% of the ring radius is treated as "off ring, hold last position."
        guard dist >= radius * 0.55 else { return }
        let f = fraction(of: location, center: center)
        proposedStart = normalize(f - grabOffset)
    }

    private func endDrag() {
        // No withAnimation — ArcBand.animatableData interpolates startFraction/endFraction
        // linearly, so a large drag (e.g. Sleep dragged across midnight) would sweep the
        // arc visibly around the ring if animated.
        guard let id = draggingID else { return }
        draggingID = nil
        let snapped = gridSnappedStart
        guard circularDistance(snapped, eventStartFraction(id)) >= 0.01 else { return }
        commitBreak(of: id, atFraction: snapped)
    }

    /// Resolve a drop via `DialMath.breakPlacement` and hand the result to the host: the
    /// dragged event moves to the resolved start; a leading boundary snap also pushes the
    /// enclosing event later; an interior break inserts a copy of the enclosing event as
    /// the resumed tail. A `nil` placement (no room) snaps the arc back with no change.
    private func commitBreak(of id: ScheduleEvent.ID, atFraction f: CGFloat) {
        let evs = sortedEvents
        guard evs.count > 1, let iD = evs.firstIndex(where: { $0.id == id }) else { return }
        let durS = cwDistance(dayMinutes(evs[iD].time), dayMinutes(evs[(iD + 1) % evs.count].time))
        let others = evs.filter { $0.id != id }.map { dayMinutes($0.time) }
        guard let p = DialMath.breakPlacement(fingerMin: Int((f * 1440).rounded()), durS: durS,
                                              others: others, minLen: minDurationMinutes,
                                              boundarySnap: snapMinutes),
              let enclosing = evs.first(where: { $0.id != id && dayMinutes($0.time) == p.brokenStart })
        else { return }
        var moves: [(id: ScheduleEvent.ID, time: Date)] = [(id, minutesToDate(p.newStart))]
        var tailCopy: ScheduleEvent?
        switch p.kind {
        case .insertLeading:
            moves.append((enclosing.id, minutesToDate(p.tailStart)))
        case .insertTrailing:
            break
        case .breakInto:
            tailCopy = ScheduleEvent(name: enclosing.name, symbol: enclosing.symbol,
                                     colorHex: enclosing.colorHex, heatTo: enclosing.heatTo,
                                     coolTo: enclosing.coolTo, time: minutesToDate(p.tailStart))
        }
        onCommitDrop(moves, tailCopy)
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
    /// previous neighbor each keep at least `minDurationMinutes`. An event sandwiched
    /// between two pieces of the same activity slides instead of resizing (the host
    /// moves its tail with it), so the room reserved ahead is the event's own duration
    /// plus the tail's floor — not just the floor.
    private func clampedStartMinutes(_ proposed: Int, for e: ScheduleEvent) -> Int {
        let evs = sortedEvents
        let n = evs.count
        guard n > 1, let idx = evs.firstIndex(where: { $0.id == e.id }) else { return proposed }
        let prevE = evs[(idx - 1 + n) % n]
        let nextE = evs[(idx + 1) % n]
        let prev = dayMinutes(prevE.time)
        if n >= 3, prevE.sameActivity(as: nextE) {
            let afterIdx = (idx + 2) % n
            let dur = cwDistance(dayMinutes(e.time), dayMinutes(nextE.time))
            let span = afterIdx == (idx - 1 + n) % n ? 1440 : cwDistance(prev, dayMinutes(evs[afterIdx].time))
            let room = span - dur
            if room >= 2 * minDurationMinutes {
                return DialMath.clampStart(proposed, prev: prev, span: room, minLen: minDurationMinutes)
            }
        }
        let span = n == 2 ? 1440 : cwDistance(prev, dayMinutes(nextE.time))   // room between neighbors
        return DialMath.clampStart(proposed, prev: prev, span: span, minLen: minDurationMinutes)
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

    /// Opacity applied to arcs that aren't being dragged (and to head/tail split previews),
    /// so the floating arc stands out. High enough that the split preview is readable.
    private let dimmedOpacity: Double = 0.45

    /// One arc per event, from its start to the next event's start. While dragging, the
    /// picked-up arc floats, its neighbors grow to fill the vacated span (meeting at its
    /// midpoint), and the floating arc carves its span out of whatever arc it sits over —
    /// a live preview of the head/tail split committed on drop. No data changes until release.
    private func arcSegments() -> [Arc] {
        let evs = sortedEvents
        guard !evs.isEmpty else { return [] }

        guard let dragID = draggingID, let iD = evs.firstIndex(where: { $0.id == dragID }) else {
            var result: [Arc] = []
            for (i, e) in evs.enumerated() {
                let selected = e.id == selectedEvent?.id
                let s = frac(e.time)
                var en = frac(evs[(i + 1) % evs.count].time)
                if evs.count == 1 { en = s + 1 } else if en <= s { en += 1 }
                let ge = en - gap
                guard ge > s else { continue }
                result.append(Arc(id: "\(e.id)", start: s, end: ge, colorHex: e.colorHex,
                                  thickness: selected ? selectedArcWidth : arcWidth, opacity: 1,
                                  floating: false, z: selected ? 2 : 0))
            }
            return result.sorted { $0.z < $1.z }
        }

        // Float position always follows the finger (15-min grid), keeping the arc's duration.
        // "-float" suffix keeps the float arc as a distinct view from the committed arc.
        // Without it, ArcBand.animatableData would interpolate between float and committed
        // positions, causing the arc to sweep visibly around the ring.
        let floatStart = gridSnappedStart
        let ds = frac(evs[iD].time)
        var den = frac(evs[(iD + 1) % evs.count].time)
        if evs.count == 1 { den = ds + 1 } else if den <= ds { den += 1 }
        let floatDuration = den - ds
        var result: [Arc] = [Arc(id: "\(dragID)-float", start: floatStart,
                                 end: floatStart + floatDuration - gap,
                                 colorHex: evs[iD].colorHex, thickness: selectedArcWidth,
                                 opacity: 1.0, floating: true, z: 3)]

        let others = evs.filter { $0.id != dragID }
        guard !others.isEmpty else { return result }
        // The dragged event's successor pulls its start back to the midpoint of the
        // vacated span, so both neighbors share the fill.
        var starts = others.map { frac($0.time) }
        if others.count > 1 {
            starts[iD % others.count] = normalize((ds + den) / 2)
        }
        for (j, e) in others.enumerated() {
            let s = starts[j]
            var en = others.count == 1 ? s + 1 : starts[(j + 1) % others.count]
            if others.count > 1, en <= s { en += 1 }
            for (k, piece) in carve(from: s, to: en - gap, holeStart: floatStart - gap,
                                    holeLength: floatDuration + gap).enumerated() {
                result.append(Arc(id: k == 0 ? "\(e.id)" : "\(e.id)-tail\(k)",
                                  start: piece.0, end: piece.1, colorHex: e.colorHex,
                                  thickness: arcWidth, opacity: dimmedOpacity,
                                  floating: false, z: 0))
            }
        }
        return result.sorted { $0.z < $1.z }
    }

    /// Pieces of the arc `[start, end)` left after removing the circular interval
    /// `[holeStart, holeStart + holeLength)` — the floating arc's span. An arc fully
    /// containing the hole yields a head and a tail; one only clipped at an edge yields a
    /// single trimmed piece; one fully covered yields nothing. Slivers too short to render
    /// cleanly are dropped.
    private func carve(from start: CGFloat, to end: CGFloat, holeStart: CGFloat,
                       holeLength: CGFloat) -> [(CGFloat, CGFloat)] {
        let length = end - start
        guard length > 0 else { return [] }
        let a = normalize(holeStart - start)
        // The hole relative to the arc's start; the shifted copy catches a hole that
        // wraps across the arc's own start.
        var cuts: [(CGFloat, CGFloat)] = []
        for base in [a - 1, a] {
            let lo = max(base, 0)
            let hi = min(base + holeLength, length)
            if hi > lo { cuts.append((lo, hi)) }
        }
        var pieces: [(CGFloat, CGFloat)] = []
        var cursor: CGFloat = 0
        for cut in cuts.sorted(by: { $0.0 < $1.0 }) {
            if cut.0 > cursor { pieces.append((cursor, cut.0)) }
            cursor = max(cursor, cut.1)
        }
        if cursor < length { pieces.append((cursor, length)) }
        return pieces.filter { $0.1 - $0.0 > gap * 2 }.map { (start + $0.0, start + $0.1) }
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
