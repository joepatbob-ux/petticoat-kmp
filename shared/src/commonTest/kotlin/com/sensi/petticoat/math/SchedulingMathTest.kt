package com.sensi.petticoat.math

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SchedulingMathTest {
    private val starts = listOf(360, 480, 1020, 1320)

    @Test
    fun currentIndexPicksLastStarted() {
        assertEquals(1, TimelineMath.currentIndex(starts, 600))
        assertEquals(0, TimelineMath.currentIndex(starts, 360))
        assertEquals(3, TimelineMath.currentIndex(starts, 1439))
    }

    @Test
    fun currentIndexBeforeFirstWrapsToLast() {
        assertEquals(3, TimelineMath.currentIndex(starts, 180))
    }

    @Test
    fun currentIndexEmptyIsNull() {
        assertNull(TimelineMath.currentIndex(emptyList(), 600))
    }

    @Test
    fun upcomingAreLaterToday() {
        assertEquals(listOf(2, 3), TimelineMath.upcomingIndices(starts, 600))
        assertEquals(listOf(0, 1, 2, 3), TimelineMath.upcomingIndices(starts, 180))
        assertEquals(emptyList(), TimelineMath.upcomingIndices(starts, 1320))
    }

    @Test
    fun cwDistanceWrapsPastMidnight() {
        assertEquals(120, DialMath.cwDistance(360, 480))
        assertEquals(120, DialMath.cwDistance(1380, 60))
        assertEquals(0, DialMath.cwDistance(100, 100))
    }

    @Test
    fun enclosingFindsContainingArc() {
        val others = listOf(360, 480, 1020)
        val e = DialMath.enclosing(600, others)
        assertEquals(480, e?.start)
        assertEquals(540, e?.length)
    }

    @Test
    fun enclosingWrapsPastMidnight() {
        val others = listOf(360, 480, 1020)
        val e = DialMath.enclosing(1200, others)
        assertEquals(1020, e?.start)
        assertEquals(780, e?.length)
    }

    @Test
    fun enclosingLoneArcSpansRing() {
        val e = DialMath.enclosing(700, listOf(500))
        assertEquals(500, e?.start)
        assertEquals(1440, e?.length)
    }

    @Test
    fun breakPlacementSplitsEnclosingArc() {
        val p = DialMath.breakPlacement(600, 120, listOf(360, 480, 1020), 60)
        assertEquals(DialMath.BreakKind.BreakInto, p?.kind)
        assertEquals(480, p?.brokenStart)
        assertEquals(600, p?.newStart)
        assertEquals(720, p?.tailStart)
        assertEquals(120, p?.head)
        assertEquals(540, p?.length)
    }

    @Test
    fun boundarySnapInsertsAtLeadingEdge() {
        val p = DialMath.breakPlacement(490, 120, listOf(360, 480, 1020), 60, boundarySnap = 24)
        assertEquals(DialMath.BreakKind.InsertLeading, p?.kind)
        assertEquals(0, p?.head)
        assertEquals(480, p?.newStart)
        assertEquals(600, p?.tailStart)
    }

    @Test
    fun boundarySnapInsertsAtTrailingEdge() {
        val p = DialMath.breakPlacement(1010, 120, listOf(360, 480, 1020), 60, boundarySnap = 24)
        assertEquals(DialMath.BreakKind.InsertTrailing, p?.kind)
        assertEquals(420, p?.head)
        assertEquals(900, p?.newStart)
        assertEquals(1020, p?.tailStart)
    }

    @Test
    fun breakPlacementClampsHeadToMinimum() {
        val p = DialMath.breakPlacement(490, 120, listOf(360, 480, 1020), 60)
        assertEquals(60, p?.head)
        assertEquals(540, p?.newStart)
        assertEquals(660, p?.tailStart)
    }

    @Test
    fun breakPlacementClampsHeadAtTailLimit() {
        val p = DialMath.breakPlacement(1000, 120, listOf(360, 480, 1020), 60)
        assertEquals(360, p?.head)
        assertEquals(840, p?.newStart)
    }
}
