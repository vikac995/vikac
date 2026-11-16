package dev.lumen.lumen

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager

/**
 * The Sidekick's own settings panel (step 2b, build 178), drawn by Android over whatever app is
 * open. Prism never comes forward for it and is not asked anything: the settings are the
 * Sidekick's own (SidekickSettings), and Prism is only told afterwards, to keep its copy.
 *
 * As the owner approved it (tasks/STEP2b.md, the mock-up linked there):
 * - beside the Sidekick, on the side away from it, nearly full height, 330 points wide;
 * - it grows out of the Sidekick's circle on Prism's "snappy" spring and goes back into it on
 *   "spatialFast", as Prism's own settings and the app list do; its contents come in between 5%
 *   and 30% of the way;
 * - a shade over the app, with a hole where the Sidekick is; the Sidekick's own window is kept
 *   above the panel, always;
 * - In Prism / Over other apps, Labels, Icons, Colours, Look (three to a row), and "Where it rests,
 *   in points": two dials side by side, Hovering and Tucked in. Touching one puts the Sidekick in
 *   that state at once, and sliding moves it the way the finger goes on either edge; one tick a
 *   point; a flick coasts and lands on a whole point. While one is held the panel stays exactly as
 *   it is and only the shade lifts. Let go: the shade comes back, with nothing else changing, and
 *   the Sidekick goes back to the state it was in when the panel opened;
 * - it never takes the focus (as the Sidekick's menu: a keyboard in the app underneath is never
 *   taken away; measured in build 176). Back goes to that app. It closes with the X, a tap on the
 *   shade, a tap on the Sidekick, Home / Recents, and the screen going off.
 *
 * Every control is drawn as Prism's own: the same sizes, colours (Prism's panel colours, sent by
 * Prism and kept by SidekickSettings), springs and fonts. Their Flutter twins: _SpringPanel and the
 * Sidekick part of _showFloating (shell.dart), Segmented, LumenSwitch, SwitchLine (controls.dart,
 * panel.dart), DragDial (inputs_room.dart), BlobSignPreview (blob_sign.dart). A change to one is a
 * change to both.
 */
object SidekickPanel {
    private var view: PanelView? = null
    private var listener: android.content.BroadcastReceiver? = null

    /** For the test report: how often it opened and closed, and why it last closed. */
    var opened = 0
        private set
    var lastClosed = ""
        private set

    val isOpen: Boolean get() = view != null

    /** True while the panel draws the Sidekick into itself (the Sidekick then neither counts the frame nor calls back). */
    var drawingStandIn = false

    /** The Sidekick has been drawn again, or its window has moved: the panel draws its hole, and its stand-in, anew. */
    fun lensChanged() {
        view?.invalidate()
    }

    /** Opens it beside the Sidekick ([how]: which of the three ways, for the recorder). */
    fun open(context: Context, how: String) {
        if (view != null) return
        val app = context.applicationContext
        if (!android.provider.Settings.canDrawOverlays(app)) return
        val lens = RestBubble.lensOnScreen() ?: run {
            Trail.add("Sidekick: its settings not opened ($how): it is not on the screen")
            return
        }
        SidekickSettings.load(app)
        val v = PanelView(app, lens[0], lens[1], lens[2], RestBubble.lensTucked())
        val lp = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT, WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            // Never the focus, never the keyboard: Back and the keyboard stay the app's.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            android.graphics.PixelFormat.TRANSLUCENT,
        )
        if (Build.VERSION.SDK_INT >= 28) {
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
        }
        lp.windowAnimations = 0
        try {
            wm(app).addView(v, lp)
        } catch (e: Exception) {
            Trail.add("Sidekick: its settings could not be shown (${e.javaClass.simpleName})")
            return
        }
        view = v
        opened++
        // (The Sidekick's own window stays where it is, under this one: never taken off and put
        // back, which blinked in build 180. Beside the panel it shows through the shade's hole;
        // where the panel covers it, the panel draws it: see PanelView.drawStandIn.)
        listen(app)
        Trail.add("Sidekick: its own settings opened ($how), never taking the focus")
    }

    /** Closes it, back into the Sidekick. */
    fun close(why: String) {
        view?.close(why)
    }

    internal fun gone(v: PanelView, why: String) {
        if (view !== v) return
        view = null
        lastClosed = why
        try { wm(v.context).removeView(v) } catch (e: Exception) {}
        val r = listener
        listener = null
        if (r != null) try { v.context.applicationContext.unregisterReceiver(r) } catch (e: Exception) {}
        Trail.add("Sidekick: its own settings gone, ${v.age()} ms after they opened ($why)")
    }

    // Heading for the home screen or the recent apps, or the screen going off: it closes. Android
    // (and One UI) announce "close system dialogs" for many other reasons too ("assist",
    // "globalactions", "lock", "dream", "voiceinteraction", and some with no reason at all, on
    // window changes): those are written in the recorder and leave it open. (Build 178 closed on
    // every one of them, and the owner saw it close by itself a moment after opening.)
    private val closingReasons = setOf("homekey", "recentapps")

    private fun listen(app: Context) {
        if (listener != null) return
        val r = object : android.content.BroadcastReceiver() {
            override fun onReceive(c: Context, i: android.content.Intent) {
                if (i.action == android.content.Intent.ACTION_SCREEN_OFF) {
                    close("the screen went off")
                    return
                }
                val reason = i.getStringExtra("reason")
                if (reason != null && reason in closingReasons) {
                    close("Android said \"$reason\": the home screen or the recent apps")
                } else {
                    Trail.add("Sidekick: its own settings stay open: Android said \"close system dialogs\" (${reason ?: "no reason given"})")
                }
            }
        }
        try {
            val filter = android.content.IntentFilter()
            @Suppress("DEPRECATION")
            filter.addAction(android.content.Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            filter.addAction(android.content.Intent.ACTION_SCREEN_OFF)
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(r, filter, Context.RECEIVER_EXPORTED) else app.registerReceiver(r, filter)
            listener = r
        } catch (e: Exception) {
            listener = null
        }
    }

    private fun wm(context: Context) = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    // ---- For the button test: what it is doing, where its parts are, and touches on them.

    fun testState(): HashMap<String, Any?> {
        val v = view
        val m = hashMapOf<String, Any?>("panelOpen" to (v != null), "panelOpened" to opened, "panelClosed" to lastClosed)
        if (v != null) m.putAll(v.testState())
        return m
    }

    /** The view, for the test's finger (its own coordinates are the screen's). */
    fun testView(): View? = view

    /** See PanelView.testSample. */
    fun testSample(at: Float): HashMap<String, Any?>? = view?.testSample(at)

    /** Where part [id] is on the screen, brought into sight first; null if there is no such part. */
    fun testSpot(id: String): FloatArray? = view?.testSpot(id)

    /** As Home or the recent apps would. */
    fun testHome() = close("Android said \"homekey\" (the test)")
}

/** A spring as in springs.dart: stiffness and damping ratio, mass 1. */
private class Spring(stiffness: Float, ratio: Float, var value: Float = 0f) {
    var k = stiffness
    var c = (2 * ratio * Math.sqrt(stiffness.toDouble())).toFloat()
    var target = value
    var speed = 0f
    var onSettle: (() -> Unit)? = null

    fun set(stiffness: Float, ratio: Float) {
        k = stiffness
        c = (2 * ratio * Math.sqrt(stiffness.toDouble())).toFloat()
    }

    fun to(t: Float, velocity: Float? = null) {
        target = t
        if (velocity != null) speed = velocity
    }

    fun jump(t: Float) {
        value = t; target = t; speed = 0f
    }

    /** Moves on by [dt] seconds; true while it is still moving. */
    fun step(dt: Float, settleDistance: Float = 0.004f, settleSpeed: Float = 0.05f): Boolean {
        if (value == target && speed == 0f) return false
        val steps = Math.ceil((dt / 0.004f).toDouble()).toInt().coerceAtLeast(1)
        val h = dt / steps
        for (i in 0 until steps) {
            speed += (-k * (value - target) - c * speed) * h
            value += speed * h
        }
        if (Math.abs(value - target) < settleDistance && Math.abs(speed) < settleSpeed) {
            value = target; speed = 0f
            onSettle?.let { onSettle = null; it() }
            return false
        }
        return true
    }
}

/** Prism's named springs (lib/core/springs.dart), the same numbers. */
private object Springs {
    val expressiveFast = 800f to 0.6f
    val snappy = 1100f to 0.82f
    val spatialFast = 1400f to 0.9f
    val effects = 1600f to 1f
}

/** Prism's own type: Inter and Bricolage from the app's fonts, each weight made once (never one per frame). */
private object PanelType {
    private val made = HashMap<String, Typeface>()

    fun inter(context: Context, weight: Int, size: Float): Typeface =
        face(context, "Inter", weight, "'opsz' ${opsz(size.coerceIn(14f, 32f))}")

    fun display(context: Context, weight: Int, size: Float): Typeface =
        face(context, "Bricolage", weight, "'wdth' 100, 'opsz' ${opsz(size.coerceIn(12f, 96f))}")

    // As LumenType: weights in steps of 10, optical sizes in steps of 0.5.
    private fun opsz(v: Float) = Math.round(v * 2) / 2f

    private fun face(context: Context, family: String, weight: Int, rest: String): Typeface {
        val w = Math.round(weight / 10f) * 10
        val key = "$family|$w|$rest"
        made[key]?.let { return it }
        val t = try {
            if (Build.VERSION.SDK_INT >= 26) {
                Typeface.Builder(context.assets, "flutter_assets/assets/fonts/$family.ttf")
                    .setFontVariationSettings("'wght' $w, $rest").build()
            } else {
                Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/$family.ttf")
            }
        } catch (e: Exception) {
            Typeface.create("sans-serif", if (w >= 600) Typeface.BOLD else Typeface.NORMAL)
        }
        made[key] = t
        return t
    }
}

internal class PanelView(
    context: Context,
    private val sx: Float,
    private val sy: Float,
    private val sr: Float,
    private val wasTucked: Boolean,
) : View(context) {
    private val dp = resources.displayMetrics.density
    private val fs = resources.configuration.fontScale
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val text = Paint(Paint.ANTI_ALIAS_FLAG)
    private val onRight = sx > resources.displayMetrics.widthPixels / 2f

    // ---- Colours: Prism's panel colours, light or dark as Prism was last.
    private fun col(name: String, light: Int, dark: Int): Int {
        val d = SidekickSettings.paletteColour("dark") == 1
        return SidekickSettings.paletteColour("${if (d) "dark" else "light"}.$name") ?: if (d) dark else light
    }
    private val dark get() = SidekickSettings.paletteColour("dark") == 1
    private val cSurface get() = col("surface", 0xFFFFFFFF.toInt(), 0xFF1B1C1F.toInt())
    private val cSurfaceHigh get() = col("surfaceHigh", 0xFFF4F4F6.toInt(), 0xFF28292D.toInt())
    private val cHairline get() = col("hairline", 0x1F000000, 0x1FFFFFFF)
    private val cInk get() = col("ink", 0xFF14161B.toInt(), 0xFFF2EFE8.toInt())
    private val cInkMuted get() = col("inkMuted", 0xFF5C6270.toInt(), 0xFF9C9890.toInt())
    private val cInkFaint get() = col("inkFaint", 0xFF9AA0AC.toInt(), 0xFF5E5C58.toInt())
    private val cAccent get() = col("accent", 0xFFE2B25A.toInt(), 0xFFE2B25A.toInt())
    private val cOnAccent get() = col("onAccent", 0xFF1A1406.toInt(), 0xFF1A1406.toInt())

    private fun alpha(c: Int, a: Float): Int = (c and 0x00FFFFFF) or ((((c ushr 24) and 0xFF) * a.coerceIn(0f, 1f)).toInt() shl 24)
    private fun mix(a: Int, b: Int, t: Float): Int {
        val u = t.coerceIn(0f, 1f)
        fun ch(s: Int) = (((a ushr s) and 0xFF) * (1 - u) + ((b ushr s) and 0xFF) * u).toInt() shl s
        return ch(24) or ch(16) or ch(8) or ch(0)
    }

    // ---- Where it is: the panel's place when open, worked out from the screen.
    private val box = RectF()
    private var topInset = 0f
    private var bottomInset = 0f

    private fun layoutBox() {
        val w = width.toFloat()
        val h = height.toFloat()
        val pw = Math.min(330 * dp, w - 16 * dp - 56 * dp)
        val left = if (onRight) 8 * dp else w - 8 * dp - pw
        val top = Math.max(56 * dp, topInset + 8 * dp)
        val bottom = h - Math.max(42 * dp, bottomInset + 8 * dp)
        box.set(left, top, left + pw, Math.max(top + 200 * dp, bottom))
        layOut()
    }

    override fun onSizeChanged(w: Int, h: Int, ow: Int, oh: Int) {
        super.onSizeChanged(w, h, ow, oh)
        readInsets()
        layoutBox()
    }

    // Where this window's corner is on the screen: the Sidekick's place is known on the screen.
    private val origin = IntArray(2)

    override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
        super.onLayout(changed, l, t, r, b)
        getLocationOnScreen(origin)
    }

    override fun onApplyWindowInsets(insets: android.view.WindowInsets): android.view.WindowInsets {
        readInsets(insets)
        if (width > 0) layoutBox()
        invalidate()
        return super.onApplyWindowInsets(insets)
    }

    private fun readInsets(given: android.view.WindowInsets? = null) {
        val ins = given ?: rootWindowInsets ?: return
        if (Build.VERSION.SDK_INT >= 30) {
            topInset = ins.getInsets(android.view.WindowInsets.Type.systemBars()).top.toFloat()
            // (A keyboard up in the app underneath: the panel ends above it, and scrolls.)
            bottomInset = Math.max(
                ins.getInsets(android.view.WindowInsets.Type.systemBars()).bottom,
                ins.getInsets(android.view.WindowInsets.Type.ime()).bottom,
            ).toFloat()
        } else {
            @Suppress("DEPRECATION")
            topInset = ins.systemWindowInsetTop.toFloat()
            @Suppress("DEPRECATION")
            bottomInset = ins.systemWindowInsetBottom.toFloat()
        }
    }

    // ---- The contents, top to bottom, in the panel's own points (y from the panel's top, before scrolling).
    private enum class Kind { TITLE, SWITCH, LABEL, PICKER, LOOKS, RULERS, GAP }
    private class Part(val kind: Kind, val id: String, val label: String, val h: Float, val options: List<String> = emptyList()) {
        var y = 0f
    }

    private val looks = listOf("pearls" to "Pearls", "petals" to "Petals", "lotus" to "Lotus", "beam" to "Beam", "halo" to "Halo", "window" to "Window")
    private val parts = ArrayList<Part>()
    private var contentH = 0f
    private val pad get() = 20 * dp

    private fun layOut() {
        parts.clear()
        fun gap(h: Float) = parts.add(Part(Kind.GAP, "", "", h * dp))
        fun label(t: String) = parts.add(Part(Kind.LABEL, "", t, 20 * dp * fs))
        parts.add(Part(Kind.TITLE, "close", "Sidekick", 44 * dp))
        gap(14f)
        parts.add(Part(Kind.SWITCH, "inApp", "In Prism", 48 * dp))
        gap(12f)
        parts.add(Part(Kind.SWITCH, "overApps", "Over other apps", 48 * dp))
        gap(14f)
        label("Labels"); gap(8f)
        parts.add(Part(Kind.PICKER, "names", "", 48 * dp, listOf("Show", "Hide")))
        gap(14f)
        label("Icons"); gap(8f)
        parts.add(Part(Kind.PICKER, "prismIcons", "", 48 * dp, listOf("Prism", "Regular")))
        gap(16f)
        label("Colours"); gap(8f)
        parts.add(Part(Kind.PICKER, "vivid", "", 48 * dp, listOf("Mellow", "Vivid")))
        gap(16f)
        label("Look"); gap(10f)
        parts.add(Part(Kind.LOOKS, "look", "", lookRows() * lookCellH() + (lookRows() - 1) * 12 * dp))
        gap(16f)
        label("Where it rests, in points"); gap(8f)
        parts.add(Part(Kind.RULERS, "rulers", "", (18 * fs + 6 + 52) * dp))
        var y = pad
        for (p in parts) {
            p.y = y
            y += p.h
        }
        contentH = y + pad
        scroll = scroll.coerceIn(0f, maxScroll())
    }

    private fun lookRows() = (looks.size + 2) / 3
    private fun lookCellH() = (66 + 6 + 17 * fs) * dp
    private fun maxScroll() = Math.max(0f, contentH - box.height())

    // ---- What each control is doing (springs and values).
    private val g = Spring(Springs.snappy.first, Springs.snappy.second)          // 0 shut, 1 open
    private val clear = Spring(Springs.effects.first, Springs.effects.second)    // 1: the shade lifted
    private val picks = HashMap<String, Spring>()
    private val switches = HashMap<String, Spring>()
    private val presses = HashMap<String, Spring>()
    private val lifts = hashMapOf(
        "gap" to Spring(Springs.expressiveFast.first, Springs.expressiveFast.second),
        "tuck" to Spring(Springs.expressiveFast.first, Springs.expressiveFast.second),
    )
    private val wheel = hashMapOf("gap" to 0f, "tuck" to 0f)
    private var closing = false
    private var why = ""
    private var opened = false

    // The lowest the panel's contents were drawn at while fully open, and since when: no flash.
    private var leastSinceOpen = 1f

    private fun pickValue(id: String): Int = when (id) {
        "names" -> if (SidekickSettings.names) 0 else 1
        "prismIcons" -> if (SidekickSettings.prismIcons) 0 else 1
        "vivid" -> if (SidekickSettings.vivid) 1 else 0
        else -> 0
    }

    private fun switchValue(id: String) = if (id == "inApp") SidekickSettings.inApp else SidekickSettings.overApps

    init {
        for (id in listOf("names", "prismIcons", "vivid")) {
            picks[id] = Spring(Springs.expressiveFast.first, Springs.expressiveFast.second, pickValue(id).toFloat())
        }
        for (id in listOf("inApp", "overApps")) {
            switches[id] = Spring(Springs.expressiveFast.first, Springs.expressiveFast.second, if (switchValue(id)) 1f else 0f)
            presses[id] = Spring(Springs.spatialFast.first, Springs.spatialFast.second)
        }
        g.to(1f)
        isFocusable = false
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        run()
    }

    override fun onDetachedFromWindow() {
        running = false
        super.onDetachedFromWindow()
    }

    // When it opened, for the recorder: how long it was open when something closed it.
    private val born = android.os.SystemClock.uptimeMillis()
    fun age(): Long = android.os.SystemClock.uptimeMillis() - born

    fun close(reason: String) {
        if (closing) return
        closing = true
        why = reason
        Trail.add("Sidekick: its own settings closing, ${age()} ms after they opened: $reason")
        endRuler(save = true, back = false)
        coasting = null
        // Back into the Sidekick, as fast as it came out: and the Sidekick to its state of before.
        g.set(Springs.spatialFast.first, Springs.spatialFast.second)
        g.to(0f)
        clear.to(0f)
        RestBubble.showSpot(wasTucked)
        run()
    }

    // ---- The frame loop: runs only while something moves.
    private var running = false
    private var last = 0L
    private val frame = object : android.view.Choreographer.FrameCallback {
        override fun doFrame(nanos: Long) {
            if (!running || !isAttachedToWindow) {
                running = false
                return
            }
            val dt = if (last == 0L) 1f / 120f else ((nanos - last) / 1e9f).coerceIn(0.001f, 0.034f)
            last = nanos
            var moving = false
            moving = g.step(dt) or moving
            moving = clear.step(dt) or moving
            for (s in picks.values) moving = s.step(dt, 0.02f, 0.4f) or moving
            for (s in switches.values) moving = s.step(dt) or moving
            for (s in presses.values) moving = s.step(dt) or moving
            for (s in lifts.values) moving = s.step(dt) or moving
            coasting?.let { moving = coast(dt) or moving }
            flinging?.let { moving = fling(dt) or moving }
            if (!opened && g.value >= 0.999f) opened = true
            if (closing && g.value <= 0.004f) {
                running = false
                SidekickPanel.gone(this@PanelView, why)
                return
            }
            invalidate()
            if (moving) {
                android.view.Choreographer.getInstance().postFrameCallback(this)
            } else {
                running = false
            }
        }
    }

    private fun run() {
        if (running) return
        running = true
        last = 0L
        android.view.Choreographer.getInstance().postFrameCallback(frame)
    }

    // ---- Drawing.
    private val rr = RectF()
    private val clip = Path()

    override fun onDraw(canvas: Canvas) {
        if (width == 0) return
        val t = g.value.coerceIn(0f, 1.2f)
        // The shade over the app, with a hole where the Sidekick is; it lifts while a dial is held.
        val shade = 0.4f * t.coerceIn(0f, 1f) * (1f - clear.value.coerceIn(0f, 1f))
        if (shade > 0.002f) {
            canvas.save()
            clip.reset()
            clip.addCircle(lensX(), lensY(), sr + 6 * dp, Path.Direction.CW)
            if (Build.VERSION.SDK_INT >= 26) canvas.clipOutPath(clip) else {
                @Suppress("DEPRECATION")
                canvas.clipPath(clip, android.graphics.Region.Op.DIFFERENCE)
            }
            canvas.drawColor(alpha(0xFF000000.toInt(), shade))
            canvas.restore()
        }
        // The panel, from the Sidekick's circle to its own place.
        val tt = t.coerceAtLeast(0f)
        val l = lerp(lensX() - sr, box.left, tt)
        val top = lerp(lensY() - sr, box.top, tt)
        val r = lerp(lensX() + sr, box.right, tt)
        val b = lerp(lensY() + sr, box.bottom, tt)
        if (tt < 0.002f) {
            standIn(canvas, false)
            return
        }
        val corner = lerp(sr, 36 * dp, tt.coerceIn(0f, 1f))
        rr.set(l, top, r, b)
        paint.style = Paint.Style.FILL
        paint.color = cSurface
        canvas.drawRoundRect(rr, corner, corner, paint)
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1 * dp
        paint.color = cHairline
        canvas.drawRoundRect(rr, corner, corner, paint)
        paint.style = Paint.Style.FILL
        // Its contents come in between 5% and 30% of the way, as in Prism; drawn at their own
        // size, scaled with the panel, as Prism's transform does.
        val a = ((tt - 0.05f) / 0.25f).coerceIn(0f, 1f)
        if (opened && !closing && !sampling) leastSinceOpen = Math.min(leastSinceOpen, a)
        if (a <= 0.001f) {
            standIn(canvas, covers(rr))
            return
        }
        canvas.save()
        clip.reset()
        clip.addRoundRect(rr, corner, corner, Path.Direction.CW)
        canvas.clipPath(clip)
        val sxk = (r - l) / box.width()
        val syk = (b - top) / box.height()
        canvas.translate(l, top)
        canvas.scale(sxk, syk)
        canvas.translate(-box.left, -box.top)
        val layer = canvas.saveLayerAlpha(box.left, box.top, box.right, box.bottom, (a * 255).toInt())
        canvas.translate(box.left, box.top - scroll)
        for (p in parts) drawPart(canvas, p)
        canvas.restoreToCount(layer)
        canvas.restore()
        standIn(canvas, covers(rr))
    }

    // Whether the panel, where it is now, lies over the Sidekick (any of its glass).
    private fun covers(panel: RectF): Boolean {
        val x = lensX()
        val y = lensY()
        val nx = x.coerceIn(panel.left, panel.right)
        val ny = y.coerceIn(panel.top, panel.bottom)
        return Math.hypot((x - nx).toDouble(), (y - ny).toDouble()) < sr + 2 * dp
    }

    // The stand-in: the Sidekick's own drawing, over the panel, only while the panel covers it,
    // so that the Sidekick is always seen above its panel without its window ever moving.
    private var standingIn = false
    var standIns = 0
        private set
    private var noStandIn = false

    // (For the test: what the last frame asked of the stand-in, and whether it was drawn.)
    private var lastAsked = false
    private var lastDrew = false

    private fun standIn(canvas: Canvas, needed: Boolean) {
        var drew = false
        lastAsked = needed && !noStandIn
        if (needed && !noStandIn) {
            SidekickPanel.drawingStandIn = true
            try {
                drew = RestBubble.drawLensInto(canvas, origin[0], origin[1])
            } finally {
                SidekickPanel.drawingStandIn = false
            }
        }
        lastDrew = drew
        if (drew != standingIn && !sampling) {
            standingIn = drew
            if (drew) standIns++
            Trail.add("Sidekick: stand-in ${if (drew) "drawn" else "stopped"} (the panel ${if (drew) "covers it" else "is clear of it"}, ${(g.value * 100).toInt()}% open)")
        }
    }

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    // The Sidekick's middle now (it may have moved while a dial was held): from its window.
    private fun lensX(): Float = (RestBubble.lensOnScreen()?.get(0) ?: sx) - origin[0]
    private fun lensY(): Float = (RestBubble.lensOnScreen()?.get(1) ?: sy) - origin[1]

    private fun drawText(canvas: Canvas, s: String, x: Float, baseline: Float, size: Float, weight: Int, color: Int, center: Boolean = false, display: Boolean = false) {
        text.typeface = if (display) PanelType.display(context, weight, size) else PanelType.inter(context, weight, size)
        text.textSize = size * dp * fs
        text.color = color
        text.letterSpacing = if (display) -0.02f else (if (size < 13) 0.01f else -0.006f)
        val w = text.measureText(s)
        canvas.drawText(s, if (center) x - w / 2f else x, baseline, text)
    }

    private val innerW get() = box.width() - 2 * pad

    private fun drawPart(canvas: Canvas, p: Part) {
        val x0 = pad
        val y = p.y
        when (p.kind) {
            Kind.GAP -> {}
            Kind.TITLE -> {
                drawText(canvas, p.label, x0, y + 30 * dp, 22f, 700, cInk, display = true)
                val cx = x0 + innerW - 22 * dp
                val cy = y + 22 * dp
                paint.color = alpha(cInk, 0.1f)
                canvas.drawCircle(cx, cy, 22 * dp, paint)
                paint.color = cInk
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 2.2f * dp
                paint.strokeCap = Paint.Cap.ROUND
                val k = 6.5f * dp
                canvas.drawLine(cx - k, cy - k, cx + k, cy + k, paint)
                canvas.drawLine(cx - k, cy + k, cx + k, cy - k, paint)
                paint.style = Paint.Style.FILL
            }
            Kind.LABEL -> drawText(canvas, p.label, x0, y + 15 * dp * fs, 15f, 560, cInk)
            Kind.SWITCH -> {
                drawText(canvas, p.label, x0, y + 24 * dp + 5 * dp * fs, 15f, 560, cInk)
                drawSwitch(canvas, p.id, x0 + innerW - 57 * dp, y + 8 * dp)
            }
            Kind.PICKER -> drawPicker(canvas, p, x0, y)
            Kind.LOOKS -> drawLooks(canvas, x0, y)
            Kind.RULERS -> drawRulers(canvas, x0, y)
        }
    }

    // LumenSwitch: 54 × 32, the knob 24 on a 4-point inset, stretched while pressed.
    private fun drawSwitch(canvas: Canvas, id: String, x: Float, y: Float) {
        val t = switches[id]?.value ?: 0f
        val on = t.coerceIn(0f, 1f)
        val stretch = 6 * dp * (presses[id]?.value ?: 0f).coerceIn(0f, 1.2f)
        val w = 54 * dp
        val h = 32 * dp
        val pd = 4 * dp
        val knob = 24 * dp
        rr.set(x, y, x + w, y + h)
        paint.color = mix(alpha(cInk, 0.16f), cAccent, on)
        canvas.drawRoundRect(rr, h / 2, h / 2, paint)
        val travel = w - pd * 2 - knob - stretch
        val left = x + pd + travel * t
        rr.set(left, y + pd, left + knob + stretch, y + pd + knob)
        paint.color = mix(if (dark) cInk else cSurfaceHigh, if (dark) cOnAccent else 0xFFFFFFFF.toInt(), on)
        paint.setShadowLayer(4 * dp, 0f, 1 * dp, 0x33000000)
        canvas.drawRoundRect(rr, knob / 2, knob / 2, paint)
        paint.clearShadowLayer()
    }

    // Segmented: a 40-point track (ink at 7%) and a thumb that slides on its spring.
    private fun drawPicker(canvas: Canvas, p: Part, x: Float, y: Float) {
        val s = picks[p.id] ?: return
        val n = p.options.size
        val top = y + 4 * dp
        rr.set(x, top, x + innerW, top + 40 * dp)
        paint.color = alpha(cInk, 0.07f)
        canvas.drawRoundRect(rr, 20 * dp, 20 * dp, paint)
        val inner = innerW - 6 * dp
        val seg = inner / n
        val stretch = (Math.abs(s.speed) * 0.9f).coerceIn(0f, 10f) * dp
        val tl = x + 3 * dp + seg * s.value - stretch / 2
        rr.set(tl, top + 3 * dp, tl + seg + stretch, top + 37 * dp)
        paint.color = if (dark) cSurfaceHigh else 0xFFFFFFFF.toInt()
        paint.setShadowLayer(6 * dp, 0f, 2 * dp, 0x26000000)
        canvas.drawRoundRect(rr, 17 * dp, 17 * dp, paint)
        paint.clearShadowLayer()
        paint.style = Paint.Style.STROKE
        paint.strokeWidth = 1 * dp
        paint.color = cHairline
        canvas.drawRoundRect(rr, 17 * dp, 17 * dp, paint)
        paint.style = Paint.Style.FILL
        for (i in 0 until n) {
            val sel = (1 - Math.abs(s.value - i)).coerceIn(0f, 1f)
            val weight = (500 + 150 * sel).toInt()
            drawText(canvas, p.options[i], x + 3 * dp + seg * (i + 0.5f), top + 20 * dp + 4.6f * dp * fs, 13f, weight,
                mix(alpha(cInk, 0.62f), cInk, sel), center = true)
        }
    }

    private fun colours(): IntArray = RestBubble.blobColours()

    // The six looks, three to a row: each drawn as it will be, in the Sidekick's own colours.
    private fun drawLooks(canvas: Canvas, x: Float, y: Float) {
        val cell = 70 * dp
        val spacing = (innerW - 3 * cell) / 2f
        val chosen = SidekickSettings.look.ifEmpty { "window" }
        for ((i, l) in looks.withIndex()) {
            val col = i % 3
            val row = i / 3
            val cx = x + col * (cell + spacing) + cell / 2
            val top = y + row * (lookCellH() + 12 * dp)
            val cy = top + 33 * dp
            val on = l.first == chosen
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 2.5f * dp
            paint.color = alpha(cAccent, if (on) 1f else 0f)
            if (on) canvas.drawCircle(cx, cy, 31.75f * dp, paint)
            paint.style = Paint.Style.FILL
            paint.color = 0xEB000000.toInt()
            canvas.drawCircle(cx, cy, 27 * dp, paint)
            BlobLooks.paint(l.first, canvas, cx, cy, 27 * dp, -Math.PI / 2, colours(), paint, SidekickSettings.vivid)
            paint.style = Paint.Style.FILL
            paint.alpha = 255
            drawText(canvas, l.second, cx, top + 72 * dp + 12.5f * dp * fs, 12.5f, if (on) 650 else 500, if (on) cInk else cInkMuted, center = true)
        }
    }

    // Two DragDial pills side by side, each with its name above it.
    private fun rulerBox(id: String, x: Float, y: Float): RectF {
        val w = (innerW - 10 * dp) / 2
        val left = if (id == "gap") x else x + w + 10 * dp
        val top = y + (18 * fs + 6) * dp
        return RectF(left, top, left + w, top + 52 * dp)
    }

    private fun drawRulers(canvas: Canvas, x: Float, y: Float) {
        for ((id, name) in listOf("gap" to "Hovering", "tuck" to "Tucked in")) {
            val b = rulerBox(id, x, y)
            drawText(canvas, name, b.centerX(), y + 13 * dp * fs, 13f, 560, cInkMuted, center = true)
            val lift = lifts[id]?.value ?: 0f
            val on = lift.coerceIn(0f, 1f)
            canvas.save()
            val k = 1 + 0.06f * lift
            canvas.scale(k, k, b.centerX(), b.centerY())
            paint.color = mix(alpha(cInk, 0.07f), alpha(cAccent, 0.16f), on)
            canvas.drawRoundRect(b, 26 * dp, 26 * dp, paint)
            if (on > 0.01f) {
                paint.style = Paint.Style.STROKE
                paint.strokeWidth = 1.5f * dp
                paint.color = alpha(cAccent, on)
                canvas.drawRoundRect(b, 26 * dp, 26 * dp, paint)
                paint.style = Paint.Style.FILL
            }
            // The edge of a wheel, turning with the thumb: ticks that bunch up and fade at the sides.
            canvas.save()
            canvas.clipRect(b)
            val mid = b.centerX()
            val radius = b.width() * 0.52f
            val spacing = 0.2
            val turn = (wheel[id] ?: 0f) / radius
            val phase = ((turn % spacing) + spacing) % spacing
            val tickTop = b.bottom - 5 * dp - 9 * dp
            val tickH = 9 * dp
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.6f * dp
            paint.strokeCap = Paint.Cap.ROUND
            var a = -1.45 + phase
            val tc = mix(cInkFaint, cAccent, on)
            while (a < 1.45) {
                val px = mid + radius * Math.sin(a).toFloat()
                val depth = Math.cos(a).toFloat()
                paint.color = alpha(tc, (depth * depth).coerceIn(0f, 1f))
                canvas.drawLine(px, tickTop + tickH * (1 - depth) * 0.5f, px, tickTop + tickH, paint)
                a += spacing
            }
            paint.style = Paint.Style.FILL
            canvas.restore()
            val v = if (id == "gap") SidekickSettings.gap else SidekickSettings.tuck
            drawText(canvas, "${Math.round(v)}", mid, b.top + 26 * dp + 2 * dp * fs, 19f, 700, cInk, center = true)
            canvas.restore()
        }
    }

    // ---- Touch. Never the focus: these come only from fingers on the panel or the shade.
    private var downX = 0f
    private var downY = 0f
    private var lastX = 0f
    private var lastY = 0f
    private var target = ""
    private var scrolling = false
    private var ruler = ""
    private var raw = 0f
    private var tracker: android.view.VelocityTracker? = null
    private var scroll = 0f
    private var coasting: Float? = null      // a flicked dial, in points a second
    private var flinging: Float? = null      // a flicked scroll, in pixels a second
    private val slop = 10 * resources.displayMetrics.density

    /** Which part a finger at [x], [y] (on the screen) is on: "" for none, "shade" outside the panel. */
    private fun hit(x: Float, y: Float): String {
        // On the Sidekick (its window lies under this one): a tap there is a tap on the Sidekick.
        if (Math.hypot((x - lensX()).toDouble(), (y - lensY()).toDouble()) < sr + 6 * dp) return "sidekick"
        if (!box.contains(x, y)) return "shade"
        val cx = x - box.left
        val cy = y - box.top + scroll
        for (p in parts) {
            if (cy < p.y || cy > p.y + p.h) continue
            when (p.kind) {
                Kind.TITLE -> {
                    val bx = pad + innerW - 22 * dp
                    if (Math.hypot((cx - bx).toDouble(), (cy - p.y - 22 * dp).toDouble()) < 28 * dp) return "close"
                }
                Kind.SWITCH -> return p.id
                Kind.PICKER -> {
                    val i = ((cx - pad - 3 * dp) / ((innerW - 6 * dp) / p.options.size)).toInt().coerceIn(0, p.options.size - 1)
                    return "${p.id}.$i"
                }
                Kind.LOOKS -> {
                    val cell = 70 * dp
                    val spacing = (innerW - 3 * cell) / 2f
                    val col = ((cx - pad) / (cell + spacing)).toInt().coerceIn(0, 2)
                    val row = ((cy - p.y) / (lookCellH() + 12 * dp)).toInt().coerceIn(0, lookRows() - 1)
                    val i = row * 3 + col
                    if (i < looks.size) return "look.${looks[i].first}"
                }
                Kind.RULERS -> {
                    for (id in listOf("gap", "tuck")) {
                        val b = rulerBox(id, pad, p.y)
                        b.inset(0f, -10 * dp)
                        if (b.contains(cx, cy)) return "ruler.$id"
                    }
                }
                else -> {}
            }
        }
        return ""
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        if (closing || g.value < 0.3f && !opened) return true
        when (e.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                downX = e.x; downY = e.y; lastX = e.x; lastY = e.y
                scrolling = false
                flinging = null
                tracker?.recycle()
                tracker = android.view.VelocityTracker.obtain()
                tracker?.addMovement(e)
                target = hit(e.x, e.y)
                if (target.startsWith("ruler.")) startRuler(target.removePrefix("ruler."))
                if (target == "inApp" || target == "overApps") {
                    presses[target]?.to(1f, 12f)
                    run()
                }
            }
            MotionEvent.ACTION_MOVE -> {
                tracker?.addMovement(e)
                val dx = e.x - lastX
                val dy = e.y - lastY
                lastX = e.x; lastY = e.y
                if (ruler.isNotEmpty()) {
                    moveRuler(dx)
                } else if (scrolling) {
                    scroll = (scroll - dy).coerceIn(0f, maxScroll())
                    invalidate()
                } else if (Math.abs(e.y - downY) > slop && box.contains(downX, downY) && maxScroll() > 0f) {
                    scrolling = true
                    unpress()
                }
            }
            MotionEvent.ACTION_UP -> {
                tracker?.addMovement(e)
                tracker?.computeCurrentVelocity(1000)
                val vx = tracker?.xVelocity ?: 0f
                val vy = tracker?.yVelocity ?: 0f
                val tap = Math.hypot((e.x - downX).toDouble(), (e.y - downY).toDouble()) < slop
                if (ruler.isNotEmpty()) {
                    // (A dial held still and let go is not a tap: it only showed where the Sidekick goes.)
                    upRuler(vx, tap && e.eventTime - e.downTime < android.view.ViewConfiguration.getLongPressTimeout(), e.x)
                } else if (scrolling) {
                    if (Math.abs(vy) > 300) {
                        flinging = -vy
                        run()
                    }
                } else if (tap && hit(e.x, e.y) == target) {
                    tapped(target)
                }
                unpress()
                scrolling = false
            }
            MotionEvent.ACTION_CANCEL -> {
                if (ruler.isNotEmpty()) endRuler(save = true, back = true)
                unpress()
                scrolling = false
            }
        }
        return true
    }

    private fun unpress() {
        for (s in presses.values) s.to(0f)
        run()
    }

    private fun haptic(kind: String) = RestBubble.haptic(context, kind)

    private fun tapped(id: String) {
        when {
            id == "shade" -> SidekickPanel.close("a tap beside it, at ${(downX / dp).toInt()},${(downY / dp).toInt()}")
            id == "sidekick" -> SidekickPanel.close("a tap on the Sidekick")
            id == "close" -> {
                haptic("tick")
                SidekickPanel.close("its X")
            }
            id == "inApp" || id == "overApps" -> {
                val v = !switchValue(id)
                change(mapOf(id to v))
                switches[id]?.let { it.onSettle = { haptic("click") }; it.to(if (v) 1f else 0f) }
                run()
                // Nowhere left to be seen (both off, or not over the app it is over): it closes
                // into where the Sidekick was, and the Sidekick goes. (Only ever after a switch
                // is tapped, and only if that switch left it nowhere to be.)
                val nowhere = !SidekickSettings.inApp && !SidekickSettings.overApps
                postDelayed({
                    if (!closing && (nowhere || !RestBubble.lensShownNow())) SidekickPanel.close("the Sidekick switched off here (${if (nowhere) "everywhere" else id})")
                }, 350)
            }
            id.contains('.') && !id.startsWith("look.") -> {
                val (pid, idx) = id.split('.').let { it[0] to it[1].toInt() }
                if (pickValue(pid) == idx) return
                when (pid) {
                    "names" -> change(mapOf("names" to (idx == 0)))
                    "prismIcons" -> change(mapOf("prismIcons" to (idx == 0)))
                    "vivid" -> change(mapOf("vivid" to (idx == 1)))
                }
                picks[pid]?.let { it.onSettle = { haptic("tick") }; it.to(idx.toFloat()) }
                run()
            }
            id.startsWith("look.") -> {
                val look = id.removePrefix("look.")
                if (SidekickSettings.look.ifEmpty { "window" } == look) return
                haptic("tick")
                change(mapOf("look" to look))
                invalidate()
            }
        }
    }

    private fun change(what: Map<String, Any>) {
        SidekickSettings.set(context, what, null, keep = true, fromPanel = true)
    }

    // ---- The two dials.
    private fun startRuler(id: String) {
        ruler = id
        coasting = null
        raw = if (id == "gap") SidekickSettings.gap else SidekickSettings.tuck
        lifts[id]?.to(1f, 8f)
        // The panel stays; only the shade lifts, to see the Sidekick over the app.
        clear.to(1f)
        RestBubble.showSpot(id == "tuck")
        run()
    }

    // Sliding moves the Sidekick the way the finger goes, on either edge: toward the middle of the
    // screen is more (further out, or more of it showing).
    private fun moveRuler(dx: Float) {
        val inward = if (onRight) -dx else dx
        wheel[ruler] = (wheel[ruler] ?: 0f) + dx
        val (lo, hi) = range(ruler)
        raw = (raw + inward / (16 * dp)).coerceIn(lo, hi)
        emit(Math.round(raw).toFloat())
        invalidate()
    }

    private fun range(id: String) =
        if (id == "gap") SidekickSettings.GAP_MIN to SidekickSettings.GAP_MAX else SidekickSettings.TUCK_MIN to SidekickSettings.TUCK_MAX

    private fun emit(v: Float) {
        val now = if (ruler == "gap") SidekickSettings.gap else SidekickSettings.tuck
        if (v == now) return
        haptic("tick")
        SidekickSettings.set(context, mapOf(ruler to v), if (ruler == "tuck") "tuck" else "rest", keep = false, fromPanel = true)
    }

    private fun upRuler(vx: Float, tap: Boolean, x: Float) {
        if (tap) {
            // A tap on one half steps once, the Sidekick moving toward that half.
            val b = rulerBox(ruler, box.left + pad, 0f)
            val leftHalf = x < b.centerX()
            val inward = if (onRight) leftHalf else !leftHalf
            val (lo, hi) = range(ruler)
            raw = (Math.round(raw) + (if (inward) 1 else -1)).toFloat().coerceIn(lo, hi)
            wheel[ruler] = (wheel[ruler] ?: 0f) + (if (leftHalf) -16 * dp else 16 * dp)
            emit(raw)
            endRuler(save = true, back = true)
            return
        }
        val inward = if (onRight) -vx else vx
        val pointsPerSecond = inward / (16 * dp)
        if (Math.abs(pointsPerSecond) > 4f) {
            // A flick: it coasts on, slowing, and lands on a whole point.
            coasting = pointsPerSecond
            run()
        } else {
            endRuler(save = true, back = true)
        }
    }

    private fun coast(dt: Float): Boolean {
        val v = coasting ?: return false
        val (lo, hi) = range(ruler)
        raw = (raw + v * dt).coerceIn(lo, hi)
        wheel[ruler] = (wheel[ruler] ?: 0f) + (if (onRight) -v else v) * dt * 16 * dp
        emit(Math.round(raw).toFloat())
        val slower = v * Math.exp(-6.0 * dt).toFloat()
        if (Math.abs(slower) < 2f || raw <= lo || raw >= hi) {
            coasting = null
            raw = Math.round(raw).toFloat()
            emit(raw)
            endRuler(save = true, back = true)
            return false
        }
        coasting = slower
        return true
    }

    /** The dial let go: kept, the shade back, and the Sidekick back to the state it was in. */
    private fun endRuler(save: Boolean, back: Boolean) {
        val id = ruler
        if (id.isEmpty()) return
        ruler = ""
        lifts[id]?.to(0f)
        clear.to(0f)
        if (save) {
            val v = Math.round(raw).toFloat()
            SidekickSettings.set(context, mapOf(id to v), null, keep = true, fromPanel = true)
        }
        if (back) RestBubble.showSpot(wasTucked)
        run()
    }

    private fun fling(dt: Float): Boolean {
        val v = flinging ?: return false
        scroll = (scroll + v * dt).coerceIn(0f, maxScroll())
        val slower = v * Math.exp(-4.0 * dt).toFloat()
        if (Math.abs(slower) < 30f || scroll <= 0f || scroll >= maxScroll()) {
            flinging = null
            return false
        }
        flinging = slower
        return true
    }

    // ---- For the test.
    fun testState(): HashMap<String, Any?> = hashMapOf(
        "panelProgress" to g.value.toDouble(),
        "panelShade" to (0.4f * g.value.coerceIn(0f, 1f) * (1f - clear.value.coerceIn(0f, 1f))).toDouble(),
        "panelLifted" to clear.target.toDouble(),
        "panelLeastSinceOpen" to leastSinceOpen.toDouble(),
        "panelOpenFully" to opened,
        "panelClosing" to closing,
        "panelBox" to listOf((box.left + origin[0]) / dp, (box.top + origin[1]) / dp, box.width() / dp, box.height() / dp).map { it.toDouble() },
        "panelOnRight" to onRight,
        "panelScroll" to (scroll / dp).toDouble(),
        "panelScrolls" to (maxScroll() / dp).toDouble(),
        "panelRuler" to ruler,
        "panelWasTucked" to wasTucked,
        "panelFrom" to listOf(sx / dp, sy / dp, sr / dp).map { it.toDouble() },
        "panelFocusable" to ((layoutParams as? WindowManager.LayoutParams)?.flags?.and(WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE) == 0),
        "panelFontScale" to fs.toDouble(),
        "panelHole" to listOf((lensX() + origin[0]) / dp, (lensY() + origin[1]) / dp).map { it.toDouble() },
        "panelStandIn" to standingIn,
        "panelStandIns" to standIns,
    )

    // ---- For the test: is the stand-in really drawn where the panel covers the Sidekick?
    private var sampling = false

    /**
     * Draws the panel as it is at [at] of the way open (a moment of its growing, when it covers the
     * Sidekick) into a few pixels round the Sidekick's middle, and reads the middle one three ways:
     * the panel with its stand-in, the panel without it, and the Sidekick alone. The first must be
     * the Sidekick's, not the panel's. (Drawn in software, off the screen: nothing is seen.)
     */
    fun testSample(at: Float): HashMap<String, Any?> {
        val was = g.value
        sampling = true
        val lx = lensX()
        val ly = lensY()
        fun pixel(draw: (Canvas) -> Unit): Int {
            val bmp = android.graphics.Bitmap.createBitmap(3, 3, android.graphics.Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            c.translate(-lx + 1, -ly + 1)
            draw(c)
            val p = bmp.getPixel(1, 1)
            bmp.recycle()
            return p
        }
        val m = HashMap<String, Any?>()
        try {
            g.value = at
            val rect = RectF(lerp(lx - sr, box.left, at), lerp(ly - sr, box.top, at), lerp(lx + sr, box.right, at), lerp(ly + sr, box.bottom, at))
            m["sampleAt"] = at.toDouble()
            m["sampleCovers"] = covers(rect)
            lastAsked = false
            lastDrew = false
            m["sampleWith"] = pixel { draw(it) }
            // What drawing the panel just now asked of the stand-in, and whether it was drawn; and
            // where the Sidekick's window was, from this window's corner, against the sampled point.
            m["sampleAsked"] = lastAsked
            m["sampleDrew"] = lastDrew
            RestBubble.lensWindow()?.let { w ->
                m["sampleDot"] = listOf(w[0] - origin[0], w[1] - origin[1], w[2], w[3])
            }
            m["sampleOrigin"] = listOf(origin[0], origin[1])
            m["samplePoint"] = listOf(lx.toDouble(), ly.toDouble())
            noStandIn = true
            m["sampleWithout"] = pixel { draw(it) }
            noStandIn = false
            m["sampleLens"] = pixel {
                SidekickPanel.drawingStandIn = true
                try { RestBubble.drawLensInto(it, origin[0], origin[1]) } finally { SidekickPanel.drawingStandIn = false }
            }
        } finally {
            noStandIn = false
            g.value = was
            sampling = false
            invalidate()
        }
        return m
    }

    fun testSpot(id: String): FloatArray? {
        if (id == "shade") {
            // Beside the panel, away from the Sidekick: high up on the far side.
            val x = if (onRight) Math.min(width - 4 * dp, box.right + 20 * dp) else Math.max(4 * dp, box.left - 20 * dp)
            return floatArrayOf(x + origin[0], box.top + 30 * dp + origin[1])
        }
        val (part, sub) = if (id.contains('.')) id.substringBefore('.') to id.substringAfter('.') else id to ""
        val p = parts.firstOrNull { it.id == part || (part == "look" && it.kind == Kind.LOOKS) || (part == "ruler" && it.kind == Kind.RULERS) } ?: return null
        val local: FloatArray = when (p.kind) {
            Kind.TITLE -> floatArrayOf(pad + innerW - 22 * dp, p.y + 22 * dp)
            Kind.SWITCH -> floatArrayOf(pad + innerW - 30 * dp, p.y + 24 * dp)
            Kind.PICKER -> {
                val i = sub.toIntOrNull() ?: 0
                val seg = (innerW - 6 * dp) / p.options.size
                floatArrayOf(pad + 3 * dp + seg * (i + 0.5f), p.y + 24 * dp)
            }
            Kind.LOOKS -> {
                val i = looks.indexOfFirst { it.first == sub }.coerceAtLeast(0)
                val cell = 70 * dp
                val spacing = (innerW - 3 * cell) / 2f
                floatArrayOf(pad + (i % 3) * (cell + spacing) + cell / 2, p.y + (i / 3) * (lookCellH() + 12 * dp) + 33 * dp)
            }
            Kind.RULERS -> {
                val b = rulerBox(sub, pad, p.y)
                floatArrayOf(b.centerX(), b.centerY())
            }
            else -> return null
        }
        // Brought into sight first, as a finger would scroll to it.
        val visTop = scroll + 12 * dp
        val visBottom = scroll + box.height() - 12 * dp
        if (local[1] < visTop || local[1] > visBottom) {
            scroll = (local[1] - box.height() / 2).coerceIn(0f, maxScroll())
            invalidate()
        }
        return floatArrayOf(box.left + local[0] + origin[0], box.top + local[1] - scroll + origin[1])
    }
}
