package com.sensi.petticoat.math

/**
 * Pure, view-agnostic scheduling math — port of `SchedulingMath.swift`.
 * Extracted so timeline + radial-dial logic can be unit-tested without UI.
 */
object TimelineMath {
    /**
     * Index of the period running right now given sorted start minutes-of-day
     * and the current minute of day. Last period that has already started;
     * before the first start wraps to the last index. `null` when empty.
     */
    fun currentIndex(starts: List<Int>, now: Int): Int? {
        if (starts.isEmpty()) return null
        val idx = starts.indexOfLast { it <= now }
        return if (idx >= 0) idx else starts.lastIndex
    }

    /** Indices of periods that still start later today. */
    fun upcomingIndices(starts: List<Int>, now: Int): List<Int> =
        starts.indices.filter { starts[it] > now }
}

object DialMath {
    /** Clockwise distance in minutes from `a` to `b` around the 24h ring. */
    fun cwDistance(a: Int, b: Int): Int = ((b - a) % 1440 + 1440) % 1440

    /** Round `minutes` to nearest multiple of `snap`, wrapped into 0..<1440. */
    fun snapToGrid(minutes: Int, snap: Int): Int {
        val m = ((minutes % 1440) + 1440) % 1440
        val r = kotlin.math.round(m.toDouble() / snap).toInt() * snap
        return ((r % 1440) + 1440) % 1440
    }

    /**
     * Clamp a proposed start so the event keeps at least `minLen` on each side
     * of the room between neighbors.
     */
    fun clampStart(proposed: Int, prev: Int, span: Int, minLen: Int): Int {
        val lo = minLen
        val hi = span - minLen
        if (hi < lo) return (prev + span / 2) % 1440
        return (prev + cwDistance(prev, proposed).coerceIn(lo, hi)) % 1440
    }

    data class Arc(val start: Int, val length: Int)

    /** Arc in `others` whose span encloses `minute`. */
    fun enclosing(minute: Int, others: List<Int>): Arc? {
        val n = others.size
        if (n == 0) return null
        if (n == 1) return Arc(others[0], 1440)
        for (i in others.indices) {
            val start = others[i]
            val length = cwDistance(start, others[(i + 1) % n])
            if (cwDistance(start, minute) < length) return Arc(start, length)
        }
        val start = others[0]
        return Arc(start, cwDistance(start, others[1]))
    }

    enum class BreakKind { BreakInto, InsertLeading, InsertTrailing }

    data class BreakPlacement(
        val kind: BreakKind,
        val brokenStart: Int,
        val newStart: Int,
        val tailStart: Int,
        val head: Int,
        val length: Int,
    )

    /**
     * Where dropping a dragged event of length `durS` at `fingerMin` lands within
     * the enclosing arc. See Swift `DialMath.breakPlacement` for full semantics.
     */
    fun breakPlacement(
        fingerMin: Int,
        durS: Int,
        others: List<Int>,
        minLen: Int,
        boundarySnap: Int = 0,
    ): BreakPlacement? {
        val target = enclosing(fingerMin, others) ?: return null
        val length = target.length
        val rawHead = cwDistance(target.start, fingerMin)
        val canBoundary = length >= durS + minLen
        if (canBoundary && rawHead <= boundarySnap) {
            val newStart = target.start % 1440
            return BreakPlacement(
                BreakKind.InsertLeading, target.start, newStart,
                (newStart + durS) % 1440, 0, length,
            )
        }
        if (canBoundary && rawHead >= length - boundarySnap) {
            val head = length - durS
            val newStart = (target.start + head) % 1440
            return BreakPlacement(
                BreakKind.InsertTrailing, target.start, newStart,
                (newStart + durS) % 1440, head, length,
            )
        }
        if (length < 2 * minLen + durS) return null
        val head = rawHead.coerceIn(minLen, length - minLen - durS)
        val newStart = (target.start + head) % 1440
        return BreakPlacement(
            BreakKind.BreakInto, target.start, newStart,
            (newStart + durS) % 1440, head, length,
        )
    }
}
