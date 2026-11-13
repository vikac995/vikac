package dev.lumen.lumen

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import android.os.VibrationAttributes
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestHighestRefreshRate()
    }

    private var device: MethodChannel? = null

    // Coming back from another app. Android throws away the surface an app draws on once the app
    // is out of sight, and until the app has drawn a new frame the window shows its plain
    // background: a dark, empty screen for a moment under the app that is shrinking away.
    // So just before leaving, the last frame is copied and made the window's background.
    // On return that picture is what shows until the first real frame replaces it.
    private var lastFrame: android.graphics.Bitmap? = null

    private fun surfaceIn(v: android.view.View): android.view.SurfaceView? {
        if (v is android.view.SurfaceView) return v
        if (v is android.view.ViewGroup) {
            for (i in 0 until v.childCount) {
                val found = surfaceIn(v.getChildAt(i))
                if (found != null) return found
            }
        }
        return null
    }

    // Prism has left the screen: if a rest is running, its countdown floats over whatever comes next.
    override fun onStop() {
        super.onStop()
        RestBubble.show(applicationContext)
    }

    override fun onStart() {
        super.onStart()
        RestBubble.onForeground(applicationContext)
    }

    override fun onPause() {
        try {
            val surface = surfaceIn(window.decorView)
            if (surface != null && surface.width > 0 && surface.height > 0 && surface.holder.surface.isValid) {
                var bmp = lastFrame
                if (bmp == null || bmp.width != surface.width || bmp.height != surface.height) {
                    bmp = android.graphics.Bitmap.createBitmap(surface.width, surface.height, android.graphics.Bitmap.Config.ARGB_8888)
                    lastFrame = bmp
                }
                val target = bmp!!
                android.view.PixelCopy.request(surface, target, { result ->
                    if (result == android.view.PixelCopy.SUCCESS) {
                        window.setBackgroundDrawable(android.graphics.drawable.BitmapDrawable(resources, target))
                    }
                }, android.os.Handler(android.os.Looper.getMainLooper()))
            }
        } catch (e: Exception) {
            // Without the picture, returning simply looks as it did before.
        }
        super.onPause()
    }

    // The home button was pressed while Prism is the home screen: tell the app, so it can go back to its first page.
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (intent.action == RestBubble.OPEN_TRAIN) {
            device?.invokeMethod("train", null)
        } else if (intent.hasCategory(android.content.Intent.CATEGORY_HOME)) {
            device?.invokeMethod("home", null)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Direct access to the vibration motor, for haptics that must be felt
        // even without a finger on the screen (the disco beat).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/haptics").setMethodCallHandler { call, result ->
            if (call.method == "play") {
                play(call.arguments as? String ?: "tick")
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        // The apps installed on this phone, for the launcher experiments: names, icons, and opening one.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/apps").setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> Thread {
                    try {
                        val pm = packageManager
                        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER)
                        val out = ArrayList<Map<String, Any>>()
                        for (r in pm.queryIntentActivities(intent, 0)) {
                            val d = r.loadIcon(pm)
                            val bmp = android.graphics.Bitmap.createBitmap(144, 144, android.graphics.Bitmap.Config.ARGB_8888)
                            val c = android.graphics.Canvas(bmp)
                            d.setBounds(0, 0, 144, 144)
                            d.draw(c)
                            val bytes = java.io.ByteArrayOutputStream()
                            bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, bytes)
                            out.add(mapOf("label" to r.loadLabel(pm).toString(), "package" to r.activityInfo.packageName, "icon" to bytes.toByteArray()))
                        }
                        runOnUiThread { result.success(out) }
                    } catch (e: Exception) {
                        runOnUiThread { result.error("apps", e.message, null) }
                    }
                }.start()
                "names" -> Thread {
                    // Every app on the home screen: its name, package and when it last changed. No pictures, so it is quick.
                    val out = ArrayList<Map<String, Any>>()
                    try {
                        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER)
                        for (r in packageManager.queryIntentActivities(intent, 0)) {
                            val pkg = r.activityInfo.packageName
                            val updated = try { packageManager.getPackageInfo(pkg, 0).lastUpdateTime } catch (e: Exception) { 0L }
                            out.add(mapOf("label" to r.loadLabel(packageManager).toString(), "package" to pkg, "updated" to updated))
                        }
                    } catch (e: Exception) {
                        // Leave the list as far as it got.
                    }
                    runOnUiThread { result.success(out) }
                }.start()
                "icons" -> Thread {
                    // The icon of each named app, and its one-colour outline where the app supplies one.
                    val out = ArrayList<Map<String, Any>>()
                    fun png(draw: (android.graphics.Canvas) -> Unit): ByteArray {
                        val bmp = android.graphics.Bitmap.createBitmap(96, 96, android.graphics.Bitmap.Config.ARGB_8888)
                        draw(android.graphics.Canvas(bmp))
                        val bytes = java.io.ByteArrayOutputStream()
                        bmp.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, bytes)
                        return bytes.toByteArray()
                    }
                    for (name in call.arguments as List<*>) {
                        try {
                            // A name starting with "label:" is looked up by what the app is called on the home screen.
                            var pkg = name as String
                            if (pkg.startsWith("label:")) {
                                val want = pkg.substring(6)
                                val intent = android.content.Intent(android.content.Intent.ACTION_MAIN).addCategory(android.content.Intent.CATEGORY_LAUNCHER)
                                pkg = packageManager.queryIntentActivities(intent, 0).first { it.loadLabel(packageManager).toString().equals(want, ignoreCase = true) }.activityInfo.packageName
                            }
                            val d = packageManager.getApplicationIcon(pkg)
                            val m = HashMap<String, Any>()
                            m["asked"] = name
                            m["package"] = pkg
                            m["icon"] = png { c -> d.setBounds(0, 0, 96, 96); d.draw(c) }
                            if (Build.VERSION.SDK_INT >= 33 && d is android.graphics.drawable.AdaptiveIconDrawable) {
                                val mono = d.monochrome
                                if (mono != null) {
                                    // An icon layer is drawn larger than what shows: only its middle two thirds is the picture.
                                    m["mono"] = png { c -> mono.mutate(); mono.setTint(android.graphics.Color.WHITE); mono.setBounds(-36, -36, 132, 132); mono.draw(c) }
                                }
                            }
                            out.add(m)
                        } catch (e: Exception) {
                            // Not installed.
                        }
                    }
                    runOnUiThread { result.success(out) }
                }.start()
                "launch" -> {
                    // Either just a package name, or a package with the place on screen it was opened from.
                    val a = call.arguments
                    val pkg = if (a is Map<*, *>) a["package"] as String else a as String
                    val i = packageManager.getLaunchIntentForPackage(pkg)
                    if (i != null) {
                        // What a home screen is expected to send: bring the app's existing task forward as it was left.
                        i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                        var opts: Bundle? = null
                        if (a is Map<*, *> && a["w"] != null) {
                            val x = (a["x"] as Number).toInt(); val y = (a["y"] as Number).toInt()
                            val w = (a["w"] as Number).toInt(); val h = (a["h"] as Number).toInt()
                            // The app opens out of the thing that was tapped, and Android is told where that was.
                            i.sourceBounds = android.graphics.Rect(x, y, x + w, y + h)
                            opts = android.app.ActivityOptions.makeClipRevealAnimation(window.decorView, x, y, w, h).toBundle()
                        }
                        startActivity(i, opts)
                    }
                    result.success(i != null)
                }
                else -> result.notImplemented()
            }
        }
        // Which phone this is, for the test report.
        device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/device")
        RestBubble.channel = device
        device!!.setMethodCallHandler { call, result ->
            if (call.method == "rest") {
                // Everything the floating workout needs to know, or nothing if no workout is on.
                val a = call.arguments as? Map<*, *>
                if (a == null) {
                    RestBubble.active = false
                } else {
                    RestBubble.active = true
                    RestBubble.title = a["title"] as String
                    RestBubble.setLabel = a["set"] as String
                    RestBubble.kg = (a["kg"] as Number).toDouble()
                    RestBubble.reps = (a["reps"] as Number).toInt()
                    RestBubble.endsAt = (a["endsAt"] as Number).toLong()
                    RestBubble.total = (a["total"] as Number).toInt()
                    RestBubble.sinceAt = (a["sinceAt"] as Number).toLong()
                    RestBubble.accent = (a["accent"] as Number).toInt()
                    RestBubble.onAccent = (a["onAccent"] as Number).toInt()
                }
                RestBubble.update(applicationContext)
                result.success(null)
            } else if (call.method == "overlayAllowed") {
                result.success(android.provider.Settings.canDrawOverlays(this))
            } else if (call.method == "askOverlay") {
                try {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:$packageName")))
                } catch (e: Exception) {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                }
                result.success(null)
            } else if (call.method == "battery") {
                // One reading of the battery: how full, how fast it is draining, whether it is charging.
                val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                val sticky = registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
                val bright = try { android.provider.Settings.System.getInt(contentResolver, android.provider.Settings.System.SCREEN_BRIGHTNESS) } catch (e: Exception) { 0 }
                result.success(mapOf(
                    "level" to bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY),
                    "current" to bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CURRENT_NOW),
                    "counter" to bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER),
                    "plugged" to ((sticky?.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0),
                    "temp" to (sticky?.getIntExtra(android.os.BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0),
                    "brightness" to bright,
                ))
            } else if (call.method == "power") {
                // Battery level, heat and power saving: they change how fast the phone is willing to draw.
                val bm = getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
                val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                val heat = arrayOf("cool", "light", "moderate", "severe", "critical", "emergency", "shutdown").getOrElse(pm.currentThermalStatus) { "?" }
                result.success("battery ${bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)}%, heat $heat, power saving ${if (pm.isPowerSaveMode) "ON" else "off"}")
            } else if (call.method == "info") {
                result.success("${Build.MANUFACTURER} ${Build.MODEL}, Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), ${Build.SOC_MODEL}")
            } else {
                result.notImplemented()
            }
        }
        // Streams the direction of gravity, so cards can tilt with the phone.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/tilt").setStreamHandler(
            object : EventChannel.StreamHandler {
                private var listener: SensorEventListener? = null
                private val sensors = getSystemService(Context.SENSOR_SERVICE) as SensorManager

                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    val sensor = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        ?: sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                    if (sensor == null) {
                        events.error("no_sensor", "No gravity sensor", null)
                        return
                    }
                    val l = object : SensorEventListener {
                        override fun onSensorChanged(e: SensorEvent) {
                            events.success(doubleArrayOf(
                                e.values[0].toDouble() / SensorManager.GRAVITY_EARTH,
                                e.values[1].toDouble() / SensorManager.GRAVITY_EARTH,
                                e.values[2].toDouble() / SensorManager.GRAVITY_EARTH,
                            ))
                        }
                        override fun onAccuracyChanged(s: Sensor?, accuracy: Int) {}
                    }
                    listener = l
                    sensors.registerListener(l, sensor, SensorManager.SENSOR_DELAY_GAME)
                }

                override fun onCancel(arguments: Any?) {
                    listener?.let { sensors.unregisterListener(it) }
                    listener = null
                }
            }
        )
    }

    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    // tick: a notch or selection. click: something settled. thud: a beat,
    // an end stop or a refusal.
    private fun play(kind: String) {
        if (!vibrator.hasVibrator()) return
        val (primitive, scale, predefined, fallbackMs) = when (kind) {
            "thud" -> Quad(VibrationEffect.Composition.PRIMITIVE_THUD, 1.0f, VibrationEffect.EFFECT_HEAVY_CLICK, 28L)
            "click" -> Quad(VibrationEffect.Composition.PRIMITIVE_CLICK, 0.7f, VibrationEffect.EFFECT_CLICK, 14L)
            else -> Quad(VibrationEffect.Composition.PRIMITIVE_TICK, 1.0f, VibrationEffect.EFFECT_TICK, 8L)
        }
        val effect: VibrationEffect = when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && vibrator.areAllPrimitivesSupported(primitive) ->
                VibrationEffect.startComposition().addPrimitive(primitive, scale).compose()
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> VibrationEffect.createPredefined(predefined)
            else -> VibrationEffect.createOneShot(fallbackMs, 255)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            // Media usage, so the phone's silent mode and touch-feedback
            // setting do not mute the demo. The app has its own Haptics switch.
            vibrator.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
        } else {
            vibrator.vibrate(effect)
        }
    }

    private data class Quad(val primitive: Int, val scale: Float, val predefined: Int, val ms: Long)

    // Ask for the fastest display mode at the current resolution, so the app
    // runs at 120 Hz where the phone would otherwise default it to 60.
    private fun requestHighestRefreshRate() {
        val display = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            display
        } else {
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay
        } ?: return
        val current = display.mode
        val best = display.supportedModes
            .filter { it.physicalWidth == current.physicalWidth && it.physicalHeight == current.physicalHeight }
            .maxByOrNull { it.refreshRate } ?: return
        val params = window.attributes
        params.preferredDisplayModeId = best.modeId
        window.attributes = params
    }
}

/**
 * The workout, floating over other apps.
 *
 * While a workout is on and Prism is not on screen, a small glass lens floats over whatever
 * app is open. During a rest it counts down; otherwise it counts up from the last set. A tap
 * opens a small panel in place: the exercise, weight and reps with steppers, and one button
 * to log the set. Logging it starts the rest and the panel folds back into the lens.
 * Everything here is drawn by Android itself. Nothing runs when no workout is on.
 */
object RestBubble {
    const val OPEN_TRAIN = "dev.lumen.OPEN_TRAIN"
    var channel: MethodChannel? = null
    var active = false
    var title = ""
    var setLabel = ""
    var kg = 0.0
    var reps = 0
    var endsAt = 0L
    var total = 90
    var sinceAt = 0L
    var accent = 0xFFFFAE1A.toInt()
    var onAccent = 0xFF1D1300.toInt()
    private var view: Dot? = null
    private var panel: android.view.View? = null
    private var refreshPanel: (() -> Unit)? = null
    private var dismissed = false

    private fun wm(context: Context) = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager

    fun clock(ms: Long): String {
        val s = (ms / 1000).coerceAtLeast(0)
        return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
    }

    fun number(v: Double): String = if (v % 1.0 == 0.0) v.toInt().toString() else String.format(java.util.Locale.US, "%.1f", v)

    /** Prism sent new facts about the workout. */
    fun update(context: Context) {
        if (!active) {
            hide(context)
            return
        }
        refreshPanel?.invoke()
        view?.invalidate()
    }

    /** Prism has left the screen. */
    fun show(context: Context) {
        if (!active || dismissed || view != null) return
        if (!android.provider.Settings.canDrawOverlays(context)) return
        try {
            val d = context.resources.displayMetrics
            val size = (84 * d.density).toInt()
            val lp = android.view.WindowManager.LayoutParams(
                size, size,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            lp.x = d.widthPixels - size - (8 * d.density).toInt()
            lp.y = (d.heightPixels * 0.30f).toInt()
            val v = Dot(context, lp)
            wm(context).addView(v, lp)
            view = v
        } catch (e: Exception) {
            view = null
        }
    }

    /** Prism is back on screen. */
    fun onForeground(context: Context) {
        dismissed = false
        hide(context)
    }

    fun hide(context: Context) {
        closePanel(context, false)
        val v = view ?: return
        view = null
        try { wm(context).removeView(v) } catch (e: Exception) {}
    }

    private fun openPrism(context: Context) {
        val i = android.content.Intent(context, MainActivity::class.java)
            .setAction(OPEN_TRAIN)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try { context.startActivity(i) } catch (ex: Exception) {}
        hide(context)
    }

    private fun rounded(color: Int, radius: Float, stroke: Int = 0, strokeWidth: Int = 0): android.graphics.drawable.GradientDrawable {
        val g = android.graphics.drawable.GradientDrawable()
        g.setColor(color)
        g.cornerRadius = radius
        if (strokeWidth > 0) g.setStroke(strokeWidth, stroke)
        return g
    }

    private fun label(context: Context, size: Float, color: Int, bold: Boolean): android.widget.TextView {
        val t = android.widget.TextView(context)
        t.textSize = size
        t.setTextColor(color)
        t.typeface = android.graphics.Typeface.create(if (bold) "sans-serif-medium" else "sans-serif", if (bold) android.graphics.Typeface.BOLD else android.graphics.Typeface.NORMAL)
        t.includeFontPadding = false
        return t
    }

    /** The panel: the current set, to adjust and log without leaving the app underneath. */
    private fun openPanel(context: Context, nearY: Int) {
        if (panel != null) return
        try {
            val d = context.resources.displayMetrics
            val dp = d.density
            fun px(v: Float) = (v * dp).toInt()
            val white = 0xFFFFFFFF.toInt()
            val grey = 0xFFA9ACB6.toInt()
            val wrap = android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            val fill = android.widget.LinearLayout.LayoutParams.MATCH_PARENT

            val root = android.widget.LinearLayout(context)
            root.orientation = android.widget.LinearLayout.VERTICAL
            root.setPadding(px(18f), px(16f), px(18f), px(18f))
            // Tinted, see-through glass with a lit edge: the app underneath shows through.
            val glass = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xE01B1E26.toInt(), 0xEA0C0D11.toInt()),
            )
            glass.cornerRadius = 30 * dp
            glass.setStroke(px(1.2f), 0x40FFFFFF)
            root.background = glass

            // Top row: the timer, and the way back into Prism.
            val top = android.widget.LinearLayout(context)
            top.gravity = android.view.Gravity.CENTER_VERTICAL
            val timeBox = android.widget.LinearLayout(context)
            timeBox.orientation = android.widget.LinearLayout.VERTICAL
            val time = label(context, 30f, white, true)
            time.fontFeatureSettings = "tnum"
            val what = label(context, 12f, grey, false)
            timeBox.addView(time)
            timeBox.addView(what)
            top.addView(timeBox, android.widget.LinearLayout.LayoutParams(0, wrap, 1f))
            val open = label(context, 13f, white, true)
            open.text = "Open Prism"
            open.setPadding(px(14f), px(9f), px(14f), px(9f))
            open.background = rounded(0x24FFFFFF, 100 * dp)
            open.setOnClickListener { openPrism(context) }
            top.addView(open)
            root.addView(top, android.widget.LinearLayout.LayoutParams(fill, wrap))

            // What is being lifted.
            val name = label(context, 19f, white, true)
            val which = label(context, 12.5f, accent, true)
            which.letterSpacing = 0.08f
            val nameLp = android.widget.LinearLayout.LayoutParams(fill, wrap)
            nameLp.topMargin = px(14f)
            root.addView(which, nameLp)
            val nameLp2 = android.widget.LinearLayout.LayoutParams(fill, wrap)
            nameLp2.topMargin = px(2f)
            root.addView(name, nameLp2)

            // Weight and reps: a minus, the number, a plus. Big targets, for one thumb.
            val values = android.widget.LinearLayout(context)
            fun stepper(unit: String, read: () -> String, change: (Int) -> Unit): android.view.View {
                val box = android.widget.LinearLayout(context)
                box.gravity = android.view.Gravity.CENTER_VERTICAL
                box.background = rounded(0x1AFFFFFF, 22 * dp)
                val number = label(context, 20f, white, true)
                number.fontFeatureSettings = "tnum"
                number.gravity = android.view.Gravity.CENTER
                fun show() { number.text = read() + " " + unit }
                fun button(sign: String, by: Int): android.widget.TextView {
                    val b = label(context, 24f, white, false)
                    b.text = sign
                    b.gravity = android.view.Gravity.CENTER
                    b.setOnClickListener {
                        change(by)
                        show()
                        it.performHapticFeedback(android.view.HapticFeedbackConstants.KEYBOARD_TAP)
                    }
                    return b
                }
                box.addView(button("−", -1), android.widget.LinearLayout.LayoutParams(px(46f), px(56f)))
                box.addView(number, android.widget.LinearLayout.LayoutParams(0, wrap, 1f))
                box.addView(button("+", 1), android.widget.LinearLayout.LayoutParams(px(46f), px(56f)))
                show()
                box.tag = Runnable { show() }
                return box
            }
            val kgBox = stepper("kg", { number(kg) }) { by -> kg = (kg + by * 2.5).coerceIn(0.0, 400.0) }
            val repsBox = stepper("reps", { reps.toString() }) { by -> reps = (reps + by).coerceIn(0, 60) }
            val left = android.widget.LinearLayout.LayoutParams(0, wrap, 1.15f)
            val right = android.widget.LinearLayout.LayoutParams(0, wrap, 1f)
            right.leftMargin = px(8f)
            values.addView(kgBox, left)
            values.addView(repsBox, right)
            val valuesLp = android.widget.LinearLayout.LayoutParams(fill, wrap)
            valuesLp.topMargin = px(14f)
            root.addView(values, valuesLp)

            // Log it.
            val done = label(context, 16.5f, onAccent, true)
            done.text = "Set done"
            done.gravity = android.view.Gravity.CENTER
            done.background = rounded(accent, 100 * dp)
            done.setOnClickListener {
                it.performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
                channel?.invokeMethod("logSet", mapOf("kg" to kg, "reps" to reps))
                closePanel(context, true)
            }
            val doneLp = android.widget.LinearLayout.LayoutParams(fill, px(54f))
            doneLp.topMargin = px(12f)
            root.addView(done, doneLp)

            fun texts() {
                val now = System.currentTimeMillis()
                if (endsAt > now) {
                    time.text = clock(endsAt - now + 999)
                    what.text = "rest left"
                } else {
                    time.text = clock(now - sinceAt)
                    what.text = "since your last set"
                }
                name.text = title
                which.text = setLabel.uppercase()
                (kgBox.tag as Runnable).run()
                (repsBox.tag as Runnable).run()
            }
            texts()
            refreshPanel = { texts() }
            val tick = object : Runnable {
                override fun run() {
                    if (panel !== root) return
                    texts()
                    root.postDelayed(this, 250)
                }
            }

            val lp = android.view.WindowManager.LayoutParams(
                minOf(d.widthPixels - px(24f), px(350f)), android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.CENTER_HORIZONTAL
            lp.y = (nearY - px(30f)).coerceIn(px(56f), (d.heightPixels * 0.5f).toInt())
            // A touch anywhere outside folds it away again.
            root.setOnTouchListener { _, e ->
                if (e.actionMasked == android.view.MotionEvent.ACTION_OUTSIDE) {
                    closePanel(context, true)
                    true
                } else {
                    false
                }
            }
            wm(context).addView(root, lp)
            panel = root
            view?.visibility = android.view.View.INVISIBLE
            root.alpha = 0f; root.scaleX = 0.86f; root.scaleY = 0.86f
            root.animate().alpha(1f).scaleX(1f).scaleY(1f).setDuration(240).setInterpolator(android.view.animation.OvershootInterpolator(1.6f)).start()
            root.postDelayed(tick, 250)
        } catch (e: Exception) {
            panel = null
            refreshPanel = null
        }
    }

    private fun closePanel(context: Context, backToLens: Boolean) {
        val p = panel ?: return
        panel = null
        refreshPanel = null
        try { wm(context).removeView(p) } catch (e: Exception) {}
        if (backToLens) {
            val v = view
            if (v != null) {
                v.visibility = android.view.View.VISIBLE
                v.scaleX = 0.6f; v.scaleY = 0.6f
                v.animate().scaleX(1f).scaleY(1f).setDuration(300).setInterpolator(android.view.animation.OvershootInterpolator(2.4f)).start()
                v.invalidate()
            }
        }
    }

    /**
     * Drawn as a small glass lens: a see-through tinted disc (the app underneath shows through
     * it), a rim lit from above, a soft highlight across the top, and the rest as a ring in
     * the chosen colour with a bright bead at its head.
     */
    private class Dot(context: Context, val lp: android.view.WindowManager.LayoutParams) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val arc = android.graphics.RectF()
        private val clip = android.graphics.Path()
        private var body: android.graphics.Shader? = null
        private var bodyDone: android.graphics.Shader? = null
        private var rim: android.graphics.Shader? = null
        private var shine: android.graphics.Shader? = null
        private var glow: android.graphics.Shader? = null
        private var shadow: android.graphics.Shader? = null
        private var shadersFor = 0
        private var downX = 0f; private var downY = 0f; private var startX = 0; private var startY = 0
        private var dragged = false
        private var buzzedFor = 0L
        private val dp = resources.displayMetrics.density
        private var tracker: android.view.VelocityTracker? = null
        // The springs that carry it to rest after a throw.
        private var px = 0f; private var py = 0f; private var vx = 0f; private var vy = 0f
        private var tx = 0f; private var ty = 0f
        private var springing = false
        private var lastFrame = 0L
        private var leaving = false

        private fun shade(color: Int, value: Float, alpha: Int): Int {
            val hsv = FloatArray(3)
            android.graphics.Color.colorToHSV(color, hsv)
            hsv[2] = (hsv[2] * value).coerceIn(0f, 1f)
            return android.graphics.Color.HSVToColor(alpha, hsv)
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            // It arrives with a small bounce, like the button it comes from.
            scaleX = 0.5f; scaleY = 0.5f; alpha = 0f
            animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(320).setInterpolator(android.view.animation.OvershootInterpolator(2.2f)).start()
        }

        private fun shaders() {
            val w = width
            val r = w / 2f
            val disc = r - 5 * dp
            // The glass: nearly clear where the light enters at the top left, deeper toward the lower
            // right, with a breath of the chosen colour in it. Clearer than before, so more shows through.
            body = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                intArrayOf(shade(accent, 0.36f, 0x78), shade(accent, 0.18f, 0xB4), 0xD60A0B0E.toInt()),
                floatArrayOf(0f, 0.55f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            bodyDone = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                intArrayOf(shade(accent, 1.18f, 0xFF), accent, shade(accent, 0.72f, 0xFF)),
                floatArrayOf(0f, 0.5f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            rim = android.graphics.LinearGradient(0f, r - disc, 0f, r + disc, 0xB8FFFFFF.toInt(), 0x14FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            shine = android.graphics.LinearGradient(0f, r - disc, 0f, r - disc * 0.1f, 0x34FFFFFF, 0x00FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            // Light gathered at the bottom edge, in the chosen colour, as a thick lens does.
            glow = android.graphics.RadialGradient(
                r, r + disc * 0.95f, disc * 0.9f,
                intArrayOf(shade(accent, 1.2f, 0x50), shade(accent, 1.0f, 0x00)), floatArrayOf(0f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            shadow = android.graphics.RadialGradient(r, r + 2 * dp, r, intArrayOf(0x55000000, 0x55000000, 0x00000000), floatArrayOf(0f, 0.78f, 1f), android.graphics.Shader.TileMode.CLAMP)
            clip.reset()
            clip.addCircle(r, r, disc, android.graphics.Path.Direction.CW)
            shadersFor = accent
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) = shaders()

        override fun onDraw(canvas: android.graphics.Canvas) {
            if (shadersFor != accent) shaders()
            val w = width.toFloat(); val r = w / 2f
            val disc = r - 5 * dp
            val now = System.currentTimeMillis()
            val left = endsAt - now
            val resting = left > 0
            // For three seconds after a rest ends, it says GO.
            val go = endsAt > 0 && !resting && now - endsAt < 3000
            paint.style = android.graphics.Paint.Style.FILL
            paint.shader = shadow
            canvas.drawCircle(r, r + 2 * dp, r, paint)
            paint.shader = if (go) bodyDone else body
            canvas.drawCircle(r, r, disc, paint)
            canvas.save()
            canvas.clipPath(clip)
            if (!go) {
                paint.shader = glow
                canvas.drawCircle(r, r + disc * 0.95f, disc * 0.9f, paint)
            }
            paint.shader = shine
            canvas.drawOval(r - disc * 1.25f, r - disc * 1.05f, r + disc * 1.25f, r - disc * 0.05f, paint)
            canvas.restore()
            paint.shader = null
            val inset = 5 * dp + 6.5f * dp
            arc.set(inset, inset, w - inset, w - inset)
            if (resting) {
                // The ring: what is left of the rest, with a bright bead where it ends.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 3.6f * dp
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = 0x24FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                val part = (left / (total * 1000f)).coerceIn(0f, 1f)
                paint.color = accent
                canvas.drawArc(arc, -90f, 360f * part, false, paint)
                val a = Math.toRadians((-90f + 360f * part).toDouble())
                val bx = r + (arc.width() / 2f) * Math.cos(a).toFloat(); val by = r + (arc.height() / 2f) * Math.sin(a).toFloat()
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = shade(accent, 1.3f, 0x55)
                canvas.drawCircle(bx, by, 5.2f * dp, paint)
                paint.color = 0xFFFFFFFF.toInt()
                canvas.drawCircle(bx, by, 2.1f * dp, paint)
            } else if (!go) {
                // Counting up: a quiet ring with one bead going round once a minute, like a second hand.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 2.2f * dp
                paint.color = 0x22FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                val a = Math.toRadians((-90.0 + 360.0 * (((now - sinceAt) % 60000L) / 60000.0)))
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = accent
                canvas.drawCircle(r + (arc.width() / 2f) * Math.cos(a).toFloat(), r + (arc.height() / 2f) * Math.sin(a).toFloat(), 2.6f * dp, paint)
            }
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 1.3f * dp
            paint.shader = rim
            canvas.drawCircle(r, r, disc - 0.65f * dp, paint)
            paint.shader = null
            paint.style = android.graphics.Paint.Style.FILL
            val secs = ((left + 999) / 1000).coerceAtLeast(0)
            paint.color = if (go) onAccent else if (resting && secs <= 10) shade(accent, 1.25f, 0xFF) else 0xFFFFFFFF.toInt()
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.letterSpacing = if (go) 0.06f else -0.01f
            paint.textSize = (if (go) 19f else 17.5f) * dp
            val text = if (go) "GO" else if (resting) clock(left + 999) else clock(now - sinceAt)
            canvas.drawText(text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            if (go && buzzedFor != endsAt) {
                buzzedFor = endsAt
                performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
                animate().scaleX(1.14f).scaleY(1.14f).setDuration(160).withEndAction {
                    animate().scaleX(1f).scaleY(1f).setDuration(420).setInterpolator(android.view.animation.OvershootInterpolator(3f)).start()
                }.start()
            }
            // Smooth while a rest runs down; otherwise once a second is enough.
            postInvalidateDelayed(if (resting) 66 else if (go) 250 else 1000)
        }

        private fun place() {
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
        }

        // A spring with some give: it overshoots the edge a little and settles, as a thrown thing does.
        private val frame = object : android.view.Choreographer.FrameCallback {
            override fun doFrame(nanos: Long) {
                if (!springing || !isAttachedToWindow) { springing = false; return }
                val dt = if (lastFrame == 0L) 1f / 120f else ((nanos - lastFrame) / 1e9f).coerceIn(0.001f, 0.032f)
                lastFrame = nanos
                val k = 210f; val c = 19f
                vx += (-k * (px - tx) - c * vx) * dt; px += vx * dt
                vy += (-k * (py - ty) - c * vy) * dt; py += vy * dt
                lp.x = px.toInt(); lp.y = py.toInt()
                place()
                val still = Math.abs(px - tx) < 0.6f && Math.abs(py - ty) < 0.6f && Math.abs(vx) < 12f && Math.abs(vy) < 12f
                if (still) {
                    springing = false
                    if (leaving) {
                        dismissed = true
                        hide(context)
                    }
                } else {
                    android.view.Choreographer.getInstance().postFrameCallback(this)
                }
            }
        }

        private fun throwIt(velX: Float, velY: Float) {
            val screen = resources.displayMetrics
            val margin = 8 * dp
            px = lp.x.toFloat(); py = lp.y.toFloat(); vx = velX; vy = velY
            // Where it would coast to decides which side it goes to, so a flick sends it across.
            val coastX = px + velX * 0.16f
            val coastY = py + velY * 0.18f
            tx = if (coastX + width / 2f < screen.widthPixels / 2f) margin else screen.widthPixels - width - margin
            leaving = coastY > screen.heightPixels * 0.86f
            ty = if (leaving) screen.heightPixels + height.toFloat() else coastY.coerceIn(48 * dp, screen.heightPixels - height - 48 * dp)
            lastFrame = 0L
            if (!springing) {
                springing = true
                android.view.Choreographer.getInstance().postFrameCallback(frame)
            }
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    springing = false
                    tracker?.recycle()
                    tracker = android.view.VelocityTracker.obtain()
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; dragged = false
                    animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    val slop = 10 * dp
                    if (dragged || dx * dx + dy * dy > slop * slop) {
                        dragged = true
                        lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt()
                        place()
                    }
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    animate().scaleX(1f).scaleY(1f).setDuration(220).setInterpolator(android.view.animation.OvershootInterpolator(2.5f)).start()
                    if (e.actionMasked == android.view.MotionEvent.ACTION_UP && !dragged) {
                        // Tapped: the set opens right here, over the app underneath.
                        openPanel(context, lp.y)
                    } else {
                        var velX = 0f; var velY = 0f
                        val t = tracker
                        if (t != null) {
                            t.computeCurrentVelocity(1000)
                            velX = t.xVelocity; velY = t.yVelocity
                        }
                        throwIt(velX, velY)
                    }
                    tracker?.recycle()
                    tracker = null
                }
            }
            // Positions on the screen, not in the lens, which moves under the finger.
            val copy = android.view.MotionEvent.obtain(e)
            copy.setLocation(e.rawX, e.rawY)
            tracker?.addMovement(copy)
            copy.recycle()
            return true
        }
    }
}
