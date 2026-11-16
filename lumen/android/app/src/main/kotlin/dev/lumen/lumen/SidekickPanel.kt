package dev.lumen.lumen

import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.os.SystemClock
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager

/**
 * The Sidekick's own settings panel (step 2b, build 178), drawn by Android over whatever app is
 * open. Prism never comes forward for it and is not asked anything: the settings are the
 * Sidekick's own (SidekickSettings), and Prism is only told afterwards, to keep its copy.
 *
 * As the owner approved it (tasks/STEP2b.md, the mock-up linked there):
 * - beside the Sidekick, on the side away from it, ending before its furthest Hovering spot (185),
 *   and above Prism's bar or Android's (186);
 * - it grows out of the Sidekick's circle on Prism's "snappy" spring and goes back into it on
 *   "spatialFast", as Prism's own settings and the app list do; its contents come in between 5%
 *   and 30% of the way;
 * - no shade (185): nothing is drawn round it; the panel has a hole where the Sidekick is, so the
 *   Sidekick (its own window, under the panel's) shows on every frame;
 * - In Prism / Over other apps, Labels, Icons, Colours, Look (three to a row), and "Where it rests,
 *   in points": two dials side by side, Hovering and Tucked in. Touching one puts the Sidekick in
 *   that state at once, and sliding moves it the way the finger goes on either edge; one tick a
 *   point; a flick coasts and lands on a whole point. While one is held, the rest of the panel goes
 *   see-through and the whole "Where it rests" section stays solid (187). Let go: a tenth of a
 *   second later the panel is solid again, on the quick spring, and the Sidekick goes back to the
 *   state it was in when the panel opened;
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
        view?.follow()
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

    /** What the "Where it rests" section really looks like, from its pixels (188). */
    fun testPixels(): HashMap<String, Any?>? = view?.testPixels()

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
    // Which side the Sidekick is on (the panel is on the other). Worked out again as it moves.
    private var onRight = sx > resources.displayMetrics.widthPixels / 2f

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

    /**
     * The panel's place (build 185, the owner's rule): it ends, on the Sidekick's side, before the
     * Sidekick's furthest Hovering spot ([SidekickSettings.GAP_MAX] from the edge, plus the
     * Sidekick's own width) with 8 points to spare, so the Sidekick never reaches it, whatever
     * its Hovering. 8 points from the far edge. As tall as its contents, at the Sidekick's
     * height, kept on the screen; taller than the screen allows, it fills the height and scrolls.
     */
    private fun layoutBox() {
        val w = width.toFloat()
        val h = height.toFloat()
        if (w <= 0f || h <= 0f) return
        val mid = lensX()
        onRight = mid > w / 2f
        // The Sidekick's window is its glass and 5 points round it.
        val reach = SidekickSettings.GAP_MAX * dp + 2 * (sr + 5 * dp) + 8 * dp
        // (Never narrower than its contents allow: three looks in a row. On a screen too narrow
        // for both, the furthest Hovering can then reach it.)
        val pw = Math.max(250 * dp, w - 8 * dp - reach)
        val left = if (onRight) 8 * dp else w - 8 * dp - pw
        val topLimit = Math.max(56 * dp, topInset + 8 * dp)
        var bottomLimit = h - Math.max(42 * dp, bottomInset + 8 * dp)
        // In Prism, it ends 8 points above Prism's own bar (where the button's top is: Prism says).
        // Outside Prism, above Android's navigation or gesture bar (the inset above). (Build 186.)
        val bar = RestBubble.barTop
        if (RestBubble.foreground && bar != null) bottomLimit = Math.min(bottomLimit, bar - origin[1] - 8 * dp)
        limitBottom = bottomLimit
        limitTop = topLimit
        box.set(left, topLimit, left + pw, Math.max(topLimit + 200 * dp, bottomLimit))
        layOut()
        fills = contentH >= box.height()
        val ph = Math.min(contentH, box.height())
        val top = (lensY() - ph / 2f).coerceIn(topLimit, Math.max(topLimit, bottomLimit - ph))
        box.set(left, top, left + pw, top + ph)
        scroll = scroll.coerceIn(0f, maxScroll())
        laidFor = floatArrayOf(lensX(), lensY())
    }

    // (The lowest and highest the panel may reach, on the screen, as it was last laid out, and
    // whether its contents fill all of that, so that it can't move up or down: for the test.)
    private var limitBottom = 0f
    private var limitTop = 0f
    private var fills = false

    // Where the Sidekick was when the panel was last laid out: it follows when that changes.
    private var laidFor = floatArrayOf(Float.NaN, Float.NaN)

    /** The Sidekick moved (dragged by hand, or a dial): the panel follows it up and down. */
    fun follow() {
        if (width == 0) return
        if (Math.abs(lensX() - laidFor[0]) > 0.5f || Math.abs(lensY() - laidFor[1]) > 0.5f) layoutBox()
        invalidate()
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
        fun label(t: String, id: String = "") = parts.add(Part(Kind.LABEL, id, t, 20 * dp * fs))
        // (From build 187 the spacing is tighter: 10 points between sections, 6 from a section's
        // name to its control, 8 under the title. That brings the dials 40 points up, so that on the
        // S25, where the panel ends above Prism's bar, both are on the screen with room to spare.
        // Nothing is smaller; only the space between.)
        val section = 10f
        val under = 6f
        // (The header: "Sidekick", then "Dismiss" right after it, and the X at the right, 194. If a
        // large text size leaves no room for "Dismiss" there, clear of the X's touch, it goes on a
        // line of its own under the title.)
        titleW = measure("Sidekick", 22f, 700, true)
        dismissBelow = titleW + DISMISS_GAP * dp + dismissW() + DISMISS_SLACK * dp > innerW - 50 * dp
        parts.add(Part(Kind.TITLE, "close", "Sidekick", (if (dismissBelow) 88 else 44) * dp))
        gap(8f)
        // (From build 186 the dials come before the two switches, so that they are on the screen
        // without scrolling, within the thumb's reach; the switches, rarely used, are at the end.)
        label("Labels"); gap(under)
        parts.add(Part(Kind.PICKER, "names", "", 48 * dp, listOf("Show", "Hide")))
        gap(section)
        label("Icons"); gap(under)
        parts.add(Part(Kind.PICKER, "prismIcons", "", 48 * dp, listOf("Prism", "Regular")))
        gap(section)
        label("Colours"); gap(under)
        parts.add(Part(Kind.PICKER, "vivid", "", 48 * dp, listOf("Mellow", "Vivid")))
        gap(section)
        label("Look"); gap(under)
        parts.add(Part(Kind.LOOKS, "look", "", lookRows() * lookCellH() + (lookRows() - 1) * 12 * dp))
        gap(section)
        label("Where it rests, in points", "rests"); gap(under)
        parts.add(Part(Kind.RULERS, "rulers", "", (18 * fs + 6) * dp + pillH()))
        gap(section)
        parts.add(Part(Kind.SWITCH, "inApp", "In Prism", 48 * dp))
        gap(12f)
        parts.add(Part(Kind.SWITCH, "overApps", "Over other apps", 48 * dp))
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
        if (dismissHeld) {
            dismissHeld = false
            holdP = 0f
            holdEnded = "the panel closed"
        }
        Trail.add("Sidekick: its own settings closing, ${age()} ms after they opened: $reason")
        endRuler(save = true, back = false, why = "let go as the panel closed")
        removeCallbacks(settle)
        settling = false
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
            moving = stepHold(dt) or moving
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
    // The panel's own outline as this frame draws it. Kept apart from [rr], which the switches and
    // pickers use as they draw: until 188 the solid "Where it rests" pass clipped to [rr] after the
    // contents had drawn, so to the last switch's knob, and was never seen on the screen.
    private val outline = RectF()
    private val clip = Path()

    // (What the panel drew, for the recorder and the button test: how many frames, and the last
    // one's rectangle, whether it lay over the Sidekick's glass, and how faded it was.)
    var draws = 0
        private set
    private val lastRect = RectF()
    private var lastCovers = false
    private var lastFade = 1f

    private fun clipOut(canvas: Canvas, path: Path) {
        if (Build.VERSION.SDK_INT >= 26) canvas.clipOutPath(path) else {
            @Suppress("DEPRECATION")
            canvas.clipPath(path, android.graphics.Region.Op.DIFFERENCE)
        }
    }

    private fun smooth(t: Float) = t * t * (3 - 2 * t)

    // While a dial is held, how see-through the rest of the panel goes: all the way (1.0: it is
    // not drawn at all, the owner's choice in 191; 0.2 in 189 and 190, 0.4 in 186 to 188). The
    // whole "Where it rests" section stays solid: its title and both dials, on a backing of its own
    // (build 187; 186 kept only the dial held).
    private val REST_SEE = 1.0f

    // The dial held, or just let go ("" when none): while it is set, "Where it rests" is drawn
    // solid, apart from the see-through panel.
    private var solidDial = ""

    // Whether [p] is part of the "Where it rests" section, drawn apart (solid) while a dial is held.
    private var drawingApart = false
    private fun heldApart(p: Part): Boolean =
        solidDial.isNotEmpty() && !drawingApart && (p.kind == Kind.RULERS || p.id == "rests")

    // (For the test: what was drawn solid in the last frame, and at what alpha; and the rest's.)
    private var lastSolidParts: List<String> = emptyList()
    private var lastSolidAlpha = 0f

    // The two dials are kept out of Android's back gesture: the outer one lies within a few dozen
    // points of the screen's edge, where a sideways stroke could otherwise be taken away from it.
    private var excluded: List<android.graphics.Rect> = emptyList()

    private fun excludeDials() {
        if (Build.VERSION.SDK_INT < 29) return
        val part = parts.firstOrNull { it.kind == Kind.RULERS }
        val want = ArrayList<android.graphics.Rect>()
        if (part != null && opened && !closing) for (it in listOf("gap", "tuck")) {
            val b = rulerBox(it, box.left + pad, box.top + part.y - scroll)
            b.inset(-4 * dp, -10 * dp)
            want.add(android.graphics.Rect(b.left.toInt(), b.top.toInt(), b.right.toInt(), b.bottom.toInt()))
        }
        // (194) The Sidekick's spot too, at its edge: this window covers the whole screen, and
        // Android honours the Sidekick's own exclusion only where no touchable window lies over it.
        // Its window and 24 points above and below, from the edge, at least 80 points wide.
        if (!closing && g.value > 0.02f) {
            val x = lensX()
            val y = lensY()
            val half = sr + 5 * dp
            val left = x < width / 2f
            want.add(android.graphics.Rect(
                if (left) 0 else Math.min(x - half, width - 80 * dp).toInt(),
                (y - half - 24 * dp).toInt(),
                if (left) Math.max(x + half, 80 * dp).toInt() else width,
                (y + half + 24 * dp).toInt(),
            ))
        }
        if (want != excluded) {
            excluded = want
            systemGestureExclusionRects = want
        }
    }

    override fun onDraw(canvas: Canvas) {
        if (width == 0) return
        draws++
        lastSolidParts = emptyList()
        lastSolidAlpha = 0f
        val t = g.value.coerceIn(0f, 1.2f)
        // (No shade: from build 185 nothing is drawn round the Sidekick or the panel.)
        // The panel, from the Sidekick's circle to its own place.
        val tt = t.coerceAtLeast(0f)
        val lx = lensX()
        val ly = lensY()
        val l = lerp(lx - sr, box.left, tt)
        val top = lerp(ly - sr, box.top, tt)
        val r = lerp(lx + sr, box.right, tt)
        val b = lerp(ly + sr, box.bottom, tt)
        outline.set(l, top, r, b)
        lastRect.set(outline)
        lastCovers = covers(outline)
        // It fades in as it grows out of the Sidekick and out as it shrinks back in: while it is
        // small it is all but clear, so no dark box is ever seen round the Sidekick. While a dial
        // is held it is gone (191), but for "Where it rests", to see where the Sidekick goes; on the
        // dial's spring.
        val grown = smooth((tt / 0.4f).coerceIn(0f, 1f))
        val fade = grown * (1f - REST_SEE * clear.value.coerceIn(0f, 1f))
        lastFade = fade
        val bodyAlpha = 1f - REST_SEE * clear.value.coerceIn(0f, 1f)
        if (clear.value >= 0.98f) holding = true
        if (holding && (ruler.isNotEmpty() || settling)) {
            heldAlphaMost = Math.max(heldAlphaMost, bodyAlpha)
            heldFrames++
        }
        if (solidDial.isNotEmpty() && ruler.isEmpty() && !settling && clear.target == 0f && clear.value < 0.01f) solidDial = ""
        if (letGoAt > 0L && ruler.isEmpty() && bodyAlpha > 0.97f) {
            solidAfterMs = SystemClock.uptimeMillis() - letGoAt
            letGoAt = 0L
        }
        excludeDials()
        // (Wholly see-through while a dial is held (191), the panel itself draws nothing, edge and
        // hairline included; "Where it rests" is still drawn, solid, below.)
        val body = fade >= 0.004f
        if (tt < 0.002f || (!body && solidDial.isEmpty())) return
        val corner = lerp(sr, 36 * dp, tt.coerceIn(0f, 1f))
        val outer = canvas.save()
        // The Sidekick's glass is never drawn over: the panel has a hole where the Sidekick is,
        // through which the Sidekick (its own window, under this one) shows on every frame,
        // whether the panel is growing, shrinking, open, or the Sidekick is dragged across it.
        clip.reset()
        clip.addCircle(lx, ly, sr, Path.Direction.CW)
        clipOut(canvas, clip)
        if (body && fade < 0.999f) canvas.saveLayerAlpha(outline, (fade * 255).toInt())
        if (body) {
            paint.style = Paint.Style.FILL
            paint.color = cSurface
            canvas.drawRoundRect(outline, corner, corner, paint)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1 * dp
            paint.color = cHairline
            canvas.drawRoundRect(outline, corner, corner, paint)
            paint.style = Paint.Style.FILL
        }
        // Its contents come in between 5% and 30% of the way, as in Prism; drawn at their own
        // size, scaled with the panel, as Prism's transform does.
        val a = ((tt - 0.05f) / 0.25f).coerceIn(0f, 1f)
        if (opened && !closing && !sampling) leastSinceOpen = Math.min(leastSinceOpen, a)
        if (body && a > 0.001f) {
            canvas.save()
            clip.reset()
            clip.addRoundRect(outline, corner, corner, Path.Direction.CW)
            canvas.clipPath(clip)
            val sxk = (r - l) / box.width()
            val syk = (b - top) / box.height()
            canvas.translate(l, top)
            canvas.scale(sxk, syk)
            canvas.translate(-box.left, -box.top)
            val layer = canvas.saveLayerAlpha(box.left, box.top, box.right, box.bottom, (a * 255).toInt())
            canvas.translate(box.left, box.top - scroll)
            for (p in parts) drawPart(canvas, p)
            drawHoldBubble(canvas)
            canvas.restoreToCount(layer)
            canvas.restore()
        }
        // While a dial is held (or just let go): the whole "Where it rests" section, its title and
        // both dials, drawn solid over the see-through panel, on a backing of the panel's own colour,
        // so it reads as one solid block whatever is behind.
        val title = parts.firstOrNull { it.id == "rests" }
        val dials = parts.firstOrNull { it.kind == Kind.RULERS }
        if (solidDial.isNotEmpty() && a > 0.001f && grown > 0.004f && title != null && dials != null) {
            canvas.restoreToCount(outer)
            val keep = canvas.save()
            clip.reset()
            clip.addCircle(lx, ly, sr, Path.Direction.CW)
            clipOut(canvas, clip)
            clip.reset()
            clip.addRoundRect(outline, corner, corner, Path.Direction.CW)
            canvas.clipPath(clip)
            canvas.translate(l, top)
            canvas.scale((r - l) / box.width(), (b - top) / box.height())
            canvas.translate(0f, -scroll)
            val sa = Math.min(grown, a)
            if (sa < 0.999f) canvas.saveLayerAlpha(0f, scroll, box.width(), scroll + box.height(), (sa * 255).toInt())
            val back = RectF(pad - 10 * dp, title.y - 8 * dp, pad + innerW + 10 * dp, dials.y + dials.h + 8 * dp)
            paint.style = Paint.Style.FILL
            paint.color = cSurface
            canvas.drawRoundRect(back, 22 * dp, 22 * dp, paint)
            // (Its edge shows only as the rest goes see-through, and goes as the rest comes back: at
            // the start and the end, the block is the panel itself, with nothing popping in or out.)
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1 * dp
            paint.color = alpha(cHairline, clear.value.coerceIn(0f, 1f))
            canvas.drawRoundRect(back, 22 * dp, 22 * dp, paint)
            paint.style = Paint.Style.FILL
            drawingApart = true
            drawPart(canvas, title)
            drawPart(canvas, dials)
            drawingApart = false
            lastSolidParts = listOf("title", "gap", "tuck")
            lastSolidAlpha = sa
            canvas.restoreToCount(keep)
            return
        }
        canvas.restoreToCount(outer)
    }

    // Whether the panel, where it is now, lies over the Sidekick (any of its glass).
    private fun covers(panel: RectF): Boolean {
        val x = lensX()
        val y = lensY()
        val nx = x.coerceIn(panel.left, panel.right)
        val ny = y.coerceIn(panel.top, panel.bottom)
        return Math.hypot((x - nx).toDouble(), (y - ny).toDouble()) < sr + 2 * dp
    }

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    // The Sidekick's middle now (it may have moved while a dial was held): from its window.
    private fun lensX(): Float = (RestBubble.lensOnScreen()?.get(0) ?: sx) - origin[0]
    private fun lensY(): Float = (RestBubble.lensOnScreen()?.get(1) ?: sy) - origin[1]

    // ---- "Dismiss" (193): the only way to send the Sidekick away. A pill in the header, left of the
    // X (which only closes the panel), in the style of the panel's own controls.
    private var dismissBelow = false

    private fun measure(s: String, size: Float, weight: Int, display: Boolean = false): Float {
        text.typeface = if (display) PanelType.display(context, weight, size) else PanelType.inter(context, weight, size)
        text.textSize = size * dp * fs
        text.letterSpacing = if (display) -0.02f else (if (size < 13) 0.01f else -0.006f)
        return text.measureText(s)
    }

    private fun dismissW(): Float = measure("Dismiss", 15f, 600) + 2 * 16 * dp

    // ---- Hold to dismiss (195, the owner's "I-05 Hold to confirm", their numbers). Held, a fill
    // sweeps across the pill from left to right over 1.2 s, with a light tick at a quarter, half and
    // three quarters, and a heavy one at the end; the pill shakes a little, more as it fills, and
    // shrinks a little. Let go or slid off before the end: the fill drains back on a spring, and
    // nothing happens. At the end: a small pop, "Dismissed", then the panel closes and the
    // Sidekick is sent away as before (193). The pill keeps the word "Dismiss" (194's size, beside
    // the title, the owner's choice); what to do is said in a small dark bubble just under it,
    // while it is pressed and for 1.2 s after a short tap: "Hold to dismiss", "Keep holding…",
    // "Dismissed" (the review chat's choice (c), 195: those labels do not fit beside the title).
    private val HOLD_REST = "Hold to dismiss"
    private val HOLD_HELD = "Keep holding…"
    private val HOLD_DONE = "Dismissed"
    private val HOLD_MS = 1200f
    private val BUBBLE_STAYS_MS = 1200L
    private var dismissHeld = false
    private var holdFrom = 0L
    private var holdP = 0f
    private var holdDone = false
    private var holdTicks = 0
    private val holdDrain = Spring(90f, 1f).also { it.k = 90f; it.c = 19f }
    private var draining = false
    private val holdPop = Spring(420f, 0.25f, 1f).also { it.k = 420f; it.c = 10f }
    private var lastBuzz = 0L
    // (For the test: the most it filled, how it last ended, when it let go and how long the fill
    // took to drain back, and each haptic given, with where the fill was.)
    private var holdMost = 0f
    private var holdEnded = ""
    private var holdLetGoAt = 0L
    private var holdDrainMs = -1L
    private var holdAt500 = -1f
    private val holdBuzzes = ArrayList<String>()
    // The bubble: how much it shows (0 to 1), and until when it stays after a let-go.
    private val holdBubble = Spring(Springs.effects.first, Springs.effects.second)
    private var bubbleUntil = 0L
    private val bubbleBox = RectF()
    private var bubbleSeen = false

    /** At most one haptic every 28 ms. */
    private fun buzz(kind: String, what: String) {
        val now = android.os.SystemClock.uptimeMillis()
        if (now - lastBuzz < 28) return
        lastBuzz = now
        holdBuzzes.add(what)
        haptic(kind)
    }

    private fun startHold() {
        if (holdDone || closing) return
        dismissHeld = true
        draining = false
        holdFrom = android.os.SystemClock.uptimeMillis() - (holdP * HOLD_MS).toLong()
        holdTicks = (holdP / 0.25f).toInt().coerceIn(0, 3)
        holdMost = 0f
        holdBuzzes.clear()
        holdDrainMs = -1L
        holdAt500 = -1f
        holdEnded = ""
        run()
    }

    /** Let go, or slid off, before the end: the fill drains back, and nothing happens. */
    private fun letGoHold(why: String) {
        if (!dismissHeld) return
        dismissHeld = false
        holdEnded = why
        holdLetGoAt = android.os.SystemClock.uptimeMillis()
        holdDrain.jump(holdP)
        holdDrain.to(0f)
        draining = true
        // (The bubble stays a moment, saying "Hold to dismiss", for a short tap above all.)
        bubbleUntil = holdLetGoAt + BUBBLE_STAYS_MS
        postDelayed({ run() }, BUBBLE_STAYS_MS + 16)
        Trail.add("Sidekick: Dismiss let go at ${(holdP * 100).toInt()}% ($why): nothing done")
        run()
    }

    /** The hold, a frame on; true while it is still moving. */
    private fun stepHold(dt: Float): Boolean {
        var moving = holdPop.step(dt)
        val now = android.os.SystemClock.uptimeMillis()
        holdBubble.to(if (dismissHeld || holdDone || now < bubbleUntil) 1f else 0f)
        moving = holdBubble.step(dt) or moving
        if (dismissHeld) {
            holdP = ((android.os.SystemClock.uptimeMillis() - holdFrom) / HOLD_MS).coerceIn(0f, 1f)
            holdMost = Math.max(holdMost, holdP)
            while (holdTicks < 3 && holdP >= (holdTicks + 1) * 0.25f) {
                holdTicks++
                buzz("tick", "light at ${holdTicks * 25}%")
            }
            if (holdP >= 1f) {
                dismissHeld = false
                holdDone = true
                holdEnded = "held to the end"
                buzz("thud", "heavy at 100%")
                holdPop.jump(0.88f)
                holdPop.to(1f)
                Trail.add("Sidekick: Dismiss held to the end")
                // (The pop and "Dismissed" seen, then the panel closes into the Sidekick, and the
                // Sidekick is sent away, 193.)
                // (Held to the end, it is sent away even if the panel was closed some other way meanwhile.)
                val main = android.os.Handler(android.os.Looper.getMainLooper())
                main.postDelayed({
                    SidekickPanel.close("Dismiss, held to the end")
                    main.postDelayed({ RestBubble.dismissSidekick() }, 280)
                }, 420)
            }
            moving = true
        } else if (draining) {
            val still = !holdDrain.step(dt)
            holdP = holdDrain.value.coerceIn(0f, 1f)
            val since = android.os.SystemClock.uptimeMillis() - holdLetGoAt
            if (holdAt500 < 0f && since >= 500) holdAt500 = holdP
            // (Drained: under 1%, less than a pixel or two of the pill.)
            if (still || holdP < 0.01f) {
                // (Drained before 0.5 s: empty then too.)
                if (holdAt500 < 0f) holdAt500 = 0f
                holdP = 0f
                draining = false
                holdDrainMs = android.os.SystemClock.uptimeMillis() - holdLetGoAt
            } else {
                moving = true
            }
        }
        return moving
    }

    // (Its place, 194: right after the title, 12 points from it; its touch reaches 6 points round
    // the 36-point pill, so 48 points tall, and stops short of the X's, which reaches 50 points in
    // from the right.)
    private var titleW = 0f
    private val DISMISS_GAP = 12f
    private val DISMISS_SLACK = 6f

    /** Where "Dismiss" is, in the panel's contents, for the header part [p]. */
    private fun dismissBox(p: Part): RectF {
        val w = dismissW()
        val h = 36 * dp
        val left = if (dismissBelow) pad else pad + titleW + DISMISS_GAP * dp
        val cy = if (dismissBelow) p.y + 44 * dp + 22 * dp else p.y + 22 * dp
        return RectF(left, cy - h / 2, left + w, cy + h / 2)
    }

    /** Where a finger counts as on "Dismiss": the pill and 6 points round it (48 tall), never reaching the X's touch. */
    private fun dismissTouch(p: Part): RectF {
        val b = dismissBox(p)
        val t = RectF(b.left - DISMISS_SLACK * dp, b.top - DISMISS_SLACK * dp, b.right + DISMISS_SLACK * dp, b.bottom + DISMISS_SLACK * dp)
        if (!dismissBelow) t.right = Math.min(t.right, pad + innerW - 50 * dp)
        return t
    }

    private fun drawText(canvas: Canvas, s: String, x: Float, baseline: Float, size: Float, weight: Int, color: Int, center: Boolean = false, display: Boolean = false) {
        text.typeface = if (display) PanelType.display(context, weight, size) else PanelType.inter(context, weight, size)
        text.textSize = size * dp * fs
        text.color = color
        text.letterSpacing = if (display) -0.02f else (if (size < 13) 0.01f else -0.006f)
        val w = text.measureText(s)
        canvas.drawText(s, if (center) x - w / 2f else x, baseline, text)
    }

    private val innerW get() = box.width() - 2 * pad

    // "Hold to dismiss": a pill, as the panel's other controls are, never round like the X (195).
    private val holdClip = Path()

    private fun drawDismiss(canvas: Canvas, p: Part) {
        val db = dismissBox(p)
        val r = db.height() / 2
        val held = dismissHeld || draining
        // (Its shake: sin(t / 14 ms) × p² × 2.2 points, while held; and 1 − 0.035 × p smaller.)
        val shake = if (dismissHeld) (Math.sin((android.os.SystemClock.uptimeMillis() - holdFrom) / 14.0) * holdP * holdP * 2.2 * dp).toFloat() else 0f
        val scale = (if (holdDone) 1f else 1f - 0.035f * holdP) * holdPop.value
        canvas.save()
        canvas.translate(db.centerX() + shake, db.centerY())
        canvas.scale(scale, scale)
        canvas.translate(-db.centerX(), -db.centerY())
        paint.style = Paint.Style.FILL
        paint.color = alpha(cInk, if (held) 0.12f else 0.08f)
        canvas.drawRoundRect(db, r, r, paint)
        val label = "Dismiss"
        val base = db.centerY() + 5 * dp * fs
        drawText(canvas, label, db.centerX(), base, 15f, 600, cInk, center = true)
        // The fill, left to right, with the label in the accent's own ink where it has reached.
        val fill = if (holdDone) 1f else holdP
        if (fill > 0f) {
            holdClip.reset()
            holdClip.addRoundRect(db, r, r, Path.Direction.CW)
            canvas.save()
            canvas.clipPath(holdClip)
            canvas.clipRect(db.left, db.top, db.left + db.width() * fill, db.bottom)
            paint.color = cAccent
            canvas.drawRect(db, paint)
            drawText(canvas, label, db.centerX(), base, 15f, 600, cOnAccent, center = true)
            canvas.restore()
        }
        canvas.restore()
    }

    private fun bubbleLabel() = when {
        holdDone -> HOLD_DONE
        dismissHeld -> HOLD_HELD
        else -> HOLD_REST
    }

    /**
     * The bubble just under the pill (in the contents' own points), kept inside the panel. It
     * begins below the title's row, so it never covers the X.
     */
    private fun bubbleRect(p: Part): RectF {
        val db = dismissBox(p)
        val w = measure(bubbleLabel(), 13f, 600) + 2 * 11 * dp
        val h = 30 * dp * Math.max(1f, fs)
        val top = Math.max(db.bottom + 8 * dp, p.y + 44 * dp + 4 * dp)
        val left = (db.centerX() - w / 2).coerceIn(pad / 2, Math.max(pad / 2, box.width() - pad / 2 - w))
        return RectF(left, top, left + w, top + h)
    }

    private val bubblePath = Path()

    /** Drawn over the rest of the contents, while it shows. */
    private fun drawHoldBubble(canvas: Canvas) {
        val v = holdBubble.value.coerceIn(0f, 1f)
        val p = parts.firstOrNull { it.kind == Kind.TITLE }
        if (v <= 0.01f || p == null) {
            bubbleSeen = false
            return
        }
        val b = bubbleRect(p)
        bubbleBox.set(b)
        bubbleSeen = true
        val db = dismissBox(p)
        canvas.save()
        // (It grows a little out of the pill as it shows.)
        val k = 0.9f + 0.1f * v
        canvas.scale(k, k, db.centerX(), b.top)
        paint.style = Paint.Style.FILL
        paint.color = alpha(0xFF1B1C1F.toInt(), 0.94f * v)
        canvas.drawRoundRect(b, 9 * dp, 9 * dp, paint)
        // Its point, up toward the pill.
        val px = db.centerX().coerceIn(b.left + 12 * dp, b.right - 12 * dp)
        bubblePath.reset()
        bubblePath.moveTo(px - 6 * dp, b.top + 0.5f)
        bubblePath.lineTo(px, b.top - 6 * dp)
        bubblePath.lineTo(px + 6 * dp, b.top + 0.5f)
        bubblePath.close()
        canvas.drawPath(bubblePath, paint)
        if (dark) {
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1 * dp
            paint.color = alpha(0xFFFFFFFF.toInt(), 0.14f * v)
            canvas.drawRoundRect(b, 9 * dp, 9 * dp, paint)
            paint.style = Paint.Style.FILL
        }
        drawText(canvas, bubbleLabel(), b.centerX(), b.centerY() + 4.5f * dp * fs, 13f, 600, alpha(0xFFF2EFE8.toInt(), v), center = true)
        canvas.restore()
    }

    private fun drawPart(canvas: Canvas, p: Part) {
        val x0 = pad
        val y = p.y
        when (p.kind) {
            Kind.GAP -> {}
            Kind.TITLE -> {
                drawText(canvas, p.label, x0, y + 30 * dp, 22f, 700, cInk, display = true)
                drawDismiss(canvas, p)
                paint.style = Paint.Style.FILL
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
            Kind.LABEL -> if (!heldApart(p)) drawText(canvas, p.label, x0, y + 15 * dp * fs, 15f, 560, cInk)
            Kind.SWITCH -> {
                drawText(canvas, p.label, x0, y + 24 * dp + 5 * dp * fs, 15f, 560, cInk)
                drawSwitch(canvas, p.id, x0 + innerW - 57 * dp, y + 8 * dp)
            }
            Kind.PICKER -> drawPicker(canvas, p, x0, y)
            Kind.LOOKS -> drawLooks(canvas, x0, y)
            Kind.RULERS -> if (!heldApart(p)) drawRulers(canvas, x0, y)
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
        return RectF(left, top, left + w, top + pillH())
    }

    // A dial's pill: 52 points tall, and taller at a large text size, so that its number, 6 points
    // of space, its ticks and 10 points under them always fit inside, with room at the top (188).
    private fun pillH(): Float = Math.max(52f, 32f + 14f * fs) * dp
    private val tickClip = Path()

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
            // They stay inside the pill's rounded outline with room to spare (188: until then they
            // were clipped only to its square box, so the outer ones ran past its rounded ends, 5
            // points from its bottom edge): 10 points above its bottom, and at the sides clear of
            // its rounded ends by 6 points, at the height of the lowest tick.
            canvas.save()
            tickClip.reset()
            tickClip.addRoundRect(b.left + 4 * dp, b.top + 4 * dp, b.right - 4 * dp, b.bottom - 4 * dp, b.height() / 2 - 4 * dp, b.height() / 2 - 4 * dp, Path.Direction.CW)
            canvas.clipPath(tickClip)
            val mid = b.centerX()
            val tickH = 8 * dp
            val tickBottom = b.bottom - 10 * dp
            val tickTop = tickBottom - tickH
            val end = b.height() / 2
            val rise = end - (b.bottom - tickBottom)
            val endInset = end - Math.sqrt((end * end - rise * rise).toDouble()).toFloat()
            val halfSpan = b.width() / 2 - endInset - 6 * dp
            val radius = halfSpan / Math.sin(1.45).toFloat()
            val spacing = 0.2
            val turn = (wheel[id] ?: 0f) / radius
            val phase = ((turn % spacing) + spacing) % spacing
            paint.style = Paint.Style.STROKE
            paint.strokeWidth = 1.6f * dp
            paint.strokeCap = Paint.Cap.ROUND
            var a = -1.45 + phase
            val tc = mix(cInkFaint, cAccent, on)
            while (a < 1.45) {
                val px = mid + radius * Math.sin(a).toFloat()
                val depth = Math.cos(a).toFloat()
                paint.color = alpha(tc, (depth * depth).coerceIn(0f, 1f))
                if (!hideTicks) canvas.drawLine(px, tickTop + tickH * (1 - depth) * 0.5f, px, tickBottom, paint)
                a += spacing
            }
            paint.style = Paint.Style.FILL
            canvas.restore()
            val v = if (id == "gap") SidekickSettings.gap else SidekickSettings.tuck
            // (Below 0, Hovering is past the edge: a true minus sign, as the number is set.)
            drawText(canvas, "${Math.round(v)}".replace('-', '\u2212'), mid, b.bottom - 24 * dp, 19f, 700, if (hideNumbers) 0 else cInk, center = true)
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
                    if (dismissTouch(p).contains(cx, cy)) return "dismiss"
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

    // A gesture that began on the Sidekick (its window lies under this one): all of it is the
    // Sidekick's, handed on as the grip hands on its touches. A tap closes the panel; a drag
    // moves the Sidekick, and the panel follows it (build 185).
    private var toLens = false

    override fun onTouchEvent(e: MotionEvent): Boolean {
        if (e.actionMasked == MotionEvent.ACTION_DOWN) toLens = !closing && hit(e.x, e.y) == "sidekick"
        if (toLens) {
            RestBubble.touchLens(e)
            if (e.actionMasked == MotionEvent.ACTION_UP || e.actionMasked == MotionEvent.ACTION_CANCEL) toLens = false
            return true
        }
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
                if (target == "dismiss") startHold()
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
                // (Slid off "Hold to dismiss" before the end: it drains back, 195.)
                if (dismissHeld && hit(e.x, e.y) != "dismiss") letGoHold("slid off")
                if (ruler.isNotEmpty()) {
                    moveRuler(dx)
                } else if (scrolling) {
                    scroll = (scroll - dy).coerceIn(0f, maxScroll())
                    invalidate()
                } else if (Math.abs(e.y - downY) > slop && box.contains(downX, downY) && maxScroll() > 0f) {
                    scrolling = true
                    letGoHold("scrolled")
                    unpress()
                }
            }
            MotionEvent.ACTION_UP -> {
                tracker?.addMovement(e)
                tracker?.computeCurrentVelocity(1000)
                val vx = tracker?.xVelocity ?: 0f
                val vy = tracker?.yVelocity ?: 0f
                val tap = Math.hypot((e.x - downX).toDouble(), (e.y - downY).toDouble()) < slop
                letGoHold("let go")
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
                letGoHold("taken away by Android (cancel)")
                if (ruler.isNotEmpty()) endRuler(save = true, back = true, why = "taken away by Android (cancel)")
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
            // (A tap on "Hold to dismiss" only starts the fill, which drains back: it is held, 195.)
            id == "dismiss" -> {}
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
        removeCallbacks(settle)
        // (A finger back on a dial: how long after the last let-go, for the owner's report. It tells
        // how short the moment after a let-go can be.)
        if (letGoAt > 0L) Trail.add("Sidekick: its panel's dial held again ${SystemClock.uptimeMillis() - letGoAt} ms after it was let go${if (settling) ", carrying on" else ""}")
        if (settling) carriedOn++
        letGoAt = 0L
        settling = false
        if (!holding) {
            heldAlphaMost = 0f
            heldFrames = 0
        }
        Trail.add("Sidekick: its panel's dial ($id) held")
        solidDial = id
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

    /** The dial let go: kept; a tenth of a second later, the panel solid again and the Sidekick back to the state it was in. */
    private fun endRuler(save: Boolean, back: Boolean, why: String = "let go") {
        val id = ruler
        if (id.isEmpty()) return
        ruler = ""
        lifts[id]?.to(0f)
        if (save) {
            val v = Math.round(raw).toFloat()
            SidekickSettings.set(context, mapOf(id to v), null, keep = true, fromPanel = true)
        }
        Trail.add("Sidekick: its panel's dial ($id) $why")
        if (back) {
            // A dial is often turned in several short strokes. Let go, the panel stays see-through,
            // and the Sidekick where the dial put it, for a tenth of a second ([SETTLE_MS]): a
            // finger straight back on a dial carries on without a flash in between. Then both come
            // back at once, on the quick spring (186's 0.6 s was much too long; 185 had none).
            removeCallbacks(settle)
            postDelayed(settle, SETTLE_MS)
            settling = true
            letGoAt = SystemClock.uptimeMillis()
            solidAfterMs = -1L
        } else {
            clear.to(0f)
            holding = false
            solidDial = ""
        }
        run()
    }

    // How long after a dial is let go before the panel starts back to solid (on the quick spring,
    // about 0.12 s more) and the Sidekick goes back. Build 186 waited 0.6 s: much too long for the
    // owner. 0.1 s is about the shortest delay anyone notices, so the let-go still feels immediate;
    // yet a finger back on the dial within it carries straight on, with no flash in between. A
    // slower stroke sees the panel start back, and a stroke after about 0.2 s sees it solid: by
    // the owner's rule, it is solid again right away. (Build 187.)
    private val SETTLE_MS = 100L
    private var settling = false
    private val settle = Runnable {
        settling = false
        if (ruler.isEmpty() && !closing) {
            clear.to(0f)
            holding = false
            // ("Where it rests" stays drawn apart, solid, until the rest has come back to solid
            // too: dropped now, it would dip to the rest's 0.2 and come back with it. onDraw lets
            // it go once the rest is solid.)
            RestBubble.showSpot(wasTucked)
            run()
        }
    }

    // (For the test: from the moment the panel is see-through for a dial until it is solid again,
    // the most opaque it was drawn, and in how many frames. It must stay about half.)
    private var holding = false
    private var heldAlphaMost = 0f
    private var heldFrames = 0
    // When a dial was last let go (0 once the panel is solid again), and how long after that the
    // first frame was drawn solid again (over 0.97); -1 until then.
    private var letGoAt = 0L
    private var solidAfterMs = -1L
    // How many times a finger came back on a dial within the moment after a let-go, carrying on.
    private var carriedOn = 0

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
        // (No shade from build 185: always 0, kept so the test can say so.)
        "panelShade" to 0.0,
        // How opaque the panel's body and contents are: 1, or about 0.2 while a dial is held.
        "panelAlpha" to (1f - REST_SEE * clear.value.coerceIn(0f, 1f)).toDouble(),
        // The dial held ("" for none); what the last frame drew solid apart from the panel ("title",
        // "gap", "tuck": the whole "Where it rests" section) and at what alpha; each dial's alpha.
        "panelSolidDial" to solidDial,
        "panelSolidParts" to lastSolidParts,
        "panelSolidAlpha" to lastSolidAlpha.toDouble(),
        "panelDialAlpha" to (if (solidDial in lastSolidParts) lastSolidAlpha else lastFade).toDouble(),
        "panelDialsAlpha" to listOf("gap", "tuck").associateWith { (if (it in lastSolidParts) lastSolidAlpha else lastFade).toDouble() },
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
        // What the panel last drew: how many frames so far, its rectangle, whether it lay over the
        // Sidekick's glass, and how faded it was (with a hole where the Sidekick is, always).
        "panelDraws" to draws,
        "panelRect" to listOf((lastRect.left + origin[0]) / dp, (lastRect.top + origin[1]) / dp, lastRect.width() / dp, lastRect.height() / dp).map { it.toDouble() },
        "panelCovers" to lastCovers,
        "panelFade" to lastFade.toDouble(),
        "panelSr" to (sr / dp).toDouble(),
        // A dial's see-through, from the moment it is half until it is solid again: the most opaque
        // it was drawn, over how many frames, and whether it is in the moment after a let-go.
        "panelHeldAlphaMost" to heldAlphaMost.toDouble(),
        "panelHeldFrames" to heldFrames,
        "panelSettling" to settling,
        // How long after the last let-go the panel was drawn solid again (over 0.97); -1 if not yet.
        "panelSolidAfterMs" to solidAfterMs,
        // The header (194): where "Dismiss" and its touch are, where the title ends and the X's
        // touch begins, on the screen, in points.
        "panelHeader" to (parts.firstOrNull { it.kind == Kind.TITLE }?.let { p ->
            val ox = box.left + origin[0]
            val oy = box.top - scroll + origin[1]
            fun pts(r: RectF) = listOf((r.left + ox) / dp, (r.top + oy) / dp, r.width() / dp, r.height() / dp).map { it.toDouble() }
            hashMapOf(
                "dismiss" to pts(dismissBox(p)),
                "dismissTouch" to pts(dismissTouch(p)),
                "titleRight" to ((pad + titleW + ox) / dp).toDouble(),
                "closeTouchLeft" to ((pad + innerW - 50 * dp + ox) / dp).toDouble(),
                "below" to dismissBelow,
            )
        }),
        // Hold to dismiss (195): the fill now (0 to 1), whether it is held or draining, whether it
        // was held to the end, the most it filled, how it last ended, how long it took to drain
        // back after the last let-go (-1 if not yet), and each haptic, with where the fill was.
        "holdFill" to holdP.toDouble(),
        "holdHeld" to dismissHeld,
        "holdDraining" to draining,
        "holdDone" to holdDone,
        "holdMost" to holdMost.toDouble(),
        "holdEnded" to holdEnded,
        "holdDrainMs" to holdDrainMs,
        "holdAt500" to holdAt500.toDouble(),
        "holdBuzzes" to holdBuzzes.toList(),
        // The bubble under the pill: what it says, how much it shows, and where it is (on the
        // screen, in points; empty when not drawn), with the X's circle for the test to compare.
        "holdLabel" to bubbleLabel(),
        "holdBubble" to holdBubble.value.toDouble(),
        "holdBubbleBox" to (if (bubbleSeen) {
            val ox = box.left + origin[0]
            val oy = box.top - scroll + origin[1]
            listOf((bubbleBox.left + ox) / dp, (bubbleBox.top + oy) / dp, bubbleBox.width() / dp, bubbleBox.height() / dp).map { it.toDouble() }
        } else emptyList<Double>()),
        "closeBox" to (parts.firstOrNull { it.kind == Kind.TITLE }?.let { p ->
            val ox = box.left + origin[0]
            val oy = box.top - scroll + origin[1]
            listOf((pad + innerW - 44 * dp + ox) / dp, (p.y + oy) / dp, 44.0, 44.0).map { it.toDouble() }
        } ?: emptyList<Double>()),
        "panelCarriedOn" to carriedOn,
        // Where the panel may reach down to, and where the dials are now (on the screen, in points).
        "panelBottomLimit" to ((limitBottom + origin[1]) / dp).toDouble(),
        "panelTopLimit" to ((limitTop + origin[1]) / dp).toDouble(),
        "panelFills" to fills,
        "panelBarTop" to (RestBubble.barTop?.let { (it / dp).toDouble() }),
        "panelInPrism" to RestBubble.foreground,
        "panelDials" to (parts.firstOrNull { it.kind == Kind.RULERS }?.let { part ->
            listOf("gap", "tuck").map {
                val d = rulerBox(it, box.left + pad, box.top + part.y - scroll)
                listOf((d.left + origin[0]) / dp, (d.top + origin[1]) / dp, d.width() / dp, d.height() / dp).map { v -> v.toDouble() }
            }
        } ?: emptyList<List<Double>>()),
    )

    // ---- For the test: does the panel ever draw over the Sidekick's glass?
    private var sampling = false

    /**
     * Draws the panel as it is at [at] of the way open (closing passes through the same moments)
     * into a picture of the Sidekick's glass and a little round it, and reads what the panel put
     * there: at the glass's middle, and at 16 points round it at 85% of its radius. Both must be
     * empty (the Sidekick, in its own window under this one, shows there). And one point just
     * outside the glass, towards the panel, to show the panel itself was drawn. (Drawn in
     * software, off the screen: nothing is seen.)
     */
    // (Test only: the next drawing leaves out the dials' ticks or numbers, to find their pixels.)
    private var hideTicks = false
    private var hideNumbers = false

    /**
     * The "Where it rests" section as it is drawn now, read from its pixels (188: 187's check read
     * only what the code meant to draw, and passed while the phone showed nothing). It is drawn in
     * software three times, as it is, without the ticks and without the numbers, onto clear pixels;
     * the differences are the ticks and the numbers. Says:
     * - how opaque the section's own area is at its least (255 solid), and a point of the rest of
     *   the panel (in its left margin, halfway down: 0 while a dial is held, solid otherwise);
     * - for each dial, how many pixels its number has and how opaque they are at the least;
     * - for each dial, how many pixels its ticks have, how many of those lie outside its pill (its
     *   rounded outline, 2 points in), and the room under the lowest, in points.
     */
    fun testPixels(): HashMap<String, Any?> {
        val m = HashMap<String, Any?>()
        val title = parts.firstOrNull { it.id == "rests" }
        val dials = parts.firstOrNull { it.kind == Kind.RULERS }
        if (title == null || dials == null || width == 0) {
            m["pixNote"] = "no section to read"
            return m
        }
        val wasSampling = sampling
        sampling = true
        try {
            val top = box.top + title.y - scroll - 12 * dp
            val bottom = box.top + dials.y + dials.h - scroll + 12 * dp
            val w = Math.ceil(box.width().toDouble()).toInt()
            val h = Math.ceil((bottom - top).toDouble()).toInt()
            if (w <= 0 || h <= 0) {
                m["pixNote"] = "nothing to read"
                return m
            }
            val bmp = android.graphics.Bitmap.createBitmap(w, h, android.graphics.Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            fun render(ticks: Boolean, numbers: Boolean): IntArray {
                bmp.eraseColor(0)
                hideTicks = !ticks
                hideNumbers = !numbers
                try {
                    val keep = c.save()
                    c.translate(-box.left, -top)
                    draw(c)
                    c.restoreToCount(keep)
                } finally {
                    hideTicks = false
                    hideNumbers = false
                }
                val px = IntArray(w * h)
                bmp.getPixels(px, 0, w, 0, 0, w, h)
                return px
            }
            val all = render(true, true)
            val noTicks = render(false, true)
            val noNumbers = render(true, false)
            bmp.recycle()
            fun alphaAt(px: IntArray, x: Int, y: Int): Int =
                if (x in 0 until w && y in 0 until h) (px[y * w + x] ushr 24) and 0xFF else -1
            // The section's own area: from just above its title to just under the dials, across
            // its width, clear of its block's rounded corners.
            val sx0 = pad + 10 * dp
            val sx1 = pad + innerW - 10 * dp
            val sy0 = title.y - scroll - 2 * dp + box.top - top
            val sy1 = dials.y + dials.h - scroll + 2 * dp + box.top - top
            var least = 255
            for (i in 0..8) for (j in 0..4) {
                val x = (sx0 + (sx1 - sx0) * i / 8f).toInt()
                val y = (sy0 + (sy1 - sy0) * j / 4f).toInt()
                val a = alphaAt(all, x, y)
                if (a >= 0) least = Math.min(least, a)
            }
            m["pixBlockLeast"] = least
            // A point of the rest of the panel, drawn on its own: in its left margin, 5 points in,
            // halfway down. Nothing but the panel's own body is ever there (the "Where it rests"
            // block starts 10 points in), it is inside the panel whatever the scroll, and it is solid
            // when the panel is. (Until 191 it was on the Labels row, which on the S25 the test's
            // earlier taps on the two switches had scrolled out above the panel's top: 189 read 0.)
            run {
                val one = android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
                val c1 = Canvas(one)
                c1.translate(-(box.left + 5 * dp), -(box.top + box.height() / 2f))
                draw(c1)
                m["pixRest"] = (one.getPixel(0, 0) ushr 24) and 0xFF
                one.recycle()
            }
            for (id in listOf("gap", "tuck")) {
                val k = 1 + 0.06f * (lifts[id]?.value ?: 0f)
                val b0 = rulerBox(id, pad, dials.y - scroll)
                // (Held, the pill is drawn a little larger, about its middle.)
                val b = RectF(b0.centerX() - b0.width() * k / 2, b0.centerY() - b0.height() * k / 2, b0.centerX() + b0.width() * k / 2, b0.centerY() + b0.height() * k / 2)
                b.offset(0f, box.top - top)
                val inside = RectF(b.left + 2 * dp, b.top + 2 * dp, b.right - 2 * dp, b.bottom - 2 * dp)
                val r = inside.height() / 2
                fun inPill(x: Float, y: Float): Boolean {
                    if (!inside.contains(x, y)) return false
                    val cx = x.coerceIn(inside.left + r, inside.right - r)
                    return Math.hypot((x - cx).toDouble(), (y - inside.centerY()).toDouble()) <= r
                }
                var numberPx = 0
                var numberLeast = 255
                var tickPx = 0
                var tickOut = 0
                var lowest = -1
                val x0 = Math.max(0, b.left.toInt() - 4)
                val x1 = Math.min(w - 1, b.right.toInt() + 4)
                val y0 = Math.max(0, b.top.toInt() - 4)
                val y1 = Math.min(h - 1, b.bottom.toInt() + 4)
                for (y in y0..y1) for (x in x0..x1) {
                    val i = y * w + x
                    if (all[i] != noNumbers[i]) {
                        numberPx++
                        numberLeast = Math.min(numberLeast, (all[i] ushr 24) and 0xFF)
                    }
                    if (all[i] != noTicks[i]) {
                        tickPx++
                        if (!inPill(x + 0.5f, y + 0.5f)) tickOut++
                        lowest = Math.max(lowest, y)
                    }
                }
                m["pix${id}NumberPx"] = numberPx
                m["pix${id}NumberLeast"] = if (numberPx == 0) 0 else numberLeast
                m["pix${id}TickPx"] = tickPx
                m["pix${id}TickOutside"] = tickOut
                m["pix${id}TickRoom"] = if (lowest < 0) -1.0 else ((b.bottom - (lowest + 1)) / dp).toDouble()
            }
            m["pixFontScale"] = fs.toDouble()
            // (How opaque the panel's own colour is: the most anything solid on it can be.)
            m["pixSurfaceAlpha"] = (cSurface ushr 24) and 0xFF
            m["pixHeld"] = solidDial
        } catch (e: Exception) {
            m["pixNote"] = "could not be read: ${e.javaClass.simpleName}"
        } finally {
            sampling = wasSampling
        }
        return m
    }

    fun testSample(at: Float): HashMap<String, Any?> {
        val was = g.value
        sampling = true
        val lx = lensX()
        val ly = lensY()
        val n = Math.ceil(1.5 * sr).toInt()
        val m = HashMap<String, Any?>()
        try {
            g.value = at
            val rect = RectF(lerp(lx - sr, box.left, at), lerp(ly - sr, box.top, at), lerp(lx + sr, box.right, at), lerp(ly + sr, box.bottom, at))
            m["sampleAt"] = at.toDouble()
            m["sampleCovers"] = covers(rect)
            m["sampleRect"] = listOf((rect.left + origin[0]) / dp, (rect.top + origin[1]) / dp, rect.width() / dp, rect.height() / dp).map { it.toDouble() }
            m["sampleLens"] = listOf((lx + origin[0]) / dp, (ly + origin[1]) / dp).map { it.toDouble() }
            m["sampleSr"] = (sr / dp).toDouble()
            val bmp = android.graphics.Bitmap.createBitmap(2 * n + 1, 2 * n + 1, android.graphics.Bitmap.Config.ARGB_8888)
            val c = Canvas(bmp)
            c.translate(-lx + n, -ly + n)
            val before = draws
            draw(c)
            m["sampleDraws"] = draws - before
            m["sampleFade"] = lastFade.toDouble()
            m["sampleMiddle"] = (bmp.getPixel(n, n) ushr 24) and 0xFF
            var ring = 0
            for (k in 0 until 16) {
                val a = 2 * Math.PI * k / 16
                val x = (n + 0.85 * sr * Math.cos(a)).toInt().coerceIn(0, 2 * n)
                val y = (n + 0.85 * sr * Math.sin(a)).toInt().coerceIn(0, 2 * n)
                ring = Math.max(ring, (bmp.getPixel(x, y) ushr 24) and 0xFF)
            }
            m["sampleRing"] = ring
            // (Just outside the glass, towards the middle of the screen, where the panel lies.)
            val toward = if (onRight) -1 else 1
            val cx = (n + toward * 1.3 * sr).toInt().coerceIn(0, 2 * n)
            m["sampleBeside"] = (bmp.getPixel(cx, n) ushr 24) and 0xFF
            bmp.recycle()
        } finally {
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
            Kind.TITLE -> if (sub == "dismiss" || id == "dismiss") dismissBox(p).let { floatArrayOf(it.centerX(), it.centerY()) } else floatArrayOf(pad + innerW - 22 * dp, p.y + 22 * dp)
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
