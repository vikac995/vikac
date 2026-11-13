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
        RestBubble.foreground = false
        RestBubble.refresh(applicationContext)
    }

    override fun onStart() {
        super.onStart()
        RestBubble.foreground = true
        RestBubble.refresh(applicationContext)
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
                    RestBubble.exercise = a["exercise"] as String
                    RestBubble.setLabel = a["set"] as String
                    RestBubble.current = (a["current"] as Number).toInt()
                    RestBubble.sets = (a["sets"] as List<*>).map {
                        val m = it as Map<*, *>
                        RestBubble.SetRow((m["kg"] as Number).toDouble(), (m["reps"] as Number).toInt(), m["done"] as Boolean)
                    }
                    RestBubble.endsAt = (a["endsAt"] as Number).toLong()
                    RestBubble.total = (a["total"] as Number).toInt()
                    RestBubble.sinceAt = (a["sinceAt"] as Number).toLong()
                    RestBubble.countUp = a["countUp"] as Boolean
                    RestBubble.accent = (a["accent"] as Number).toInt()
                    RestBubble.onAccent = (a["onAccent"] as Number).toInt()
                }
                RestBubble.refresh(applicationContext)
                result.success(null)
            } else if (call.method == "page") {
                // Whether Prism's own workout page is the one showing.
                RestBubble.page(applicationContext, call.arguments as Boolean)
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
 * The workout, floating over the whole phone.
 *
 * While a workout is on, a small glass lens floats over whatever is on screen: other apps,
 * the app switcher, and Prism itself. (Only on Prism's own workout page is it absent,
 * because that page is the thing the lens stands for.) It has three sizes on one axis:
 *
 *   lens    a glance: the timer. Drag it anywhere; drop it on the cross at the bottom to close it.
 *   compact a bottom sheet in the thumb's reach: the current set on two dials, and "Set done".
 *   full    the same sheet grown tall: a large timer, every set of the exercise, rest controls.
 *
 * Tap the lens for the sheet. Swipe the sheet up to grow it, down to shrink it, down again
 * to fold it back into the lens. Everything is drawn by Android itself, and nothing exists
 * when no workout is on.
 */
object RestBubble {
    const val OPEN_TRAIN = "dev.lumen.OPEN_TRAIN"

    class SetRow(var kg: Double, var reps: Int, var done: Boolean)

    var channel: MethodChannel? = null
    var active = false
    var title = ""
    var exercise = ""
    var setLabel = ""
    var sets: List<SetRow> = emptyList()
    var current = 0
    var endsAt = 0L
    var total = 90
    var sinceAt = 0L
    var countUp = false
    var accent = 0xFFFFAE1A.toInt()
    var onAccent = 0xFF1D1300.toInt()
    var foreground = true
    var onTrain = false

    private var view: Dot? = null
    private var target: Target? = null
    private var sheet: SheetHost? = null
    private var dismissed = false
    private var fullMode = false
    private var lensX = -1
    private var lensY = -1

    private const val WHITE = 0xFFFFFFFF.toInt()
    private const val GREY = 0xFFA9ACB6.toInt()
    private const val GREEN = 0xFF2FA84F.toInt()

    private fun wm(context: Context) = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager

    fun clock(ms: Long): String {
        val s = (ms / 1000).coerceAtLeast(0)
        return "${s / 60}:${(s % 60).toString().padStart(2, '0')}"
    }

    fun number(v: Double): String = if (v % 1.0 == 0.0) v.toInt().toString() else String.format(java.util.Locale.US, "%.1f", v)

    private fun tint(color: Int, alpha: Int): Int = (color and 0x00FFFFFF) or (alpha shl 24)

    private fun shade(color: Int, value: Float, alpha: Int): Int {
        val hsv = FloatArray(3)
        android.graphics.Color.colorToHSV(color, hsv)
        hsv[2] = (hsv[2] * value).coerceIn(0f, 1f)
        return android.graphics.Color.HSVToColor(alpha, hsv)
    }

    /** The same three clicks Prism's own dials make. */
    fun haptic(context: Context, kind: String) {
        try {
            val vib: Vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (!vib.hasVibrator()) return
            val primitive = when (kind) {
                "thud" -> VibrationEffect.Composition.PRIMITIVE_THUD
                "click" -> VibrationEffect.Composition.PRIMITIVE_CLICK
                else -> VibrationEffect.Composition.PRIMITIVE_TICK
            }
            val effect: VibrationEffect = when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && vib.areAllPrimitivesSupported(primitive) ->
                    VibrationEffect.startComposition().addPrimitive(primitive, if (kind == "click") 0.7f else 1f).compose()
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q -> VibrationEffect.createPredefined(
                    when (kind) {
                        "thud" -> VibrationEffect.EFFECT_HEAVY_CLICK
                        "click" -> VibrationEffect.EFFECT_CLICK
                        else -> VibrationEffect.EFFECT_TICK
                    },
                )
                else -> VibrationEffect.createOneShot(if (kind == "thud") 28L else 10L, 255)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                vib.vibrate(effect, VibrationAttributes.createForUsage(VibrationAttributes.USAGE_MEDIA))
            } else {
                vib.vibrate(effect)
            }
        } catch (e: Throwable) {
            // No vibration is not worth failing over.
        }
    }

    /** Something changed: decide whether the lens should be there, and bring what is shown up to date. */
    fun refresh(context: Context) {
        val want = active && !dismissed && !(foreground && onTrain) && android.provider.Settings.canDrawOverlays(context)
        if (!want) {
            remove(context)
            return
        }
        if (view == null) add(context)
        sheet?.sync()
        view?.invalidate()
    }

    /** Prism's workout page came on screen or left it. Going to it also brings a closed lens back. */
    fun page(context: Context, train: Boolean) {
        onTrain = train
        if (train) dismissed = false
        refresh(context)
    }

    private fun add(context: Context) {
        try {
            val d = context.resources.displayMetrics
            val dp = d.density
            // The cross to drop it on. Added first, so it lies under the lens; it cannot be touched.
            val t = Target(context)
            val tlp = android.view.WindowManager.LayoutParams(
                (150 * dp).toInt(), (150 * dp).toInt(),
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            tlp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            tlp.x = d.widthPixels / 2 - (75 * dp).toInt()
            tlp.y = d.heightPixels - (104 * dp).toInt() - (75 * dp).toInt()
            t.alpha = 0f
            wm(context).addView(t, tlp)
            target = t

            val size = (84 * dp).toInt()
            val lp = android.view.WindowManager.LayoutParams(
                size, size,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            // Where it was last left, so it is in the same spot everywhere.
            lp.x = if (lensX >= 0) lensX else d.widthPixels - size - (8 * dp).toInt()
            lp.y = if (lensY >= 0) lensY else (d.heightPixels * 0.30f).toInt()
            val v = Dot(context, lp)
            wm(context).addView(v, lp)
            view = v
        } catch (e: Exception) {
            view = null
        }
    }

    private fun remove(context: Context) {
        removeSheet(context)
        val t = target
        target = null
        if (t != null) try { wm(context).removeView(t) } catch (e: Exception) {}
        val v = view ?: return
        view = null
        try { wm(context).removeView(v) } catch (e: Exception) {}
    }

    private fun openPrism(context: Context) {
        closeSheet(context)
        val i = android.content.Intent(context, MainActivity::class.java)
            .setAction(OPEN_TRAIN)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try { context.startActivity(i) } catch (ex: Exception) {}
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

    private fun openSheet(context: Context) {
        if (sheet != null) return
        try {
            val d = context.resources.displayMetrics
            val dp = d.density
            val host = SheetHost(context)
            val lp = android.view.WindowManager.LayoutParams(
                minOf(d.widthPixels - (16 * dp).toInt(), (440 * dp).toInt()), android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            // Always at the bottom, wherever the lens is: that is where a thumb reaches.
            lp.gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
            lp.y = (14 * dp).toInt()
            wm(context).addView(host, lp)
            sheet = host
            view?.visibility = android.view.View.INVISIBLE
            host.arrive()
        } catch (e: Exception) {
            sheet = null
        }
    }

    /** Folds the sheet back into the lens, with a little movement. */
    private fun closeSheet(context: Context) {
        val s = sheet ?: return
        s.leave { removeSheet(context) }
    }

    private fun removeSheet(context: Context) {
        val s = sheet ?: return
        sheet = null
        try { wm(context).removeView(s) } catch (e: Exception) {}
        val v = view
        if (v != null) {
            v.visibility = android.view.View.VISIBLE
            v.scaleX = 0.6f; v.scaleY = 0.6f
            v.animate().scaleX(1f).scaleY(1f).setDuration(300).setInterpolator(android.view.animation.OvershootInterpolator(2.4f)).start()
            v.invalidate()
        }
    }

    /** What the timer shows, the same for the lens and for the sheet. */
    private class Reading(val text: String, val part: Float, val resting: Boolean, val go: Boolean, val urgent: Boolean, val what: String)

    private fun reading(now: Long): Reading {
        val left = endsAt - now
        val resting = left > 0
        val go = endsAt > 0 && !resting && now - endsAt < 3000
        val since = now - sinceAt
        if (go) return Reading("GO", 1f, false, true, false, "REST IS OVER")
        if (resting) {
            val gone = (total * 1000L - left).coerceAtLeast(0)
            return if (countUp) {
                Reading(clock(gone), (gone / (total * 1000f)).coerceIn(0f, 1f), true, false, left <= 10000, "RESTING")
            } else {
                Reading(clock(left + 999), (left / (total * 1000f)).coerceIn(0f, 1f), true, false, left <= 10000, "REST LEFT")
            }
        }
        return Reading(clock(since), -1f, false, false, false, "SINCE LAST SET")
    }

    /** The cross at the bottom of the screen that the lens is dropped on to close it. */
    private class Target(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val dp = resources.displayMetrics.density
        var held = false
            set(v) {
                if (field != v) {
                    field = v
                    animate().scaleX(if (v) 1.28f else 1f).scaleY(if (v) 1.28f else 1f).setDuration(160)
                        .setInterpolator(android.view.animation.OvershootInterpolator(2.5f)).start()
                    invalidate()
                }
            }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val c = width / 2f
            val r = 40 * dp
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = if (held) 0xE6181A20.toInt() else 0xCC101216.toInt()
            canvas.drawCircle(c, c, r, paint)
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = (if (held) 2.2f else 1.4f) * dp
            paint.color = if (held) accent else 0x66FFFFFF
            canvas.drawCircle(c, c, r - paint.strokeWidth / 2, paint)
            paint.strokeWidth = 2.6f * dp
            paint.strokeCap = android.graphics.Paint.Cap.ROUND
            paint.color = WHITE
            val a = 9 * dp
            canvas.drawLine(c - a, c - a, c + a, c + a, paint)
            canvas.drawLine(c - a, c + a, c + a, c - a, paint)
        }
    }

    /**
     * The lens: a see-through tinted disc (what is underneath shows through it), a rim lit from
     * above, a soft highlight across the top, and the timer.
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
        private var snapped = false
        private var buzzedFor = 0L
        private val dp = resources.displayMetrics.density
        private var tracker: android.view.VelocityTracker? = null
        // The springs that carry it to rest after a throw.
        private var px = 0f; private var py = 0f; private var vx = 0f; private var vy = 0f
        private var tx = 0f; private var ty = 0f
        private var springing = false
        private var lastFrame = 0L
        private var leaving = false

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            scaleX = 0.5f; scaleY = 0.5f; alpha = 0f
            animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(320).setInterpolator(android.view.animation.OvershootInterpolator(2.2f)).start()
        }

        private fun shaders() {
            val r = width / 2f
            val disc = r - 5 * dp
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
            val t = reading(now)
            paint.style = android.graphics.Paint.Style.FILL
            paint.shader = shadow
            canvas.drawCircle(r, r + 2 * dp, r, paint)
            paint.shader = if (t.go) bodyDone else body
            canvas.drawCircle(r, r, disc, paint)
            canvas.save()
            canvas.clipPath(clip)
            if (!t.go) {
                paint.shader = glow
                canvas.drawCircle(r, r + disc * 0.95f, disc * 0.9f, paint)
            }
            paint.shader = shine
            canvas.drawOval(r - disc * 1.25f, r - disc * 1.05f, r + disc * 1.25f, r - disc * 0.05f, paint)
            canvas.restore()
            paint.shader = null
            val inset = 5 * dp + 6.5f * dp
            arc.set(inset, inset, w - inset, w - inset)
            if (t.resting) {
                // The ring: the rest running down, or filling up, with a bright bead at its head.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 3.6f * dp
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = 0x24FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                paint.color = accent
                canvas.drawArc(arc, -90f, 360f * t.part, false, paint)
                val a = Math.toRadians((-90f + 360f * t.part).toDouble())
                val bx = r + (arc.width() / 2f) * Math.cos(a).toFloat(); val by = r + (arc.height() / 2f) * Math.sin(a).toFloat()
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = shade(accent, 1.3f, 0x55)
                canvas.drawCircle(bx, by, 5.2f * dp, paint)
                paint.color = WHITE
                canvas.drawCircle(bx, by, 2.1f * dp, paint)
            } else if (!t.go) {
                // No rest running: a quiet ring with one bead going round once a minute, like a second hand.
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
            paint.color = if (t.go) onAccent else if (t.urgent) shade(accent, 1.25f, 0xFF) else WHITE
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.letterSpacing = if (t.go) 0.06f else -0.01f
            paint.textSize = (if (t.go) 19f else 17.5f) * dp
            canvas.drawText(t.text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            if (t.go && buzzedFor != endsAt) {
                buzzedFor = endsAt
                haptic(context, "thud")
                animate().scaleX(1.14f).scaleY(1.14f).setDuration(160).withEndAction {
                    animate().scaleX(1f).scaleY(1f).setDuration(420).setInterpolator(android.view.animation.OvershootInterpolator(3f)).start()
                }.start()
            }
            // Smooth while a rest is running; otherwise once a second is enough.
            postInvalidateDelayed(if (t.resting) 66 else if (t.go) 250 else 1000)
        }

        private fun place() {
            lensX = lp.x; lensY = lp.y
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
        }

        /** The middle of the cross, on the screen. */
        private fun crossX() = resources.displayMetrics.widthPixels / 2f
        private fun crossY() = resources.displayMetrics.heightPixels - 104 * dp

        // A spring with some give: it overshoots a little and settles, as a thrown thing does.
        private val frame = object : android.view.Choreographer.FrameCallback {
            override fun doFrame(nanos: Long) {
                if (!springing || !isAttachedToWindow) { springing = false; return }
                val dt = if (lastFrame == 0L) 1f / 120f else ((nanos - lastFrame) / 1e9f).coerceIn(0.001f, 0.032f)
                lastFrame = nanos
                val k = if (leaving) 320f else 210f; val c = if (leaving) 30f else 19f
                vx += (-k * (px - tx) - c * vx) * dt; px += vx * dt
                vy += (-k * (py - ty) - c * vy) * dt; py += vy * dt
                lp.x = px.toInt(); lp.y = py.toInt()
                place()
                val near = if (leaving) 6f else 0.6f
                val still = Math.abs(px - tx) < near && Math.abs(py - ty) < near && (leaving || (Math.abs(vx) < 12f && Math.abs(vy) < 12f))
                if (still) {
                    springing = false
                    if (leaving) close()
                } else {
                    android.view.Choreographer.getInstance().postFrameCallback(this)
                }
            }
        }

        /** Dropped on the cross: it shrinks into it and is gone until the workout page is opened again. */
        private fun close() {
            haptic(context, "click")
            val c = context
            target?.animate()?.alpha(0f)?.setDuration(220)?.start()
            animate().scaleX(0.2f).scaleY(0.2f).alpha(0f).setDuration(170).withEndAction {
                dismissed = true
                // It comes back at its usual place, not on the cross.
                lensX = -1; lensY = -1
                refresh(c)
            }.start()
        }

        private fun throwIt(velX: Float, velY: Float) {
            val screen = resources.displayMetrics
            val margin = 8 * dp
            px = lp.x.toFloat(); py = lp.y.toFloat(); vx = velX; vy = velY
            // Where it would coast to decides where it ends up, so a flick carries it.
            val coastX = px + velX * 0.16f
            val coastY = py + velY * 0.18f
            // A flick down toward the middle is a throw at the cross.
            val atCross = velY > 700 && coastY + height / 2f > screen.heightPixels * 0.70f && Math.abs(coastX + width / 2f - crossX()) < 120 * dp
            leaving = snapped || atCross
            if (leaving) {
                tx = crossX() - width / 2f; ty = crossY() - height / 2f
            } else {
                tx = if (coastX + width / 2f < screen.widthPixels / 2f) margin else screen.widthPixels - width - margin
                ty = coastY.coerceIn(48 * dp, screen.heightPixels - height - 48 * dp)
                target?.held = false
                target?.animate()?.alpha(0f)?.setDuration(200)?.start()
            }
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
                    leaving = false
                    tracker?.recycle()
                    tracker = android.view.VelocityTracker.obtain()
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; dragged = false; snapped = false
                    animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    val slop = 10 * dp
                    if (!dragged && dx * dx + dy * dy > slop * slop) {
                        dragged = true
                        // The cross appears as soon as the lens is picked up.
                        target?.animate()?.alpha(1f)?.setDuration(160)?.start()
                    }
                    if (dragged) {
                        var x = startX + dx; var y = startY + dy
                        // Near the cross the lens is pulled onto it, and lets go again if dragged clear.
                        val cx = x + width / 2f; val cy = y + height / 2f
                        val dist = Math.hypot((cx - crossX()).toDouble(), (cy - crossY()).toDouble()).toFloat()
                        val was = snapped
                        snapped = dist < (if (snapped) 118 else 92) * dp
                        if (snapped) {
                            x = crossX() - width / 2f + (cx - crossX()) * 0.18f
                            y = crossY() - height / 2f + (cy - crossY()) * 0.18f
                        }
                        if (snapped != was) {
                            haptic(context, if (snapped) "click" else "tick")
                            target?.held = snapped
                        }
                        lp.x = x.toInt(); lp.y = y.toInt()
                        place()
                    }
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    animate().scaleX(1f).scaleY(1f).setDuration(220).setInterpolator(android.view.animation.OvershootInterpolator(2.5f)).start()
                    if (e.actionMasked == android.view.MotionEvent.ACTION_UP && !dragged) {
                        // Tapped: the set opens, at the bottom of the screen.
                        haptic(context, "tick")
                        openSheet(context)
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

    /** The timer in the sheet: a ring with the time in it. */
    private class Clock(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val arc = android.graphics.RectF()
        private val dp = resources.displayMetrics.density

        override fun onDraw(canvas: android.graphics.Canvas) {
            val w = width.toFloat(); val r = w / 2f
            val now = System.currentTimeMillis()
            val t = reading(now)
            val stroke = Math.max(3.5f * dp, w * 0.055f)
            arc.set(stroke, stroke, w - stroke, w - stroke)
            paint.shader = null
            if (t.go) {
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = accent
                canvas.drawCircle(r, r, r - stroke / 2, paint)
            } else {
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = stroke
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = 0x22FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                paint.color = accent
                if (t.resting) {
                    canvas.drawArc(arc, -90f, 360f * t.part, false, paint)
                } else {
                    val a = Math.toRadians((-90.0 + 360.0 * (((now - sinceAt) % 60000L) / 60000.0)))
                    paint.style = android.graphics.Paint.Style.FILL
                    canvas.drawCircle(r + (arc.width() / 2f) * Math.cos(a).toFloat(), r + (arc.height() / 2f) * Math.sin(a).toFloat(), stroke * 0.8f, paint)
                }
            }
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = if (t.go) onAccent else if (t.urgent) shade(accent, 1.25f, 0xFF) else WHITE
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.textSize = w * 0.27f
            canvas.drawText(t.text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            postInvalidateDelayed(if (t.resting) 50 else 500)
        }
    }

    /**
     * A thumb dial, the same as the ones on Prism's workout page: drag sideways and the number
     * turns under the thumb with a click for every step; slow down and it changes to fine
     * steps with a different click; a tap on either half nudges it one step.
     */
    private class Dial(context: Context, val unit: String, val step: Double, val fine: Double, val min: Double, val max: Double) : android.view.View(context) {
        var value = 0.0
            set(v) {
                if (field != v) {
                    field = v
                    invalidate()
                }
            }
        var onChange: ((Double) -> Unit)? = null
        var dragging = false
        private val dp = resources.displayMetrics.density
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val box = android.graphics.RectF()
        private var downX = 0f; private var lastX = 0f; private var lastT = 0L
        private var raw = 0.0; private var wheel = 0f; private var speed = 0f
        private var fineNow = false; private var slowSince = 0L
        private var moved = false

        private fun snap(v: Double, s: Double) = (Math.round(v / s) * s).coerceIn(min, max)

        private fun emit(v: Double) {
            if (v != value) {
                value = v
                haptic(context, "tick")
                onChange?.invoke(v)
            }
        }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val w = width.toFloat(); val h = height.toFloat()
            box.set(1 * dp, 1 * dp, w - 1 * dp, h - 1 * dp)
            paint.shader = null
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = if (dragging) tint(accent, 0x2E) else 0x14FFFFFF
            canvas.drawRoundRect(box, h / 2, h / 2, paint)
            if (dragging) {
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 1.5f * dp
                paint.color = accent
                canvas.drawRoundRect(box, h / 2, h / 2, paint)
            }
            // The edge of a wheel seen side-on: ticks bunch up and fade toward the sides, and turn with the thumb.
            val cx = w / 2
            val radius = w / 2 - 12 * dp
            val gap = 0.21
            val turn = ((wheel / radius) % gap + gap) % gap
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeCap = android.graphics.Paint.Cap.ROUND
            paint.strokeWidth = (if (fineNow) 1.1f else 1.6f) * dp
            val base = if (dragging) accent else GREY
            var k = -8
            while (k <= 8) {
                val a = k * gap + turn
                if (Math.abs(a) < 1.45) {
                    val x = cx + radius * Math.sin(a).toFloat()
                    paint.color = tint(base, (150 * Math.cos(a)).toInt().coerceIn(0, 255))
                    canvas.drawLine(x, h - 7 * dp - 5 * dp, x, h - 7 * dp, paint)
                }
                k++
            }
            // The number, with its unit small beside it.
            val num = number(value)
            paint.style = android.graphics.Paint.Style.FILL
            paint.textAlign = android.graphics.Paint.Align.LEFT
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.textSize = 20 * dp
            val wn = paint.measureText(num)
            val baseline = h / 2 - 5 * dp - (paint.descent() + paint.ascent()) / 2f
            paint.textSize = 12 * dp
            val wu = paint.measureText(unit)
            val x0 = cx - (wn + 4 * dp + wu) / 2
            paint.textSize = 20 * dp
            paint.color = WHITE
            canvas.drawText(num, x0, baseline, paint)
            paint.textSize = 12 * dp
            paint.typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
            paint.color = GREY
            canvas.drawText(unit, x0 + wn + 4 * dp, baseline, paint)
        }

        private fun end() {
            dragging = false
            fineNow = false
            moved = false
            invalidate()
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            if (!isEnabled) return false
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    downX = e.x; lastX = e.x; lastT = e.eventTime
                    raw = value
                    speed = 240f * dp // starts in whole steps; slowing down is what selects fine ones
                    fineNow = false; slowSince = 0L; moved = false
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    if (!moved) {
                        if (Math.abs(e.x - downX) > 8 * dp) {
                            moved = true
                            dragging = true
                            parent?.requestDisallowInterceptTouchEvent(true)
                            lastX = e.x; lastT = e.eventTime
                            invalidate()
                        }
                    } else {
                        val dx = e.x - lastX
                        val dt = (e.eventTime - lastT) / 1000f
                        if (dt > 0) speed += (Math.abs(dx) / dt - speed) * 0.3f
                        if (speed < 45 * dp) {
                            if (slowSince == 0L) slowSince = e.eventTime
                            if (!fineNow && fine < step && e.eventTime - slowSince >= 120) {
                                fineNow = true
                                raw = value // fine steps start from the number on screen
                                haptic(context, "click") // a different click: "fine steps now"
                            }
                        } else {
                            slowSince = 0L
                            if (fineNow && speed > 160 * dp) fineNow = false
                        }
                        val s = if (fineNow) fine else step
                        raw = (raw + dx / (16 * dp) * s).coerceIn(min, max)
                        wheel += dx
                        lastX = e.x; lastT = e.eventTime
                        emit(snap(raw, s))
                        invalidate()
                    }
                }
                android.view.MotionEvent.ACTION_UP -> {
                    if (!moved) emit(snap(value + (if (e.x < width / 2f) -step else step), fine))
                    end()
                }
                android.view.MotionEvent.ACTION_CANCEL -> end()
            }
            return true
        }
    }

    /** The round tick at the end of a set's row. */
    private class Tick(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val check = android.graphics.Path()
        private val dp = resources.displayMetrics.density
        var done = false
            set(v) {
                if (field != v) {
                    field = v
                    invalidate()
                }
            }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val c = width / 2f; val cy = height / 2f
            val r = 21 * dp
            paint.style = if (done) android.graphics.Paint.Style.FILL else android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 2 * dp
            paint.color = if (done) GREEN else 0x66FFFFFF
            canvas.drawCircle(c, cy, r - 1 * dp, paint)
            check.reset()
            check.moveTo(c - 8 * dp, cy + 0.5f * dp)
            check.lineTo(c - 2.5f * dp, cy + 6 * dp)
            check.lineTo(c + 8.5f * dp, cy - 5.5f * dp)
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 2.6f * dp
            paint.strokeCap = android.graphics.Paint.Cap.ROUND
            paint.strokeJoin = android.graphics.Paint.Join.ROUND
            paint.color = if (done) WHITE else 0x66FFFFFF
            canvas.drawPath(check, paint)
        }
    }

    private class Row(val root: android.widget.LinearLayout, val name: android.widget.TextView, val kg: Dial, val reps: Dial, val tick: Tick)

    /** The sheet: compact or full, at the bottom of the screen. */
    private class SheetHost(context: Context) : android.widget.FrameLayout(context) {
        private val dp = resources.displayMetrics.density
        private fun px(v: Float) = (v * dp).toInt()
        private val wrap = android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        private val fill = android.widget.LinearLayout.LayoutParams.MATCH_PARENT

        private val card = android.widget.LinearLayout(context)
        private val grab = android.view.View(context)
        private val header = android.widget.LinearLayout(context)
        private val clock = Clock(context)
        private val info = android.widget.LinearLayout(context)
        private val what = label(context, 11.5f, GREY, true)
        private val name = label(context, 18f, WHITE, true)
        private val which = label(context, 12.5f, GREY, false)
        private val controls = android.widget.LinearLayout(context)
        private val add = label(context, 13f, WHITE, true)
        private val skip = label(context, 13f, WHITE, true)
        private val open = label(context, 13f, WHITE, true)
        private val rows = android.widget.LinearLayout(context)
        private val rowViews = ArrayList<Row>()
        private val done = label(context, 16.5f, onAccent, true)

        private var downX = 0f; private var downY = 0f
        private var pulling = false
        private var tracker: android.view.VelocityTracker? = null
        private var closing = false

        private val ticker = object : Runnable {
            override fun run() {
                if (sheet !== this@SheetHost) return
                texts()
                postDelayed(this, 250)
            }
        }

        init {
            // Room above the card, so it can lean a little past its place when pulled up.
            setPadding(0, px(18f), 0, 0)
            clipChildren = false
            clipToPadding = false
            card.orientation = android.widget.LinearLayout.VERTICAL
            card.setPadding(px(14f), px(4f), px(14f), px(14f))
            // Tinted, see-through glass with a lit edge: what is underneath shows through.
            val glass = android.graphics.drawable.GradientDrawable(
                android.graphics.drawable.GradientDrawable.Orientation.TL_BR,
                intArrayOf(0xE01C1F27.toInt(), 0xEC0C0D11.toInt()),
            )
            glass.cornerRadius = 32 * dp
            glass.setStroke(px(1.2f), 0x40FFFFFF)
            card.background = glass
            addView(card, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))

            // The grabber: swipe it, or tap it, to change size.
            grab.background = rounded(0x55FFFFFF, 100 * dp)
            val grabBox = android.widget.FrameLayout(context)
            grabBox.addView(grab, LayoutParams(px(42f), px(5f), android.view.Gravity.CENTER))
            grabBox.setOnClickListener {
                haptic(context, "tick")
                fullMode = !fullMode
                applyMode(true)
            }
            card.addView(grabBox, android.widget.LinearLayout.LayoutParams(fill, px(26f)))

            // The timer. A tap on it switches between counting down and counting up.
            val switchMode = android.view.View.OnClickListener {
                haptic(context, "click")
                countUp = !countUp
                channel?.invokeMethod("timerMode", null)
                texts()
                clock.invalidate()
                view?.invalidate()
            }
            clock.setOnClickListener(switchMode)
            what.letterSpacing = 0.08f
            what.maxLines = 1
            name.maxLines = 1
            what.setOnClickListener(switchMode)
            what.setPadding(0, px(4f), 0, px(4f))
            info.orientation = android.widget.LinearLayout.VERTICAL
            info.addView(what)
            info.addView(name)
            val whichLp = android.widget.LinearLayout.LayoutParams(wrap, wrap)
            whichLp.topMargin = px(2f)
            info.addView(which, whichLp)

            fun pill(t: android.widget.TextView, text: String, action: () -> Unit) {
                t.text = text
                t.setPadding(px(14f), px(10f), px(14f), px(10f))
                t.background = rounded(0x24FFFFFF, 100 * dp)
                t.setOnClickListener {
                    haptic(context, "tick")
                    action()
                }
            }
            pill(add, "+15 s") { channel?.invokeMethod("restAdd", null) }
            pill(skip, "Skip rest") { channel?.invokeMethod("restSkip", null) }
            pill(open, "Open Prism") { openPrism(context) }
            controls.gravity = android.view.Gravity.CENTER_VERTICAL
            val gapLp = { android.widget.LinearLayout.LayoutParams(wrap, wrap).also { it.leftMargin = px(8f) } }
            controls.addView(add, android.widget.LinearLayout.LayoutParams(wrap, wrap))
            controls.addView(skip, gapLp())
            controls.addView(open, gapLp())

            header.addView(clock)
            header.addView(info)
            header.addView(controls)
            card.addView(header, android.widget.LinearLayout.LayoutParams(fill, wrap))

            rows.orientation = android.widget.LinearLayout.VERTICAL
            val rowsLp = android.widget.LinearLayout.LayoutParams(fill, wrap)
            rowsLp.topMargin = px(12f)
            card.addView(rows, rowsLp)

            done.gravity = android.view.Gravity.CENTER
            done.setOnClickListener {
                haptic(context, "click")
                if (current in sets.indices) channel?.invokeMethod("toggle", current)
                // In the small sheet, logging is the whole errand: it folds away again.
                if (!fullMode) closeSheet(context)
            }
            val doneLp = android.widget.LinearLayout.LayoutParams(fill, px(56f))
            doneLp.topMargin = px(10f)
            card.addView(done, doneLp)

            applyMode(false)
            sync()
        }

        private fun buildRows() {
            rows.removeAllViews()
            rowViews.clear()
            for (i in sets.indices) {
                val root = android.widget.LinearLayout(context)
                root.gravity = android.view.Gravity.CENTER_VERTICAL
                val n = label(context, 15f, WHITE, true)
                n.gravity = android.view.Gravity.CENTER
                val kg = Dial(context, "kg", 1.0, 0.5, 0.0, 400.0)
                val reps = Dial(context, "reps", 1.0, 1.0, 0.0, 60.0)
                val tick = Tick(context)
                kg.onChange = { v ->
                    if (i in sets.indices) {
                        sets[i].kg = v
                        channel?.invokeMethod("setValue", mapOf("i" to i, "kg" to sets[i].kg, "reps" to sets[i].reps))
                    }
                }
                reps.onChange = { v ->
                    if (i in sets.indices) {
                        sets[i].reps = v.toInt()
                        channel?.invokeMethod("setValue", mapOf("i" to i, "kg" to sets[i].kg, "reps" to sets[i].reps))
                    }
                }
                tick.setOnClickListener {
                    haptic(context, "click")
                    channel?.invokeMethod("toggle", i)
                }
                root.addView(n, android.widget.LinearLayout.LayoutParams(px(30f), wrap))
                root.addView(kg, android.widget.LinearLayout.LayoutParams(0, px(56f), 1.12f))
                val repsLp = android.widget.LinearLayout.LayoutParams(0, px(56f), 1f)
                repsLp.leftMargin = px(8f)
                root.addView(reps, repsLp)
                val tickLp = android.widget.LinearLayout.LayoutParams(px(52f), px(56f))
                tickLp.leftMargin = px(4f)
                root.addView(tick, tickLp)
                val lp = android.widget.LinearLayout.LayoutParams(fill, wrap)
                lp.topMargin = px(6f)
                rows.addView(root, lp)
                rowViews.add(Row(root, n, kg, reps, tick))
            }
        }

        /** Lays the same parts out for the small sheet or the tall one. */
        private fun applyMode(animated: Boolean) {
            val full = fullMode
            header.orientation = if (full) android.widget.LinearLayout.VERTICAL else android.widget.LinearLayout.HORIZONTAL
            header.gravity = if (full) android.view.Gravity.CENTER_HORIZONTAL else android.view.Gravity.CENTER_VERTICAL
            val size = px(if (full) 150f else 62f)
            clock.layoutParams = android.widget.LinearLayout.LayoutParams(size, size)
            val infoLp = if (full) android.widget.LinearLayout.LayoutParams(wrap, wrap) else android.widget.LinearLayout.LayoutParams(0, wrap, 1f)
            if (full) infoLp.topMargin = px(10f) else infoLp.leftMargin = px(12f)
            info.layoutParams = infoLp
            info.gravity = if (full) android.view.Gravity.CENTER_HORIZONTAL else android.view.Gravity.START
            // Centred under the big timer in the tall sheet; beside the small one otherwise.
            val side = if (full) android.view.Gravity.CENTER_HORIZONTAL else android.view.Gravity.START
            what.gravity = side
            name.gravity = side
            which.gravity = side
            val ctlLp = android.widget.LinearLayout.LayoutParams(wrap, wrap)
            if (full) ctlLp.topMargin = px(12f)
            controls.layoutParams = ctlLp
            sync()
            if (animated) {
                card.alpha = 0.65f
                card.translationY = if (full) 30 * dp else -14 * dp
                card.animate().alpha(1f).translationY(0f).setDuration(260).setInterpolator(android.view.animation.OvershootInterpolator(1.3f)).start()
            }
        }

        private fun texts() {
            val t = reading(System.currentTimeMillis())
            // The tall sheet has room to say what a tap does; the small one shows a pair of arrows.
            what.text = when {
                !t.resting -> t.what
                fullMode -> t.what + (if (countUp) "  \u00B7  TAP TO COUNT DOWN" else "  \u00B7  TAP TO COUNT UP")
                else -> t.what + "  \u21C4"
            }
            what.setTextColor(if (t.resting) accent else GREY)
            val show = if (fullMode && t.resting) android.view.View.VISIBLE else android.view.View.GONE
            if (add.visibility != show) {
                add.visibility = show
                skip.visibility = show
            }
        }

        /** Brings everything shown up to date with the workout. */
        fun sync() {
            if (rowViews.size != sets.size) buildRows()
            val full = fullMode
            name.text = title
            which.text = if (full) exercise else setLabel
            for (i in rowViews.indices) {
                val r = rowViews[i]
                val s = sets[i]
                if (!r.kg.dragging) r.kg.value = s.kg
                if (!r.reps.dragging) r.reps.value = s.reps.toDouble()
                r.tick.done = s.done
                r.kg.isEnabled = !s.done
                r.reps.isEnabled = !s.done
                r.kg.alpha = if (s.done) 0.5f else 1f
                r.reps.alpha = if (s.done) 0.5f else 1f
                r.name.text = if (i == 0) "W" else i.toString()
                r.name.setTextColor(if (i == 0) GREY else WHITE)
                r.root.visibility = if (full || i == current) android.view.View.VISIBLE else android.view.View.GONE
                r.name.visibility = if (full) android.view.View.VISIBLE else android.view.View.GONE
                r.tick.visibility = if (full) android.view.View.VISIBLE else android.view.View.GONE
                if (full) {
                    r.root.setPadding(px(6f), px(6f), px(4f), px(6f))
                    r.root.background = when {
                        s.done -> rounded(tint(GREEN, 0x1F), 24 * dp)
                        i == current -> rounded(0x14FFFFFF, 24 * dp, tint(accent, 0x99), px(1.5f))
                        else -> rounded(0x0AFFFFFF, 24 * dp)
                    }
                } else {
                    r.root.setPadding(0, 0, 0, 0)
                    r.root.background = null
                }
            }
            done.text = if (current in sets.indices) "Set done  ·  " + number(sets[current].kg) + " kg × " + sets[current].reps else "Set done"
            done.setTextColor(onAccent)
            done.background = rounded(accent, 100 * dp)
            texts()
            clock.invalidate()
        }

        /** It rises from the bottom edge. */
        fun arrive() {
            card.translationY = 260 * dp
            card.alpha = 0f
            card.animate().translationY(0f).alpha(1f).setDuration(320).setInterpolator(android.view.animation.OvershootInterpolator(0.9f)).start()
            postDelayed(ticker, 250)
        }

        /** It sinks away again. */
        fun leave(then: () -> Unit) {
            if (closing) return
            closing = true
            card.animate().translationY(card.height + 40 * dp).alpha(0f).setDuration(190)
                .setInterpolator(android.view.animation.AccelerateInterpolator(1.4f)).withEndAction { then() }.start()
        }

        private fun settle() {
            card.animate().translationY(0f).setDuration(240).setInterpolator(android.view.animation.OvershootInterpolator(1.6f)).start()
        }

        override fun dispatchTouchEvent(e: android.view.MotionEvent): Boolean {
            // A touch anywhere outside folds it away; the touch still reaches the app underneath.
            if (e.actionMasked == android.view.MotionEvent.ACTION_OUTSIDE) {
                closeSheet(context)
                return true
            }
            return super.dispatchTouchEvent(e)
        }

        private fun watch(e: android.view.MotionEvent) {
            val copy = android.view.MotionEvent.obtain(e)
            copy.setLocation(e.rawX, e.rawY)
            tracker?.addMovement(copy)
            copy.recycle()
        }

        private fun startsPull(e: android.view.MotionEvent): Boolean {
            val dx = e.rawX - downX; val dy = e.rawY - downY
            return Math.abs(dy) > 10 * dp && Math.abs(dy) > Math.abs(dx) * 1.3f
        }

        // An up-or-down drag that starts anywhere on the sheet, even on a dial, moves the sheet.
        override fun onInterceptTouchEvent(e: android.view.MotionEvent): Boolean {
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; pulling = false
                    tracker?.recycle()
                    tracker = android.view.VelocityTracker.obtain()
                    watch(e)
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    watch(e)
                    if (!pulling && startsPull(e)) {
                        pulling = true
                        return true
                    }
                }
            }
            return false
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_MOVE -> {
                    watch(e)
                    if (!pulling && startsPull(e)) pulling = true
                    if (pulling) {
                        val dy = e.rawY - downY
                        // Down, it follows the finger. Up, it only leans: there is nowhere for it to go but taller.
                        card.translationY = if (dy > 0) dy else -Math.min(16 * dp, -dy * 0.16f)
                    }
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    watch(e)
                    var vy = 0f
                    val t = tracker
                    if (t != null) {
                        t.computeCurrentVelocity(1000)
                        vy = t.yVelocity
                    }
                    tracker?.recycle()
                    tracker = null
                    if (pulling) {
                        val dy = e.rawY - downY
                        when {
                            dy > 70 * dp || vy > 1100 -> {
                                // Down: the tall sheet becomes the small one; the small one becomes the lens.
                                haptic(context, "tick")
                                if (fullMode) {
                                    fullMode = false
                                    applyMode(true)
                                } else {
                                    closeSheet(context)
                                }
                            }
                            dy < -36 * dp || vy < -1100 -> {
                                if (!fullMode) {
                                    haptic(context, "tick")
                                    fullMode = true
                                    applyMode(true)
                                } else {
                                    settle()
                                }
                            }
                            else -> settle()
                        }
                    }
                    pulling = false
                }
            }
            return true
        }
    }
}
