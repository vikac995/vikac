package dev.lumen.lumen

import android.graphics.RectF

/**
 * Where the Sidekick's blobs and their names go when its menu opens (build 191, "the fan and its
 * names"; the owner chose "Away from the Sidekick" and the turned fan, in the mock-up
 * https://claude.ai/artifact/7b5NvRHX4jVK8UVKfEQjoh).
 *
 * - **The fan** is an arc of seats round the Sidekick's middle, pointing into the screen from its
 *   side. Its seats keep their normal spacing (the same distance from one blob to the next as
 *   always) and stay clear of the screen's edges and of Prism's bar. Near a corner it turns away
 *   from it. If no turn fits it (the Sidekick high or low in a corner), the arc is made a little
 *   larger, its seats closer round it so that they keep their spacing: away from the corner there
 *   is more room. Made smaller only if no larger one fits either (smaller, with the same spacing,
 *   it needs more room, not less). Until 191 the seats were pushed onto the screen one by one, and
 *   near a corner two could end up on the same spot.
 * - **Up to 2.2 times as large** (from 198; 1.4 until then): with the Sidekick very low in a corner,
 *   in Prism above its bar, nothing up to 1.4 fitted, and the menu's last resort pushed each blob
 *   that was off the screen back onto it on its own, onto its neighbours (the owner's screenshot).
 * - **The last resort** (nothing fits at all) moves the whole fan as one onto the screen
 *   ([intoBounds]), so its blobs keep their spacing and never overlap (from 198).
 * - **Each name** sits on the far side of its blob, along the line from the Sidekick's middle
 *   through the blob (left of it on the right side, right of it on the left, above it for a spot
 *   at the bottom later). At most about one and a half blobs wide, ending in "…"; pushed back onto
 *   the screen, and above Prism's bar. It never covers a blob, a badge, the Sidekick or another
 *   name: if it would, it is tried beside its blob, then shorter.
 *
 * Everything is in pixels, in the menu's own place (which is the screen's).
 */
internal object FanLayout {
    /** A blob's radius, in points. */
    const val BLOB_R = 31f

    class Fan(
        val axis: Double,
        val reach: Float,
        /** How far apart one seat is from the next, in halves of a turn (as `angle()` takes it). */
        val step: Double,
        val x: FloatArray,
        val y: FloatArray,
        val overflow: Float,
        /** How far it was turned from pointing straight in, in degrees, and how much larger than usual. */
        val turned: Double,
        val grown: Float,
    )

    /** The usual distance from the Sidekick's middle to its blobs' middles. */
    fun normalReach(lensR: Float, dp: Float, names: Boolean): Float =
        if (names) Math.max(178 * dp, lensR + 75 * dp) else Math.max(156 * dp, lensR + 58 * dp)

    /** The usual angle from one seat to the next, in halves of a turn (with names off, wider, so the gap stays). */
    fun normalStep(reach: Float, dp: Float, names: Boolean): Double =
        if (names || reach <= 0f) 0.155 else (0.155 * 178.0 * dp / reach).coerceIn(0.155, 0.1769)

    /**
     * Where a blob's middle may be: clear of the screen's sides, of the status bar, and of the
     * bottom; in Prism ([barTop], in this view), of Prism's bar as well.
     */
    fun bounds(w: Float, h: Float, dp: Float, barTop: Float?): RectF {
        var bottom = h - 80 * dp
        if (barTop != null) bottom = Math.min(bottom, barTop - (BLOB_R + 14) * dp)
        val top = 78 * dp
        return RectF(45 * dp, top, Math.max(45 * dp, w - 45 * dp), Math.max(top, bottom))
    }

    private fun overflow(b: RectF, x: Float, y: Float): Float =
        Math.max(0f, b.left - x) + Math.max(0f, x - b.right) + Math.max(0f, b.top - y) + Math.max(0f, y - b.bottom)

    /** The fan for [n] blobs round a Sidekick whose middle is at [cx], [cy] and whose glass is [lensR]. */
    fun lay(w: Float, h: Float, cx: Float, cy: Float, lensR: Float, dp: Float, n: Int, names: Boolean, barTop: Float?): Fan {
        val r0 = normalReach(lensR, dp, names)
        val s0 = normalStep(r0, dp, names)
        // The usual distance between one blob's middle and the next: kept whatever the arc.
        val chord = 2 * r0 * Math.sin(Math.PI * s0 / 2).toFloat()
        val b = bounds(w, h, dp, barTop)
        val onRight = cx > w / 2f
        val inward = if (onRight) Math.PI else 0.0
        // Which way the fan turns to point further down the screen, and which way to try first.
        val down = if (onRight) -1.0 else 1.0
        val first = if (cy < h / 2f) down else -down
        val xs = FloatArray(n)
        val ys = FloatArray(n)
        var best: Fan? = null
        for (k in floatArrayOf(1f, 1.1f, 1.2f, 1.3f, 1.4f, 1.5f, 1.6f, 1.7f, 1.8f, 1.9f, 2f, 2.2f, 0.9f, 0.8f)) {
            val r = r0 * k
            // (Never so near that a blob would touch the Sidekick.)
            if (r < lensR + (BLOB_R + 12) * dp) continue
            val q = chord / (2 * r)
            if (q >= 1f) continue
            val step = 2 * Math.asin(q.toDouble()) / Math.PI
            for (j in 0..30) {
                for (way in doubleArrayOf(first, -first)) {
                    val t = inward + way * j * Math.toRadians(4.0)
                    var over = 0f
                    for (i in 0 until n) {
                        val a = t + Math.PI * step * (i - (n - 1) / 2f)
                        xs[i] = cx + r * Math.cos(a).toFloat()
                        ys[i] = cy + r * Math.sin(a).toFloat()
                        over += overflow(b, xs[i], ys[i])
                    }
                    if (best == null || over < best.overflow - 0.01f) {
                        best = Fan(t, r, step, xs.copyOf(), ys.copyOf(), over, Math.toDegrees(way * j * Math.toRadians(4.0)), k)
                    }
                    if (over == 0f) return best!!
                    if (j == 0) break
                }
            }
        }
        return best ?: Fan(inward, r0, s0, xs, ys, 0f, 0.0, 1f)
    }

    /**
     * The last resort, where no fan fits (198): the whole fan moved as one, up or down and side to
     * side, as far as it must to lie within [b]. Its blobs keep their spacing, so none can ever lie
     * on another. (Until 198 each was pushed in on its own, and could end up on its neighbour.)
     */
    fun intoBounds(xs: FloatArray, ys: FloatArray, b: RectF, count: Int = xs.size) {
        if (count == 0) return
        var minX = Float.MAX_VALUE; var maxX = -Float.MAX_VALUE
        var minY = Float.MAX_VALUE; var maxY = -Float.MAX_VALUE
        for (i in 0 until count) {
            minX = Math.min(minX, xs[i]); maxX = Math.max(maxX, xs[i])
            minY = Math.min(minY, ys[i]); maxY = Math.max(maxY, ys[i])
        }
        val dx = if (minX < b.left) b.left - minX else if (maxX > b.right) b.right - maxX else 0f
        val dy = if (maxY > b.bottom) b.bottom - maxY else if (minY < b.top) b.top - minY else 0f
        if (dx == 0f && dy == 0f) return
        for (i in 0 until count) {
            xs[i] += dx
            ys[i] += dy
        }
    }

    /** The usual gap between two neighbouring blobs (edge to edge), in pixels: the same at any size of arc. */
    fun usualGap(lensR: Float, dp: Float, names: Boolean): Float {
        val r0 = normalReach(lensR, dp, names)
        val s0 = normalStep(r0, dp, names)
        return 2 * r0 * Math.sin(Math.PI * s0 / 2).toFloat() - 2 * BLOB_R * dp
    }

    // ---- The names.

    /** A blob's name: its text as shown (shortened with "…" if it must be), and where its pill is; null rect when not shown. */
    class Name(val text: String, val rect: RectF?)

    /** The box a badge takes, round its middle at [bx], [by] (a blob's upper right), [half] wide each way; null for none. */
    class Badge(val rect: RectF?)

    /**
     * Where a blob's badge goes (204): on the blob's corner nearest the way away from the
     * Sidekick's middle at [cx], [cy] (as its name is, on its far side), 22 points out each way.
     * From a Sidekick on the right its blobs are up and to the left of it, so their badges are on
     * their upper left; from one on the left, their upper right. Until 204 always the upper right:
     * on the right side, facing the Sidekick. Straight above or below it, on the side away from
     * the screen's edge it is at ([onRight]).
     */
    fun badgeCenter(bx: Float, by: Float, cx: Float, cy: Float, onRight: Boolean, dp: Float): FloatArray {
        val dx = bx - cx
        val dy = by - cy
        val sx = if (Math.abs(dx) < 1f) (if (onRight) -1f else 1f) else Math.signum(dx)
        val sy = if (Math.abs(dy) < 1f) -1f else Math.signum(dy)
        return floatArrayOf(bx + sx * 22 * dp, by + sy * 22 * dp)
    }

    fun badgeRect(bx: Float, by: Float, cx: Float, cy: Float, onRight: Boolean, halfW: Float, dp: Float): RectF? {
        if (halfW <= 0f) return null
        val c = badgeCenter(bx, by, cx, cy, onRight, dp)
        val hh = (10.5f + 1.8f) * dp
        return RectF(c[0] - halfW, c[1] - hh, c[0] + halfW, c[1] + hh)
    }

    private fun rectCircleGap(r: RectF, x: Float, y: Float, rad: Float): Float {
        val nx = x.coerceIn(r.left, r.right)
        val ny = y.coerceIn(r.top, r.bottom)
        val inside = r.contains(x, y)
        val d = Math.hypot((x - nx).toDouble(), (y - ny).toDouble()).toFloat()
        return if (inside) -rad - Math.min(Math.min(x - r.left, r.right - x), Math.min(y - r.top, r.bottom - y)) else d - rad
    }

    private fun rectGap(a: RectF, b: RectF): Float {
        val dx = Math.max(b.left - a.right, a.left - b.right)
        val dy = Math.max(b.top - a.bottom, a.top - b.bottom)
        return if (dx < 0 && dy < 0) Math.max(dx, dy) else Math.hypot(Math.max(dx, 0f).toDouble(), Math.max(dy, 0f).toDouble()).toFloat()
    }

    /**
     * Places every blob's name. [fit] shortens a text to a width (with "…"), [wide] measures one;
     * [pillH] is a pill's height. [screen] is where a name may be: the screen less a margin, the
     * status bar, and Prism's bar.
     */
    fun names(
        cx: Float, cy: Float, lensR: Float, xs: FloatArray, ys: FloatArray, texts: List<String>, badges: List<RectF?>,
        screen: RectF, dp: Float, pillH: Float, fit: (String, Float) -> String, wide: (String) -> Float,
    ): Array<Name> {
        val n = xs.size
        val out = arrayOfNulls<Name>(n)
        val placed = ArrayList<RectF>()
        val padX = 7 * dp
        val most = 1.5f * 2 * BLOB_R * dp
        val least = 2 * BLOB_R * dp
        for (i in 0 until n) {
            val full = texts.getOrElse(i) { "" }
            if (full.isEmpty()) {
                out[i] = Name("", null)
                continue
            }
            var dx = xs[i] - cx
            var dy = ys[i] - cy
            val len = Math.hypot(dx.toDouble(), dy.toDouble()).toFloat().coerceAtLeast(1f)
            dx /= len; dy /= len
            // (How clear of everything a pill at [r] is; negative where it covers something.)
            fun clear(r: RectF): Float {
                var g = Float.MAX_VALUE
                for (j in 0 until n) g = Math.min(g, rectCircleGap(r, xs[j], ys[j], BLOB_R * dp))
                for (b in badges) if (b != null) g = Math.min(g, rectGap(r, b))
                g = Math.min(g, rectCircleGap(r, cx, cy, lensR))
                for (p in placed) g = Math.min(g, rectGap(r, p))
                return g
            }
            fun pushIn(r: RectF) {
                if (r.left < screen.left) r.offset(screen.left - r.left, 0f)
                if (r.right > screen.right) r.offset(screen.right - r.right, 0f)
                if (r.top < screen.top) r.offset(0f, screen.top - r.top)
                if (r.bottom > screen.bottom) r.offset(0f, screen.bottom - r.bottom)
            }
            var bestRect: RectF? = null
            var bestText = full
            var bestClear = -Float.MAX_VALUE
            search@ for (cap in floatArrayOf(most, least)) {
                val text = fit(full, cap - 2 * padX)
                val w = wide(text) + 2 * padX
                // 1. Along the line from the Sidekick through the blob, on its far side (the
                //    mock-up's rule); 2. straight beside it, on the side away from the Sidekick.
                for (way in 0..1) {
                    val ux = if (way == 0) dx else (if (dx < 0) -1f else 1f)
                    val uy = if (way == 0) dy else 0f
                    val px = xs[i] + ux * (BLOB_R + 8) * dp
                    val py = ys[i] + uy * (BLOB_R + 8) * dp
                    val left = if (ux < -0.35f) px - w else if (ux > 0.35f) px else px - w / 2
                    val top = if (uy < -0.35f) py - pillH else if (uy > 0.35f) py else py - pillH / 2
                    val r = RectF(left, top, left + w, top + pillH)
                    pushIn(r)
                    val c = clear(r)
                    if (c > bestClear) {
                        bestClear = c
                        bestRect = r
                        bestText = text
                    }
                    if (c >= 2 * dp) break@search
                }
            }
            out[i] = Name(bestText, bestRect)
            bestRect?.let { placed.add(it) }
        }
        @Suppress("UNCHECKED_CAST")
        return out as Array<Name>
    }

    // ---- For the test: how clear of each other everything is.

    /**
     * The smallest gap, in points, between each kind of pair (negative: they overlap), and from
     * anything to the screen's edges and to Prism's bar; with what overlaps, in words.
     */
    fun gaps(
        cx: Float, cy: Float, lensR: Float, xs: FloatArray, ys: FloatArray, names: Array<Name>, badges: List<RectF?>,
        w: Float, h: Float, barTop: Float?, dp: Float,
    ): HashMap<String, Any?> {
        val n = xs.size
        val r = BLOB_R * dp
        var blobBlob = Float.MAX_VALUE
        var nameBlob = Float.MAX_VALUE
        var nameBadge = Float.MAX_VALUE
        var nameSidekick = Float.MAX_VALUE
        var nameName = Float.MAX_VALUE
        var edge = Float.MAX_VALUE
        var bar = Float.MAX_VALUE
        // (204) Badges: how near one comes to another blob (not its own) or the Sidekick, and
        // whether each lies on its blob's outer side, away from the Sidekick's middle.
        var badgeBlob = Float.MAX_VALUE
        var badgesOuter = 0
        var badgesCounted = 0
        val wrong = ArrayList<String>()
        for ((i, b) in badges.withIndex()) {
            if (b == null || i >= n) continue
            badgesCounted++
            val ox = b.centerX() - xs[i]
            val oy = b.centerY() - ys[i]
            if (ox * (xs[i] - cx) + oy * (ys[i] - cy) > 0f) badgesOuter++ else wrong.add("badge ${i + 1} facing the Sidekick")
            for (j in 0 until n) {
                if (j == i) continue
                val g = rectCircleGap(b, xs[j], ys[j], r)
                badgeBlob = Math.min(badgeBlob, g)
                if (g < 0) wrong.add("badge ${i + 1} on blob ${j + 1}")
            }
            val gs = rectCircleGap(b, cx, cy, lensR)
            badgeBlob = Math.min(badgeBlob, gs)
            if (gs < 0) wrong.add("badge ${i + 1} on the Sidekick")
        }
        for (i in 0 until n) {
            for (j in i + 1 until n) {
                val g = Math.hypot((xs[i] - xs[j]).toDouble(), (ys[i] - ys[j]).toDouble()).toFloat() - 2 * r
                blobBlob = Math.min(blobBlob, g)
                if (g < 0) wrong.add("blobs ${i + 1} and ${j + 1}")
            }
            edge = Math.min(edge, Math.min(Math.min(xs[i] - r, w - xs[i] - r), Math.min(ys[i] - r, h - ys[i] - r)))
            if (barTop != null) bar = Math.min(bar, barTop - (ys[i] + r))
            val nr = names.getOrNull(i)?.rect ?: continue
            for (j in 0 until n) {
                val g = rectCircleGap(nr, xs[j], ys[j], r)
                nameBlob = Math.min(nameBlob, g)
                if (g < 0) wrong.add("name ${i + 1} on blob ${j + 1}")
            }
            for ((j, b) in badges.withIndex()) {
                if (b == null) continue
                val g = rectGap(nr, b)
                nameBadge = Math.min(nameBadge, g)
                if (g < 0) wrong.add("name ${i + 1} on badge ${j + 1}")
            }
            val gs = rectCircleGap(nr, cx, cy, lensR)
            nameSidekick = Math.min(nameSidekick, gs)
            if (gs < 0) wrong.add("name ${i + 1} on the Sidekick")
            for (j in i + 1 until n) {
                val o = names.getOrNull(j)?.rect ?: continue
                val g = rectGap(nr, o)
                nameName = Math.min(nameName, g)
                if (g < 0) wrong.add("names ${i + 1} and ${j + 1}")
            }
            edge = Math.min(edge, Math.min(Math.min(nr.left, w - nr.right), Math.min(nr.top, h - nr.bottom)))
            if (barTop != null) bar = Math.min(bar, barTop - nr.bottom)
        }
        if (edge < 0) wrong.add("something off the screen")
        if (barTop != null && bar < 0) wrong.add("something on Prism's bar")
        fun pts(v: Float): Double? = if (v == Float.MAX_VALUE) null else Math.round(v / dp * 10) / 10.0
        val all = listOf(blobBlob, nameBlob, nameBadge, nameSidekick, nameName, edge, if (barTop != null) bar else Float.MAX_VALUE).minOrNull() ?: 0f
        return hashMapOf(
            "blobBlob" to pts(blobBlob),
            "nameBlob" to pts(nameBlob),
            "nameBadge" to pts(nameBadge),
            "nameSidekick" to pts(nameSidekick),
            "nameName" to pts(nameName),
            "edge" to pts(edge),
            "bar" to pts(bar),
            "least" to pts(all),
            "badgeBlob" to pts(badgeBlob),
            "badgesOuter" to badgesOuter,
            "badgesCounted" to badgesCounted,
            "wrong" to wrong,
        )
    }
}
