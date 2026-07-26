import Testing
@testable import Petticoat

struct SchedulingMathTests {

    // Sample day: 6:00, 8:00, 17:00, 22:00 (minutes of day).
    private let starts = [360, 480, 1020, 1320]

    // MARK: TimelineMath

    @Test func currentIndexPicksLastStarted() {
        #expect(TimelineMath.currentIndex(starts: starts, now: 600) == 1)   // 10:00 → 8:00 period
        #expect(TimelineMath.currentIndex(starts: starts, now: 360) == 0)   // exactly at a start
        #expect(TimelineMath.currentIndex(starts: starts, now: 1439) == 3)  // late night → last
    }

    @Test func currentIndexBeforeFirstWrapsToLast() {
        #expect(TimelineMath.currentIndex(starts: starts, now: 180) == 3)   // 3:00 → carryover
    }

    @Test func currentIndexEmptyIsNil() {
        #expect(TimelineMath.currentIndex(starts: [], now: 600) == nil)
    }

    @Test func upcomingAreLaterToday() {
        #expect(TimelineMath.upcomingIndices(starts: starts, now: 600) == [2, 3])
        #expect(TimelineMath.upcomingIndices(starts: starts, now: 180) == [0, 1, 2, 3])
        #expect(TimelineMath.upcomingIndices(starts: starts, now: 1320) == [])  // at/after last
    }

    // MARK: DialMath.cwDistance

    @Test func cwDistanceWrapsPastMidnight() {
        #expect(DialMath.cwDistance(360, 480) == 120)
        #expect(DialMath.cwDistance(1380, 60) == 120)   // 23:00 → 01:00
        #expect(DialMath.cwDistance(100, 100) == 0)
    }

    // MARK: DialMath.enclosing

    @Test func enclosingFindsContainingArc() {
        let others = [360, 480, 1020]
        // 10:00 is inside the 8:00 arc (480 → 1020, length 540).
        let e = DialMath.enclosing(600, others: others)
        #expect(e?.start == 480)
        #expect(e?.length == 540)
    }

    @Test func enclosingWrapsPastMidnight() {
        let others = [360, 480, 1020]
        // 20:00 is inside the 17:00 arc that wraps to 6:00 (length 780).
        let e = DialMath.enclosing(1200, others: others)
        #expect(e?.start == 1020)
        #expect(e?.length == 780)
    }

    @Test func enclosingLoneArcSpansRing() {
        let e = DialMath.enclosing(700, others: [500])
        #expect(e?.start == 500)
        #expect(e?.length == 1440)
    }

    // MARK: DialMath.breakPlacement

    @Test func breakPlacementSplitsEnclosingArc() {
        let p = DialMath.breakPlacement(fingerMin: 600, durS: 120, others: [360, 480, 1020], minLen: 60)
        #expect(p?.brokenStart == 480)
        #expect(p?.newStart == 600)
        #expect(p?.tailStart == 720)
        #expect(p?.head == 120)
        #expect(p?.length == 540)
    }

    @Test func breakPlacementClampsHeadToMinimum() {
        // Finger only 10 min past the arc start → head clamps up to the 60-min minimum.
        let p = DialMath.breakPlacement(fingerMin: 490, durS: 120, others: [360, 480, 1020], minLen: 60)
        #expect(p?.head == 60)
        #expect(p?.newStart == 540)
        #expect(p?.tailStart == 660)
    }

    @Test func breakPlacementClampsHeadAtTailLimit() {
        // Finger deep in the arc → head clamps so the tail keeps its minimum (540-60-120=360).
        let p = DialMath.breakPlacement(fingerMin: 1000, durS: 120, others: [360, 480, 1020], minLen: 60)
        #expect(p?.head == 360)
        #expect(p?.newStart == 840)
    }

    @Test func breakPlacementNilWhenNoRoom() {
        // Arc for 100 is only 100 min; need 2*60 + 120 = 240.
        #expect(DialMath.breakPlacement(fingerMin: 150, durS: 120, others: [0, 100, 200], minLen: 60) == nil)
    }

    @Test func breakPlacementLoneArcWrapsTail() {
        let p = DialMath.breakPlacement(fingerMin: 700, durS: 120, others: [500], minLen: 60)
        #expect(p?.brokenStart == 500)
        #expect(p?.newStart == 700)
        #expect(p?.tailStart == 820)
        #expect(p?.length == 1440)
    }
}
