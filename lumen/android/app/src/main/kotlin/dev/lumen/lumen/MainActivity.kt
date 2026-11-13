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
        RestBubble.hide(applicationContext)
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
        device!!.setMethodCallHandler { call, result ->
            if (call.method == "rest") {
                val a = call.arguments as? Map<*, *>
                if (a == null) {
                    RestBubble.endsAt = 0L
                    RestBubble.hide(applicationContext)
                } else {
                    RestBubble.endsAt = (a["endsAt"] as Number).toLong()
                    RestBubble.total = (a["total"] as Number).toInt()
                    RestBubble.accent = (a["accent"] as Number).toInt()
                    RestBubble.onAccent = (a["onAccent"] as Number).toInt()
                }
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

/** The rest timer as a small round countdown floating over other apps. */
object RestBubble {
    const val OPEN_TRAIN = "dev.lumen.OPEN_TRAIN"
    var endsAt = 0L
    var total = 90
    var accent = 0xFFFFAE1A.toInt()
    var onAccent = 0xFF1D1300.toInt()
    private var view: Dot? = null

    fun show(context: Context) {
        if (view != null || endsAt <= System.currentTimeMillis()) return
        if (!android.provider.Settings.canDrawOverlays(context)) return
        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
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
            wm.addView(v, lp)
            view = v
        } catch (e: Exception) {
            view = null
        }
    }

    fun hide(context: Context) {
        val v = view ?: return
        view = null
        try {
            (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).removeView(v)
        } catch (e: Exception) {
            // Already gone.
        }
    }

    /**
     * Drawn as a small glass lens: a see-through tinted disc (the app underneath shows through
     * it), a rim lit from above, a soft highlight across the top, and the countdown as a ring in
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
        private var shadow: android.graphics.Shader? = null
        private var downX = 0f; private var downY = 0f; private var startX = 0; private var startY = 0
        private var dragged = false
        private var buzzed = false
        private val dp = resources.displayMetrics.density

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

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            val r = w / 2f
            val disc = r - 5 * dp
            // The glass: nearly clear where the light enters at the top left, deeper toward the lower right,
            // with a breath of the chosen colour in it.
            body = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                intArrayOf(shade(accent, 0.34f, 0xB0), shade(accent, 0.16f, 0xD2), 0xE60A0B0E.toInt()),
                floatArrayOf(0f, 0.55f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            // When the rest is over the lens fills with the colour itself, lit the same way.
            bodyDone = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                intArrayOf(shade(accent, 1.18f, 0xFF), accent, shade(accent, 0.72f, 0xFF)),
                floatArrayOf(0f, 0.5f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            rim = android.graphics.LinearGradient(0f, r - disc, 0f, r + disc, 0xA6FFFFFF.toInt(), 0x14FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            shine = android.graphics.LinearGradient(0f, r - disc, 0f, r - disc * 0.1f, 0x30FFFFFF, 0x00FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            shadow = android.graphics.RadialGradient(r, r + 2 * dp, r, intArrayOf(0x55000000, 0x55000000, 0x00000000), floatArrayOf(0f, 0.78f, 1f), android.graphics.Shader.TileMode.CLAMP)
            clip.reset()
            clip.addCircle(r, r, disc, android.graphics.Path.Direction.CW)
        }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val w = width.toFloat(); val r = w / 2f
            val disc = r - 5 * dp
            val left = endsAt - System.currentTimeMillis()
            val done = left <= 0
            // The shadow it casts on the app below.
            paint.style = android.graphics.Paint.Style.FILL
            paint.shader = shadow
            canvas.drawCircle(r, r + 2 * dp, r, paint)
            // The glass.
            paint.shader = if (done) bodyDone else body
            canvas.drawCircle(r, r, disc, paint)
            // Light lying across the top half.
            canvas.save()
            canvas.clipPath(clip)
            paint.shader = shine
            canvas.drawOval(r - disc * 1.25f, r - disc * 1.05f, r + disc * 1.25f, r - disc * 0.05f, paint)
            canvas.restore()
            paint.shader = null
            if (!done) {
                // The ring: what is left of the rest, with a bright bead where it ends.
                val inset = 5 * dp + 6.5f * dp
                arc.set(inset, inset, w - inset, w - inset)
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
            }
            // The rim, lit from above.
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 1.3f * dp
            paint.shader = rim
            canvas.drawCircle(r, r, disc - 0.65f * dp, paint)
            paint.shader = null
            // The time. In the last ten seconds it takes the colour, as a nudge.
            paint.style = android.graphics.Paint.Style.FILL
            val secs = ((left + 999) / 1000).coerceAtLeast(0)
            paint.color = if (done) onAccent else if (secs <= 10) shade(accent, 1.25f, 0xFF) else 0xFFFFFFFF.toInt()
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.letterSpacing = if (done) 0.06f else -0.01f
            paint.textSize = (if (done) 19f else 17.5f) * dp
            val text = if (done) "GO" else "${secs / 60}:${(secs % 60).toString().padStart(2, '0')}"
            canvas.drawText(text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            if (done && !buzzed) {
                buzzed = true
                performHapticFeedback(android.view.HapticFeedbackConstants.LONG_PRESS)
                // One small swell to say it is time.
                animate().scaleX(1.14f).scaleY(1.14f).setDuration(160).withEndAction {
                    animate().scaleX(1f).scaleY(1f).setDuration(420).setInterpolator(android.view.animation.OvershootInterpolator(3f)).start()
                }.start()
            }
            // The ring moves smoothly: redrawn about fifteen times a second while counting, not at all once it says GO.
            if (!done) postInvalidateDelayed(66)
        }

        private fun move(wm: android.view.WindowManager) {
            try { wm.updateViewLayout(this, lp) } catch (ex: Exception) {}
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager
            val screen = resources.displayMetrics
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y; dragged = false
                    animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    val dx = e.rawX - downX; val dy = e.rawY - downY
                    val slop = 10 * dp
                    if (dragged || dx * dx + dy * dy > slop * slop) {
                        dragged = true
                        lp.x = startX + dx.toInt(); lp.y = startY + dy.toInt()
                        move(wm)
                    }
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    animate().scaleX(1f).scaleY(1f).setDuration(220).setInterpolator(android.view.animation.OvershootInterpolator(2.5f)).start()
                    if (e.actionMasked == android.view.MotionEvent.ACTION_UP && !dragged) {
                        // Tapped: back to the workout.
                        val i = android.content.Intent(context, MainActivity::class.java)
                            .setAction(OPEN_TRAIN)
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                        try { context.startActivity(i) } catch (ex: Exception) {}
                        hide(context)
                    } else if (lp.y > screen.heightPixels * 0.84f) {
                        // Dropped at the bottom edge: put away until the next rest.
                        hide(context)
                    } else {
                        // Let go anywhere else: it settles against the nearer side, out of the way.
                        val margin = (8 * dp).toInt()
                        val target = if (lp.x + width / 2 < screen.widthPixels / 2) margin else screen.widthPixels - width - margin
                        lp.y = lp.y.coerceIn((40 * dp).toInt(), screen.heightPixels - height - (40 * dp).toInt())
                        val slide = android.animation.ValueAnimator.ofInt(lp.x, target)
                        slide.duration = 260
                        slide.interpolator = android.view.animation.OvershootInterpolator(1.4f)
                        slide.addUpdateListener { lp.x = it.animatedValue as Int; move(wm) }
                        slide.start()
                    }
                }
            }
            return true
        }
    }
}
