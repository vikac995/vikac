package dev.lumen.lumen

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.SweepGradient

/**
 * The looks the Blob's sign can have on the floating blob. The same looks, from the same
 * numbers, as lib/fit/blob_sign.dart draws on Prism's button.
 *
 * TO REMOVE A LOOK: delete its line in [looks] and its one function below, and the same two
 * things in blob_sign.dart. Nothing else knows the looks by name: one that is not known here is
 * drawn as the first in the list.
 *
 * Every function draws with the middle of the glass at (0, 0), in a circle of radius r (already
 * clipped to it), for blobs of these colours, pointing along a (radians).
 */
object BlobLooks {
    private class Look(val spectrum: Boolean, val draw: (Canvas, Float, IntArray, Double, Paint) -> Unit)

    private val looks = linkedMapOf(
        "pearls" to Look(false, ::pearls),
        "petals" to Look(false, ::petals),
        "lotus" to Look(false, ::lotus),
        "beam" to Look(true, ::beam),
        "bands" to Look(true, ::bands),
        "bandsclear" to Look(true, ::bandsClear),
        "bandswhite" to Look(true, ::bandsWhite),
        "vivid" to Look(false, ::vivid),
        "halo" to Look(true, ::halo),
        "triangle" to Look(true, ::triangle),
        "window" to Look(true, ::window),
    )

    private val clip = Path()
    private val path = Path()
    private val box = RectF()
    private val hsv = FloatArray(3)

    /** Draws look [id] with its middle at ([cx], [cy]) in glass of radius [r]. */
    fun paint(id: String, canvas: Canvas, cx: Float, cy: Float, r: Float, a: Double, colours: IntArray, paint: Paint) {
        if (colours.isEmpty()) return
        val look = looks[id] ?: looks.values.first()
        var cs = IntArray(minOf(colours.size, 5)) { colours[it] or 0xFF000000.toInt() }
        if (look.spectrum) {
            // From red round to violet, so that the colours read as light.
            cs = cs.sortedBy { Color.colorToHSV(it, hsv); (hsv[0] + 20f) % 360f }.toIntArray()
        }
        canvas.save()
        canvas.translate(cx, cy)
        clip.reset(); clip.addCircle(0f, 0f, r, Path.Direction.CW)
        canvas.clipPath(clip)
        paint.shader = null
        paint.alpha = 255
        paint.style = Paint.Style.FILL
        paint.strokeCap = Paint.Cap.ROUND
        paint.strokeJoin = Paint.Join.ROUND
        look.draw(canvas, r, cs, a, paint)
        canvas.restore()
        paint.shader = null
        paint.alpha = 255
        paint.style = Paint.Style.FILL
        paint.strokeCap = Paint.Cap.BUTT
    }

    // ---- Shared by the looks.

    private fun cos(a: Double) = Math.cos(a).toFloat()
    private fun sin(a: Double) = Math.sin(a).toFloat()
    private fun deg(a: Double) = Math.toDegrees(a).toFloat()
    private fun clear(c: Int) = c and 0x00FFFFFF
    private fun seen(c: Int, alpha: Float) = (c and 0x00FFFFFF) or ((alpha * 255).toInt() shl 24)

    private fun lighter(c: Int, t: Float): Int {
        val r = (c shr 16) and 255; val g = (c shr 8) and 255; val b = c and 255
        return (0xFF shl 24) or ((r + ((255 - r) * t).toInt()) shl 16) or ((g + ((255 - g) * t).toInt()) shl 8) or (b + ((255 - b) * t).toInt())
    }

    private fun upright(x: Float, y: Float, size: Float): Path {
        path.reset()
        path.moveTo(x, y - size); path.lineTo(x + size * 0.866f, y + size * 0.5f); path.lineTo(x - size * 0.866f, y + size * 0.5f); path.close()
        return path
    }

    /** A soft white (or coloured) glow at a point. */
    private fun glow(c: Canvas, x: Float, y: Float, r: Float, colour: Int, alpha: Float, p: Paint) {
        p.style = Paint.Style.FILL
        p.shader = RadialGradient(x, y, r, seen(colour, alpha), clear(colour), Shader.TileMode.CLAMP)
        c.drawCircle(x, y, r, p)
        p.shader = null
    }

    /**
     * A fan of the colours from a point, [half] to each side of [a], each colour holding in the
     * middle of its share and melting into the next. Drawn in one go.
     */
    private fun fan(c: Canvas, x: Float, y: Float, reach: Float, cs: IntArray, a: Double, half: Double, p: Paint) {
        val n = cs.size
        c.save()
        c.translate(x, y)
        c.rotate(deg(a - half))
        p.style = Paint.Style.FILL
        if (n == 1) {
            p.shader = null
            p.color = cs[0]
        } else {
            val share = (2 * half / (2 * Math.PI)).toFloat()
            val colours = IntArray(2 * n) { cs[it / 2] }
            val at = FloatArray(2 * n) { ((it / 2) + (if (it % 2 == 0) 0.3f else 0.7f)) / n * share }
            p.shader = SweepGradient(0f, 0f, colours, at)
        }
        box.set(-reach, -reach, reach, reach)
        c.drawArc(box, 0f, deg(2 * half), true, p)
        p.shader = null
        c.restore()
    }

    // ---- The looks.

    /** Pearls: a white point, Prism, and the blobs around it as small lit pearls. */
    private fun pearls(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val n = cs.size
        val u = r / 29f
        val back = (if (n == 1) 6f else 10f) * u
        val reach = (if (n == 1) 14f else 21f) * u
        val pr = floatArrayOf(6.0f, 5.4f, 4.8f, 4.3f, 3.9f)[n - 1] * u
        val step = doubleArrayOf(0.0, 52.0, 40.0, 31.0, 26.0)[n - 1] * Math.PI / 180.0
        val kx = -back * cos(a); val ky = -back * sin(a)
        val xs = FloatArray(n); val ys = FloatArray(n)
        for (k in 0 until n) {
            val t = a + (k - (n - 1) / 2.0) * step
            xs[k] = kx + reach * cos(t); ys[k] = ky + reach * sin(t)
            glow(c, xs[k], ys[k], pr * 2.3f, cs[k], 0.5f, p)
        }
        glow(c, kx, ky, 10 * u, Color.WHITE, 0.45f, p)
        p.color = Color.WHITE
        c.drawCircle(kx, ky, (if (n == 1) 3.4f else 3.0f) * u, p)
        for (k in 0 until n) {
            p.shader = RadialGradient(
                xs[k] - pr * 0.3f, ys[k] - pr * 0.4f, pr * 1.5f,
                intArrayOf(lighter(cs[k], 0.55f), cs[k], cs[k]), floatArrayOf(0f, 0.6f, 1f), Shader.TileMode.CLAMP,
            )
            c.drawCircle(xs[k], ys[k], pr, p)
        }
        p.shader = null
    }

    /** Petals: the blobs' colours as petals round a quiet white point in the very middle. */
    private fun petals(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val n = cs.size
        val u = r / 29f
        val step = if (n == 1) 0.0 else 360.0 / n
        for (k in 0 until n) {
            c.save()
            c.rotate((Math.toDegrees(a) + (k - (n - 1) / 2.0) * step).toFloat())
            p.color = seen(lighter(cs[k], 0.14f), 0.76f)
            c.drawOval(1f * u, -9.5f * u, 25f * u, 9.5f * u, p)
            c.restore()
        }
        glow(c, 0f, 0f, 6.5f * u, Color.WHITE, 0.35f, p)
        p.color = seen(Color.WHITE, 0.85f)
        c.drawCircle(0f, 0f, 2.4f * u, p)
    }

    /** Lotus: pointed petals opening from one foot, the middle one tallest and in front. */
    private fun lotus(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val n = cs.size
        val u = r / 29f
        val step = if (n <= 3) 38.0 else 29.0
        val fx = -18 * u * cos(a); val fy = -18 * u * sin(a)
        // From the outside in, so the middle petal lies over its neighbours.
        for (k in (0 until n).sortedByDescending { Math.abs(it - (n - 1) / 2f) }) {
            val off = k - (n - 1) / 2f
            val len = (39f - 4f * Math.abs(off)) * u; val w = 9.6f * u
            c.save()
            c.translate(fx, fy)
            c.rotate((Math.toDegrees(a) + off * step).toFloat())
            path.reset()
            path.moveTo(0f, 0f)
            path.cubicTo(len * 0.22f, -w * 1.5f, len * 0.72f, -w * 1.05f, len, 0f)
            path.cubicTo(len * 0.72f, w * 1.05f, len * 0.22f, w * 1.5f, 0f, 0f)
            path.close()
            p.color = seen(lighter(cs[k], 0.14f), 0.8f)
            c.drawPath(path, p)
            c.restore()
        }
        glow(c, fx + 4 * u * cos(a), fy + 4 * u * sin(a), 7f * u, Color.WHITE, 0.5f, p)
    }

    /** Beam: a short white beam into a prism set low in the glass, the colours wide across the rest. */
    private fun beam(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val x = -cos(a) * r * 0.42f; val y = -sin(a) * r * 0.42f
        fan(c, x, y, r * 2.2f, cs, a, (if (cs.size == 1) 24.0 else 52.0) * Math.PI / 180.0, p)
        glow(c, x, y, r * 0.95f, Color.WHITE, 0.6f, p)
        p.style = Paint.Style.STROKE
        p.color = seen(Color.WHITE, 0.28f); p.strokeWidth = r * 0.2f
        c.drawLine(-cos(a) * r * 1.1f, -sin(a) * r * 1.1f, x, y, p)
        p.color = Color.WHITE; p.strokeWidth = r * 0.08f
        c.drawLine(-cos(a) * r * 1.1f, -sin(a) * r * 1.1f, x, y, p)
        val prism = upright(x, y + r * 0.02f, r * 0.3f)
        p.style = Paint.Style.FILL
        p.shader = LinearGradient(x, y - r * 0.3f, x, y + r * 0.2f, 0xFF39424C.toInt(), 0xFF161B20.toInt(), Shader.TileMode.CLAMP)
        c.drawPath(prism, p)
        p.shader = null
        p.style = Paint.Style.STROKE
        p.color = Color.WHITE; p.strokeWidth = r * 0.055f
        c.drawPath(prism, p)
    }

    /** Bands: the same light through the same prism, cut clean, with a dark line between the colours. */
    private fun bands(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) = cutBands(c, r, cs, a, 0xFF0B0E11.toInt(), 0.05f, p)

    /** Clear: the bands with nothing between them, colour straight against colour. */
    private fun bandsClear(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) = cutBands(c, r, cs, a, 0, 0f, p)

    /** Lined: the bands with a very thin white line between them. */
    private fun bandsWhite(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) = cutBands(c, r, cs, a, Color.WHITE, 0.018f, p)

    /**
     * Vivid: black glass and the full rainbow at full strength, cut clean. The colours are the
     * light's own here, not the blobs': always these six, however many blobs there are.
     */
    private fun vivid(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        p.style = Paint.Style.FILL
        p.shader = null
        p.color = 0xF2000000.toInt()
        c.drawCircle(0f, 0f, r, p)
        cutBands(
            c, r,
            intArrayOf(0xFFF2334B.toInt(), 0xFFFF7A2B.toInt(), 0xFFFFD21F.toInt(), 0xFF34C94A.toInt(), 0xFF1F7BF2.toInt(), 0xFF8A3FF0.toInt()),
            // (No white shine: it would grey the black.)
            a, 0, 0f, p, 0f,
        )
    }

    /**
     * The flat bands of the looks above. [line] is drawn between the colours, [width] of the
     * glass's radius wide; 0 for none. (Used only by Bands, Clear, Lined and Vivid: when the last of them is removed,
     * this goes with it.)
     */
    private fun cutBands(c: Canvas, r: Float, cs: IntArray, a: Double, line: Int, width: Float, p: Paint, shine: Float = 0.6f) {
        val n = cs.size
        val x = -cos(a) * r * 0.42f; val y = -sin(a) * r * 0.42f
        val half = (if (n == 1) 24.0 else 54.0) * Math.PI / 180.0
        val each = 2 * half / n
        val dark = 0xFF0B0E11.toInt()
        c.save()
        c.translate(x, y)
        c.rotate(deg(a - half))
        p.style = Paint.Style.FILL
        box.set(-r * 2.2f, -r * 2.2f, r * 2.2f, r * 2.2f)
        for (k in 0 until n) {
            p.color = cs[k]
            c.drawArc(box, deg(k * each), deg(each), true, p)
        }
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.BUTT
        if (line != 0) {
            // Between the colours only, but for the dark one: the fan's two outer edges lie against the dark glass.
            p.color = line; p.strokeWidth = Math.max(1f, r * width)
            for (k in (if (line == dark) 0 else 1)..(if (line == dark) n else n - 1)) c.drawLine(0f, 0f, cos(k * each) * r * 2.2f, sin(k * each) * r * 2.2f, p)
        }
        c.restore()
        // The same white shine round the prism as Beam has.
        if (shine > 0f) glow(c, x, y, r * 0.95f, Color.WHITE, shine, p)
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.BUTT
        p.color = Color.WHITE; p.strokeWidth = r * 0.13f
        c.drawLine(-cos(a) * r * 1.1f, -sin(a) * r * 1.1f, x, y, p)
        val prism = Path(upright(x, y + r * 0.02f, r * 0.34f))
        p.style = Paint.Style.FILL
        p.color = dark
        c.drawPath(prism, p)
        // The bands again inside the prism, paler: the light seen through the glass.
        c.save()
        c.clipPath(prism)
        c.translate(x, y)
        c.rotate(deg(a - half))
        box.set(-r, -r, r, r)
        for (k in 0 until n) {
            p.color = lighter(cs[k], 0.45f)
            c.drawArc(box, deg(k * each), deg(each), true, p)
        }
        c.restore()
        p.style = Paint.Style.STROKE
        p.strokeCap = Paint.Cap.ROUND
        p.color = Color.WHITE; p.strokeWidth = r * 0.08f
        c.drawPath(prism, p)
    }

    /** Halo: white light in the middle, split by the rim of the glass; each blob owns a piece of the rim. */
    private fun halo(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val n = cs.size
        val each = 2 * Math.PI / n
        val gap = if (n == 1) 0.0 else 0.07
        for (k in 0 until n) {
            val t0 = a + Math.PI / 2 + k * each
            p.style = Paint.Style.FILL
            p.shader = RadialGradient(
                0f, 0f, r,
                intArrayOf(clear(cs[k]), seen(cs[k], 0.45f), seen(cs[k], 0.85f)), floatArrayOf(0.2f, 0.62f, 1f), Shader.TileMode.CLAMP,
            )
            box.set(-r * 1.1f, -r * 1.1f, r * 1.1f, r * 1.1f)
            c.drawArc(box, deg(t0), deg(each), true, p)
            p.shader = null
            p.style = Paint.Style.STROKE
            p.color = lighter(cs[k], 0.25f); p.strokeWidth = r * 0.2f
            box.set(-r * 0.8f, -r * 0.8f, r * 0.8f, r * 0.8f)
            c.drawArc(box, deg(t0 + gap + 0.06), if (n == 1) 360f else deg(each - 2 * gap - 0.12), false, p)
        }
        p.style = Paint.Style.FILL
        p.shader = RadialGradient(
            0f, 0f, r * 0.62f,
            intArrayOf(seen(Color.WHITE, 0.85f), seen(Color.WHITE, 0.3f), clear(Color.WHITE)), floatArrayOf(0f, 0.35f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawCircle(0f, 0f, r * 0.62f, p)
        p.shader = null
        p.color = Color.WHITE
        c.drawPath(upright(0f, r * 0.03f, r * 0.27f), p)
    }

    /** Triangle: the prism itself, made of light: white at the corner the light comes in by. */
    private fun triangle(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val s = r * 0.94f
        val ax = -cos(a) * s; val ay = -sin(a) * s
        glow(c, cos(a) * r * 0.5f, sin(a) * r * 0.5f, r * 1.1f, cs[cs.size / 2], 0.4f, p)
        val shape = Path()
        shape.moveTo(ax, ay)
        shape.lineTo(cos(a + Math.PI / 3) * s, sin(a + Math.PI / 3) * s)
        shape.lineTo(cos(a - Math.PI / 3) * s, sin(a - Math.PI / 3) * s)
        shape.close()
        c.save()
        c.clipPath(shape)
        fan(c, ax, ay, r * 2.2f, cs, a, Math.PI / 6, p)
        p.style = Paint.Style.FILL
        p.shader = RadialGradient(
            ax, ay, s * 1.75f,
            intArrayOf(Color.WHITE, seen(Color.WHITE, 0.75f), seen(Color.WHITE, 0.1f), clear(Color.WHITE)),
            floatArrayOf(0f, 0.3f, 0.62f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawCircle(ax, ay, s * 1.75f, p)
        p.shader = null
        c.restore()
        p.style = Paint.Style.STROKE
        p.color = seen(Color.WHITE, 0.7f); p.strokeWidth = Math.max(1f, r * 0.03f)
        c.drawPath(shape, p)
    }

    /**
     * Window: the same triangle, turning the same way, but as a window onto a field of colour of its
     * own that stands still behind it: upright bands, one for each blob, from the left of the glass
     * to the right. Whichever way the triangle points, its left shows the same colour, and its right.
     */
    private fun window(c: Canvas, r: Float, cs: IntArray, a: Double, p: Paint) {
        val s = r * 0.94f
        val shape = Path()
        shape.moveTo(-cos(a) * s, -sin(a) * s)
        shape.lineTo(cos(a + Math.PI / 3) * s, sin(a + Math.PI / 3) * s)
        shape.lineTo(cos(a - Math.PI / 3) * s, sin(a - Math.PI / 3) * s)
        shape.close()
        val n = cs.size
        c.save()
        c.clipPath(shape)
        p.style = Paint.Style.FILL
        if (n == 1) {
            p.shader = null
            p.color = cs[0]
        } else {
            // Each colour holds across the middle of its band and melts into the next.
            val colours = IntArray(2 * n) { cs[it / 2] }
            val at = FloatArray(2 * n) { ((it / 2) + (if (it % 2 == 0) 0.25f else 0.75f)) / n }
            p.shader = LinearGradient(-r, 0f, r, 0f, colours, at, Shader.TileMode.CLAMP)
        }
        c.drawRect(-r, -r, r, r, p)
        // Light from above, the same across the whole field: it does not turn either.
        p.shader = LinearGradient(
            0f, -r, 0f, r,
            intArrayOf(seen(Color.WHITE, 0.32f), clear(Color.WHITE), seen(Color.BLACK, 0.12f)),
            floatArrayOf(0f, 0.55f, 1f), Shader.TileMode.CLAMP,
        )
        c.drawRect(-r, -r, r, r, p)
        p.shader = null
        c.restore()
        p.style = Paint.Style.STROKE
        p.color = seen(Color.WHITE, 0.75f); p.strokeWidth = Math.max(1f, r * 0.035f)
        c.drawPath(shape, p)
    }
}
