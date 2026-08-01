import Foundation

// Pure, view-agnostic scheduling math, extracted so it can be unit-tested directly
// (the callers — AppModel's timeline and the radial dial's break-to-insert — are
// otherwise entangled with Date()/SwiftUI state).

// MARK: - Controller timeline

enum TimelineMath {
    /// The index of the period running right now, given the periods' start minutes-of-day
    /// (sorted ascending) and the current minute of day. It's the last period that has
    /// already started; before the first start we're still in the previous day's final
    /// period (wraps to the last index). `nil` when there are no periods.
    static func currentIndex(starts: [Int], now: Int) -> Int? {
        guard !starts.isEmpty else { return nil }
        return starts.lastIndex { $0 <= now } ?? (starts.count - 1)
    }

    /// The indices of the periods that still start later today.
    static func upcomingIndices(starts: [Int], now: Int) -> [Int] {
        starts.indices.filter { starts[$0] > now }
    }
}

// MARK: - Radial dial break-to-insert

enum DialMath {
    /// Clockwise distance in minutes from `a` to `b` around the 24h (1440-minute) ring.
    static func cwDistance(_ a: Int, _ b: Int) -> Int { ((b - a) % 1440 + 1440) % 1440 }

    /// Round `minutes` to the nearest multiple of `snap`, wrapped into 0..<1440. Every start
    /// time (dial drag, manual entry, editor) passes through this so periods land on the grid.
    static func snapToGrid(_ minutes: Int, snap: Int) -> Int {
        let m = ((minutes % 1440) + 1440) % 1440
        let r = Int((Double(m) / Double(snap)).rounded()) * snap
        return ((r % 1440) + 1440) % 1440
    }

    /// Clamp a proposed start (minutes of day) so the event keeps at least `minLen` on
    /// each side of the room between its neighbors: ≥ `minLen` after `prev` and ≥ `minLen`
    /// before `prev + span`. When the room can't fit both floors, it sits in the middle.
    static func clampStart(_ proposed: Int, prev: Int, span: Int, minLen: Int) -> Int {
        let lo = minLen
        let hi = span - minLen
        guard hi >= lo else { return (prev + span / 2) % 1440 }
        return (prev + min(max(cwDistance(prev, proposed), lo), hi)) % 1440
    }

    /// The arc in `others` (sorted, distinct start minutes) whose span encloses `minute`,
    /// as `(start, length)` in minutes. A lone arc spans the whole ring.
    static func enclosing(_ minute: Int, others: [Int]) -> (start: Int, length: Int)? {
        let n = others.count
        guard n > 0 else { return nil }
        if n == 1 { return (others[0], 1440) }
        for (i, start) in others.enumerated() {
            let length = cwDistance(start, others[(i + 1) % n])
            if cwDistance(start, minute) < length { return (start, length) }
        }
        let start = others[0]
        return (start, cwDistance(start, others[1]))
    }

    /// How a drop resolves against the enclosing arc.
    /// - `breakInto`: the finger is in the arc's interior — split it into a kept head, the
    ///   dropped event, and a copied tail (a new event is created for the tail).
    /// - `insertLeading`: the finger is snapped to the arc's leading boundary — the dropped
    ///   event slots in flush at the boundary and pushes the enclosing arc later (no copy;
    ///   the enclosing event just moves). `head` is 0.
    /// - `insertTrailing`: the finger is snapped to the arc's trailing boundary — the dropped
    ///   event slots in flush at the end (no copy); the enclosing arc keeps the whole head.
    enum BreakKind { case breakInto, insertLeading, insertTrailing }

    /// Where dropping a dragged event of length `durS` at `fingerMin` lands within the
    /// enclosing arc. When the finger is within `boundarySnap` of either boundary the drop
    /// snaps flush against it (a reorder — the neighbor donates the time, no event copied);
    /// otherwise the arc breaks into a kept head + a copied tail, keeping head, dragged, and
    /// tail each ≥ `minLen`. Returns the resolution `kind`, the enclosing arc's `brokenStart`,
    /// the dragged event's `newStart`, the tail/next-boundary `tailStart` (all wrapped into
    /// 0..<1440), plus the raw `head` length and enclosing `length` (for the live preview's
    /// geometry). `nil` when the finger isn't over a breakable arc or there isn't room.
    static func breakPlacement(fingerMin: Int, durS: Int, others: [Int], minLen: Int,
                               boundarySnap: Int = 0)
        -> (kind: BreakKind, brokenStart: Int, newStart: Int, tailStart: Int, head: Int, length: Int)? {
        guard let target = enclosing(fingerMin, others: others) else { return nil }
        let length = target.length
        let rawHead = cwDistance(target.start, fingerMin)
        // A boundary insert only needs the single remaining piece to keep the minimum.
        let canBoundary = length >= durS + minLen
        if canBoundary && rawHead <= boundarySnap {
            let newStart = target.start % 1440
            return (.insertLeading, target.start, newStart, (newStart + durS) % 1440, 0, length)
        }
        if canBoundary && rawHead >= length - boundarySnap {
            let head = length - durS
            let newStart = (target.start + head) % 1440
            return (.insertTrailing, target.start, newStart, (newStart + durS) % 1440, head, length)
        }
        guard length >= 2 * minLen + durS else { return nil }
        let head = min(max(rawHead, minLen), length - minLen - durS)
        let newStart = (target.start + head) % 1440
        return (.breakInto, target.start, newStart, (newStart + durS) % 1440, head, length)
    }
}
