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

    /// Where dropping a dragged event of length `durS` at `fingerMin` breaks the enclosing
    /// arc into a kept head + a copied tail, keeping head, dragged, and tail each
    /// ≥ `minLen`. Returns the enclosing arc's `brokenStart`, the dragged event's clamped
    /// `newStart`, the tail copy's `tailStart` (all wrapped into 0..<1440), plus the raw
    /// `head` length and enclosing `length` (for the live preview's geometry). `nil` when
    /// the finger isn't over a breakable arc or there isn't room for all three pieces.
    static func breakPlacement(fingerMin: Int, durS: Int, others: [Int], minLen: Int)
        -> (brokenStart: Int, newStart: Int, tailStart: Int, head: Int, length: Int)? {
        guard let target = enclosing(fingerMin, others: others) else { return nil }
        guard target.length >= 2 * minLen + durS else { return nil }
        let head = min(max(cwDistance(target.start, fingerMin), minLen), target.length - minLen - durS)
        let newStart = (target.start + head) % 1440
        let tailStart = (newStart + durS) % 1440
        return (target.start, newStart, tailStart, head, target.length)
    }
}
