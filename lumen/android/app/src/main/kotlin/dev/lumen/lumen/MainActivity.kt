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
        RestBubble.closeMenu()
        for (b in Floaters) {
            b.foreground = false
            b.refresh(applicationContext)
        }
    }

    override fun onStart() {
        super.onStart()
        for (b in Floaters) b.foreground = true
        // Prism itself is in front: no other app is.
        for (b in Floaters) b.frontApp = ""
        // A blob that only came along with an app gives way to whatever was floating before.
        RestBubble.homeAgain()
        for (b in Floaters) b.refresh(applicationContext)
    }

    override fun onPause() {
        // Prism is being left (for the recent apps, say): the lens's own menu does not stay open over what comes next.
        RestBubble.closeMenu()
        try {
            val surface = surfaceIn(window.decorView)
            if (surface != null && surface.width > 0 && surface.height > 0 && surface.holder.surface.isValid) {
                var bmp = lastFrame
                if (bmp == null || bmp.width != surface.width || bmp.height != surface.height) {
                    bmp = android.graphics.Bitmap.createBitmap(surface.width, surface.height, android.graphics.Bitmap.Config.ARGB_8888)
                    lastFrame = bmp
                }
                val target = bmp
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
        if (intent.action == Floater.OPEN_TRAIN) {
            device?.invokeMethod("train", null)
        } else if (intent.action == Floater.OPEN_ACTION) {
            device?.invokeMethod("action", intent.getIntExtra("index", 0))
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
                        // Prism has just opened this app: it is the one in front.
                        for (b in Floaters) b.frontApp = pkg
                        // Prism is told, so that the app's blob can go along if that is switched on.
                        if (RestBubble.follow) RestBubble.channel?.invokeMethod("launched", pkg)
                    }
                    result.success(i != null)
                }
                else -> result.notImplemented()
            }
        }
        // Which phone this is, for the test report.
        device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/device")
        for (b in Floaters) b.channel = device
        device!!.setMethodCallHandler { call, result ->
            if (call.method == "rest") {
                // Everything the floating workout needs to know, or nothing if no workout is on.
                val a = call.arguments as? Map<*, *>
                // (Both are told: the timer shows it, and the blob's menu opens the workout's sheet from it.)
                for (b in Floaters) {
                val endedAt = b.endsAt
                val wasOff = b.timerOff
                if (a == null) {
                    b.active = false
                } else {
                    b.active = true
                    b.title = a["title"] as String
                    b.exercise = a["exercise"] as String
                    b.setLabel = a["set"] as String
                    b.current = (a["current"] as Number).toInt()
                    b.sets = (a["sets"] as List<*>).map {
                        val m = it as Map<*, *>
                        Floater.SetRow((m["kg"] as Number).toDouble(), (m["reps"] as Number).toInt(), m["done"] as Boolean)
                    }
                    b.endsAt = (a["endsAt"] as Number).toLong()
                    b.total = (a["total"] as Number).toInt()
                    b.sinceAt = (a["sinceAt"] as Number).toLong()
                    b.countUp = a["countUp"] as Boolean
                    b.pausedAt = (a["pausedAt"] as? Number)?.toLong() ?: 0L
                    b.timerOff = (a["off"] as? Boolean) ?: false
                    b.short = (a["short"] as? String) ?: ""
                    b.hapticsOn = a["haptics"] as Boolean
                    b.accent = (a["accent"] as Number).toInt()
                    b.onAccent = (a["onAccent"] as Number).toInt()
                }
                b.restTold(endedAt, wasOff)
                b.planBuzz(applicationContext)
                b.refresh(applicationContext)
                }
                result.success(null)
            } else if (call.method == "pin") {
                // What is pinned from the blob menu to float over the phone, or nothing.
                val a = call.arguments as? Map<*, *>
                RestBubble.pinFromPrism(if (a == null) null else RestBubble.blobOf(a))
                RestBubble.refresh(applicationContext)
                result.success(null)
            } else if (call.method == "follow") {
                // The blob of an app Prism has just opened: it floats for now, tucked at the side.
                val a = call.arguments as? Map<*, *>
                if (a != null) RestBubble.followTo(applicationContext, RestBubble.blobOf(a))
                result.success(null)
            } else if (call.method == "land") {
                // A blob has been shot out of Prism's button to become the lens. The lens is put in
                // its place, unseen if it was not there, and Prism is told where that is.
                val a = call.arguments as? Map<*, *>
                // Where it was put down, if it was put down somewhere, and how fast it was going.
                val at = if (a?.get("atX") != null) floatArrayOf((a["atX"] as Number).toFloat(), (a["atY"] as Number).toFloat()) else null
                val fling = floatArrayOf(((a?.get("vx")) as? Number)?.toFloat() ?: 0f, ((a?.get("vy")) as? Number)?.toFloat() ?: 0f)
                RestBubble.incoming(applicationContext, if (a != null) RestBubble.blobOf(a) else null, at, fling) { spot -> result.success(spot) }
            } else if (call.method == "landed") {
                // Answered once the lens has been drawn, so Prism can take its own blob away then and not before.
                RestBubble.landed { result.success(null) }
            } else if (call.method == "taken") {
                // Prism has drawn the blob that was let go among its own: the lens can go.
                RestBubble.taken()
                result.success(null)
            } else if (call.method == "lensSize") {
                result.success(RestBubble.lensSizeNow(applicationContext))
            } else if (call.method == "blobNames") {
                // Whether the blobs show their names under them.
                RestBubble.blobNames = (call.arguments as? Boolean) ?: true
                result.success(null)
            } else if (call.method == "floating") {
                // Where the floating elements may be seen: over Prism itself, and over other apps.
                val where = call.arguments as? List<*>
                RestBubble.follow = (where?.getOrNull(2) as? Boolean) ?: false
                if (!RestBubble.follow) RestBubble.homeAgain()
                for (b in Floaters) {
                    b.floatIn = (where?.getOrNull(0) as? Boolean) ?: true
                    b.floatOut = (where?.getOrNull(1) as? Boolean) ?: true
                    b.refresh(applicationContext)
                }
                result.success(null)
            } else if (call.method == "fan") {
                // Where Prism's own blobs sit while they are out, or nothing when they are not.
                val fan = (call.arguments as? List<*>)?.map { (it as Number).toFloat() }
                for (b in Floaters) b.fan = fan
                // (With floating elements switched off in Prism, they are seen there only while the blobs are out.)
                if (!RestBubble.floatIn) for (b in Floaters) b.refresh(applicationContext)
                result.success(null)
            } else if (call.method == "blobs") {
                // What the blobs in the menu are, in order, so the floating lens can open the same menu.
                val list = call.arguments as? List<*>
                RestBubble.blobs = list?.mapNotNull { (it as? Map<*, *>)?.let { m -> RestBubble.blobOf(m) } } ?: emptyList()
                result.success(null)
            } else if (call.method == "pinData") {
                // The numbers the pinned sheets show.
                val a = call.arguments as Map<*, *>
                for (b in Floaters) {
                b.light = a["light"] as Boolean
                b.container = (a["container"] as? Boolean) ?: false
                b.hapticsOn = a["haptics"] as Boolean
                b.accent = (a["accent"] as Number).toInt()
                b.onAccent = (a["onAccent"] as Number).toInt()
                b.weight = (a["weight"] as Number).toDouble()
                b.kcalLeft = (a["left"] as Number).toInt()
                b.meals = (a["meals"] as List<*>).map {
                    val m = it as Map<*, *>
                    Floater.Meal((m["i"] as Number).toInt(), m["name"] as String, m["what"] as String, (m["kcal"] as Number).toInt())
                }
                b.refresh(applicationContext)
                }
                result.success(null)
            } else if (call.method == "tab") {
                // Which of Prism's own pages is the one showing.
                for (b in Floaters) b.tab = (call.arguments as Number).toInt()
                result.success(null)
            } else if (call.method == "page") {
                // Whether Prism's own workout page is the one showing.
                for (b in Floaters) b.page(applicationContext, call.arguments as Boolean)
                result.success(null)
            } else if (call.method == "overlayAllowed") {
                result.success(android.provider.Settings.canDrawOverlays(this))
            } else if (call.method == "shade") {
                // Pulls the notifications down, as a swipe from the top of the screen does.
                // Android has no public call for it; this is the one home screens have always used.
                result.success(try {
                    val bar = getSystemService("statusbar")
                    Class.forName("android.app.StatusBarManager").getMethod("expandNotificationsPanel").invoke(bar)
                    true
                } catch (e: Throwable) {
                    false
                })
            } else if (call.method == "notesAllowed") {
                result.success(RestBubble.notesAllowed(this))
            } else if (call.method == "askNotes") {
                try {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                } catch (e: Exception) {}
                result.success(null)
            } else if (call.method == "notes") {
                result.success(RestBubble.notes)
            } else if (call.method == "askOverlay") {
                try {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:$packageName")))
                } catch (e: Exception) {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
                }
                result.success(null)
            } else if (call.method == "lensTest") {
                // The long test: Prism's robot asks for one thing at a time, and is told how it went.
                val asked = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                var answered = false
                // (What is asked of the timer goes to the timer; everything else to the blob.)
                val whom = if (asked["timer"] == true) TimerBubble else RestBubble
                // Beginning, ending and keeping quiet are for both of them.
                if (asked["op"] == "begin" || asked["op"] == "end" || asked["op"] == "quiet") {
                    (if (whom === RestBubble) TimerBubble else RestBubble).test(this, asked) { }
                }
                whom.test(this, asked) { told ->
                    if (!answered) {
                        answered = true
                        try { result.success(told) } catch (e: Exception) {}
                    }
                }
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
 * the app switcher, and every page of Prism. It is in the same place everywhere and behaves
 * the same everywhere. It has three sizes on one axis:
 *
 *   lens    a glance: the timer. Drag it anywhere; drop it on the cross at the bottom to close it.
 *   compact a bottom sheet in the thumb's reach: the current set on two dials, and "Set done".
 *   full    the same sheet grown tall: a large timer, every set of the exercise, rest controls.
 *
 * Tap the lens for the sheet. Swipe the sheet up to grow it, down to shrink it, down again
 * to fold it back into the lens. Everything is drawn by Android itself, and nothing exists
 * when no workout is on.
 */
/**
 * Android tells this whenever a notification appears or goes, once the person has allowed it
 * (on Android's own screen). It keeps one number for each app: how many notifications that app
 * has that can be swiped away. Nothing here runs by itself; it only answers when told, and
 * however many notifications come and go at once it counts once, a moment later.
 */
class Notes : android.service.notification.NotificationListenerService() {
    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private var due = false
    private val counting = Runnable {
        due = false
        count()
    }

    private fun soon() {
        if (due) return
        due = true
        handler.postDelayed(counting, 400)
    }

    override fun onListenerConnected() = soon()

    override fun onNotificationPosted(sbn: android.service.notification.StatusBarNotification?) {
        // Things that only say something is running (a download's progress, music playing) are
        // not counted, and they can change many times a second: they are not looked at at all.
        if (sbn != null && (!sbn.isClearable || sbn.notification.flags and android.app.Notification.FLAG_ONGOING_EVENT != 0)) return
        soon()
    }

    override fun onNotificationRemoved(sbn: android.service.notification.StatusBarNotification?) = soon()

    override fun onNotificationRemoved(
        sbn: android.service.notification.StatusBarNotification?,
        rankingMap: android.service.notification.NotificationListenerService.RankingMap?,
        reason: Int,
    ) {
        // Removed because it was tapped: its app is the one the person has just gone to.
        if (reason == REASON_CLICK && sbn != null) for (b in Floaters) b.frontApp = sbn.packageName
        soon()
    }

    override fun onListenerDisconnected() {
        handler.removeCallbacks(counting)
        due = false
        RestBubble.setNotes(applicationContext, emptyMap())
    }

    override fun onDestroy() {
        handler.removeCallbacks(counting)
        super.onDestroy()
    }

    private fun count() {
        val next = HashMap<String, Int>()
        try {
            for (n in activeNotifications ?: emptyArray()) {
                val flags = n.notification.flags
                // Not the heading of a bundle, and not things that only say something is running.
                if (flags and android.app.Notification.FLAG_GROUP_SUMMARY != 0) continue
                if (flags and android.app.Notification.FLAG_ONGOING_EVENT != 0) continue
                if (!n.isClearable) continue
                next[n.packageName] = (next[n.packageName] ?: 0) + 1
            }
        } catch (e: Exception) {
            return
        }
        RestBubble.setNotes(applicationContext, next)
    }
}

/** The blob that floats, with its menu. */
val RestBubble = Floater(false)

/** The timer that floats. A thing of its own beside the blob: both can be on the screen. */
val TimerBubble = Floater(true)

val Floaters = arrayOf(RestBubble, TimerBubble)

/**
 * One floating thing and everything that belongs to it: its window, the cross it is dropped
 * on, its sheet, its handle when tucked away. There are two, made from this same code, so
 * they behave alike in every way: the blob ([timer] false) and the timer ([timer] true).
 * Each is told the same things by Prism; what differs is only what it shows.
 */
class Floater(val timer: Boolean) {
    companion object {
        const val OPEN_TRAIN = "dev.lumen.OPEN_TRAIN"
        const val OPEN_ACTION = "dev.lumen.OPEN_ACTION"
        private const val WHITE = 0xFFFFFFFF.toInt()
        private const val GREY = 0xFFA9ACB6.toInt()
        private const val GREEN = 0xFF2FA84F.toInt()
        private const val SHEET_AUTO = -1
        private const val SHEET_WORKOUT = -2

        // How far to either side of the cross the timer's other two places are, and how large
        // the timer must be for its controls to be under it instead (both in dp).
        private const val SIDE = 104
        private const val BIG = 170
    }

    /** Whether the timer is large enough to carry its controls under it. Then only the cross is at the foot. */
    private fun big(context: Context): Boolean = timer && lensSize >= BIG * context.resources.displayMetrics.density

    /** A new rest was begun, or the timer switched on again: one that was closed is back. */
    fun restTold(endedAt: Long, wasOff: Boolean) {
        if (timer && dismissed && ((endsAt > 0 && endsAt != endedAt) || (wasOff && !timerOff))) dismissed = false
    }

    /**
     * What the timer's three places do. 0 the cross: the timer is stopped and taken off the
     * screen. 1 pause: it stands, or goes on again. 2 count up: it counts up from nothing.
     */
    private fun timerDo(context: Context, what: Int) {
        when (what) {
            1 -> channel?.invokeMethod("timerPause", null)
            2 -> channel?.invokeMethod("timerUp", null)
            else -> {
                dismissed = true
                if (!timerOff) channel?.invokeMethod("timerOff", null)
                closeTray(context)
                refresh(context)
            }
        }
    }

    /** The signs on the timer's places: 0 a cross, 1 pause (or go on, when it stands), 2 a stopwatch with an arrow up. */
    private fun paintSign(canvas: android.graphics.Canvas, what: Int, cx: Float, cy: Float, dp: Float, paint: android.graphics.Paint) {
        paint.color = WHITE
        paint.strokeCap = android.graphics.Paint.Cap.ROUND
        paint.strokeJoin = android.graphics.Paint.Join.ROUND
        when (what) {
            0 -> {
                val a = 8.5f * dp
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 2.6f * dp
                canvas.drawLine(cx - a, cy - a, cx + a, cy + a, paint)
                canvas.drawLine(cx - a, cy + a, cx + a, cy - a, paint)
            }
            1 -> if (pausedAt > 0) {
                // Standing: the sign to go on.
                paint.style = android.graphics.Paint.Style.FILL_AND_STROKE
                paint.strokeWidth = 2f * dp
                val t = android.graphics.Path()
                t.moveTo(cx - 5 * dp, cy - 8 * dp); t.lineTo(cx + 8 * dp, cy); t.lineTo(cx - 5 * dp, cy + 8 * dp); t.close()
                canvas.drawPath(t, paint)
            } else {
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 4.2f * dp
                canvas.drawLine(cx - 5 * dp, cy - 7.5f * dp, cx - 5 * dp, cy + 7.5f * dp, paint)
                canvas.drawLine(cx + 5 * dp, cy - 7.5f * dp, cx + 5 * dp, cy + 7.5f * dp, paint)
            }
            else -> {
                // A stopwatch, and beside it an arrow up.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 2.2f * dp
                val wx = cx - 4.5f * dp; val wy = cy + 1.5f * dp
                canvas.drawCircle(wx, wy, 7.5f * dp, paint)
                canvas.drawLine(wx, wy - 7.5f * dp, wx, wy - 10.5f * dp, paint)
                canvas.drawLine(wx - 2.6f * dp, wy - 11f * dp, wx + 2.6f * dp, wy - 11f * dp, paint)
                canvas.drawLine(wx, wy, wx, wy - 4f * dp, paint)
                val ax = cx + 9.5f * dp
                canvas.drawLine(ax, cy + 7 * dp, ax, cy - 7 * dp, paint)
                canvas.drawLine(ax - 3.6f * dp, cy - 3.2f * dp, ax, cy - 7 * dp, paint)
                canvas.drawLine(ax + 3.6f * dp, cy - 3.2f * dp, ax, cy - 7 * dp, paint)
            }
        }
    }

    // The timer's controls, under it once it is large: the same three, in the same order as
    // at the foot of the screen. A small window of its own that is there only while the timer
    // lies still, and goes the moment the timer is touched.
    private var tray: Tray? = null
    private var trayTries = 0
    private val trayLater = Runnable { view?.let { syncTray(it.context) } }

    private fun closeTray(context: Context) {
        watcher.removeCallbacks(trayLater)
        val t = tray ?: return
        tray = null
        try { wm(context).removeView(t) } catch (e: Exception) {}
    }

    /** Looked at again a little later: after it is let go the timer is still on its way for a moment. */
    private fun trayAfter(ms: Long) {
        if (!timer) return
        watcher.removeCallbacks(trayLater)
        watcher.postDelayed(trayLater, ms)
    }

    private fun syncTray(context: Context) {
        if (!timer) return
        val v = view
        val want = v != null && mode() == 1 && !tucked && !docked && sheet == null && !swallowing && big(context)
        if (v == null || !want) {
            closeTray(context)
            return
        }
        if (v.busy()) {
            // Still moving, or in the hand: not yet. Looked at again shortly, a few times at most.
            closeTray(context)
            if (trayTries++ < 12) trayAfter(250)
            return
        }
        trayTries = 0
        val d = context.resources.displayMetrics
        val dp = d.density
        val w = (176 * dp).toInt(); val h = (56 * dp).toInt()
        val size = v.ownSize()
        val x = (v.lensLeft() + size / 2 - w / 2).coerceIn((8 * dp).toInt(), Math.max((8 * dp).toInt(), d.widthPixels - w - (8 * dp).toInt()))
        // Under it; where there is no room under it, over it.
        val under = (v.lensTop() + size + 6 * dp).toInt()
        val y = if (under + h < d.heightPixels - 24 * dp) under else (v.lensTop() - h - 6 * dp).toInt()
        val t = tray
        if (t != null) {
            val l = t.layoutParams as android.view.WindowManager.LayoutParams
            if (l.x != x || l.y != y) {
                l.x = x; l.y = y
                try { wm(context).updateViewLayout(t, l) } catch (e: Exception) {}
            }
            t.invalidate()
            return
        }
        try {
            val n = Tray(context)
            val l = android.view.WindowManager.LayoutParams(
                w, h,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            l.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            l.x = x; l.y = y
            if (Build.VERSION.SDK_INT >= 34) l.setCanPlayMoveAnimation(false)
            wm(context).addView(n, l)
            n.alpha = 0f
            n.animate().alpha(1f).setDuration(140).start()
            tray = n
        } catch (e: Exception) {
            tray = null
        }
    }

    private inner class Tray(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val dp = resources.displayMetrics.density
        private var down = -1

        private fun at(x: Float): Int = (x / (width / 3f)).toInt().coerceIn(0, 2)

        override fun onDraw(canvas: android.graphics.Canvas) {
            val cy = height / 2f
            for (k in 0..2) {
                val cx = width / 6f + k * width / 3f
                val r = 24 * dp
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = if (down == k) 0xF0262A33.toInt() else 0xE0101216.toInt()
                canvas.drawCircle(cx, cy, r, paint)
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 1.3f * dp
                paint.color = if (down == k) accent else 0x66FFFFFF
                canvas.drawCircle(cx, cy, r - paint.strokeWidth / 2, paint)
                canvas.save()
                canvas.scale(0.82f, 0.82f, cx, cy)
                // Left to right as at the foot of the screen: pause, the cross, count up.
                paintSign(canvas, if (k == 0) 1 else if (k == 1) 0 else 2, cx, cy, dp, paint)
                canvas.restore()
            }
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> { down = at(e.x); invalidate() }
                android.view.MotionEvent.ACTION_CANCEL -> { down = -1; invalidate() }
                android.view.MotionEvent.ACTION_UP -> {
                    val k = down
                    down = -1
                    invalidate()
                    if (k >= 0 && k == at(e.x) && e.y >= 0 && e.y <= height) {
                        haptic(context, if (k == 1) "thud" else "click")
                        timerDo(context, if (k == 0) 1 else if (k == 1) 0 else 2)
                    }
                }
            }
            return true
        }
    }

    /** How many notifications each app has, by package. Empty until the person allows Prism to be told. */
    var notes: Map<String, Int> = emptyMap()
        private set

    fun setNotes(context: Context, next: Map<String, Int>) {
        if (next == notes) return
        notes = next
        try { channel?.invokeMethod("notes", next) } catch (e: Exception) {}
        view?.invalidate()
        menu?.invalidate()
    }

    fun notesAllowed(context: Context): Boolean {
        val listed = android.provider.Settings.Secure.getString(context.contentResolver, "enabled_notification_listeners") ?: return false
        return listed.split(":").any { android.content.ComponentName.unflattenFromString(it)?.packageName == context.packageName }
    }


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

    // Paused: the moment it was paused, and the time stands at that moment. Otherwise 0.
    var pausedAt = 0L

    // Switched off: no timer is shown anywhere, only which set this is.
    var timerOff = false
    var short = ""
    var accent = 0xFFFFAE1A.toInt()
    var onAccent = 0xFF1D1300.toInt()
    var foreground = true
    var onTrain = false

    /** Prism's own Haptics switch. The floating parts obey it too. */
    var hapticsOn = true

    /** Something from Prism's blob menu, pinned to float over the phone. */
    class Pin(
        val key: String, val kind: String, val index: Int, val pkg: String, val name: String, val color: Int,
        val icon: android.graphics.Bitmap?, val picture: Boolean,
        // The colour of the small number on it (the one opposite its own, which Prism works
        // out), and the package its notifications come under.
        val badge: Int, val notesFor: String,
        // Which of the menu's five places it is in, where that is known.
        val slot: Int,
    ) {
        /** The same thing, in another of the menu's places. */
        fun inPlace(place: Int) = Pin(key, kind, index, pkg, name, color, icon, picture, badge, notesFor, place)
    }

    class Meal(val index: Int, val name: String, val what: String, val kcal: Int)

    var pin: Pin? = null

    /**
     * The lens's style. True: a container. It is always the same glass button in Prism's colour;
     * what was put in it sits inside it as its blob; held, it opens the blob menu. False: the
     * lens as it was at build 63, which takes on the look of the thing pinned to it.
     */
    var container = false

    /** What the blobs in the menu are, in order: the same blobs Prism's own button shows. */
    var blobs: List<Pin> = emptyList()
    private var menu: Menu? = null

    // Where Prism's own blobs sit while they are out: the middle of its button, and how near
    // and how far from it counts as among them. A lens let go among them is put back with them.
    var fan: List<Float>? = null

    // Which app is in front, as far as Prism knows, by its package; nothing when Prism itself is
    // in front or when it cannot say. Prism is the home screen, so it opens most apps itself
    // (from a blob, the app list, the lens, the lens's menu) and each time notes which. It is
    // told when the person heads for the recent apps, from where they may come back to any
    // app, and forgets. Nothing looks, and nothing is asked of Android: it is only remembered.
    // It is what lets a tap on the lens tell "take me to my app" from "I am in my app already".
    var frontApp = ""

    // Which of Prism's own pages is showing.
    var tab = 0

    private var frontListener: android.content.BroadcastReceiver? = null

    private fun listenForFront(context: Context) {
        if (frontListener != null) return
        val app = context.applicationContext
        val r = object : android.content.BroadcastReceiver() {
            override fun onReceive(c: Context, i: android.content.Intent) {
                val why = i.getStringExtra("reason")
                if (why == "recentapps" || why == "homekey") frontApp = ""
            }
        }
        try {
            @Suppress("DEPRECATION")
            val filter = android.content.IntentFilter(android.content.Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(r, filter, Context.RECEIVER_EXPORTED) else app.registerReceiver(r, filter)
            frontListener = r
        } catch (e: Exception) {
            frontListener = null
        }
    }

    // Where the floating elements may be seen, as chosen in Prism: over Prism itself, and over
    // other apps. Switched off in Prism, they are still seen there while its blobs are out, so
    // that one can be put back among them. Switched off in both, there are none.
    var floatIn = true
    var floatOut = true

    // "Launch and follow". An app opened from Prism brings its blob along as the one in the
    // lens, tucked at the side: a guest, in nobody's place. What the person had floating (or
    // nothing) is kept aside and is back when Prism is. The five blobs are never changed by it.
    var follow = false
    private var guest = false
    private var own: Pin? = null
    private var tuckWhenShown = false

    /** What Prism says is pinned. While a guest is in the lens it is only noted, for afterwards. */
    fun pinFromPrism(p: Pin?) {
        if (guest) own = p else pin = p
    }

    fun followTo(context: Context, blob: Pin) {
        if (!follow || !floatOut || !container || blob.kind != "app") return
        // Already the one in the lens: it stays as it is.
        if (pin?.key == blob.key) return
        if (!guest) {
            own = pin
            guest = true
        }
        pin = blob
        tuckWhenShown = true
        refresh(context)
        val v = view
        if (v != null) v.post { if (tuckWhenShown) { tuckWhenShown = false; v.tuckNow() } }
    }

    /** Prism is in front again, or following was switched off: the guest goes. */
    fun homeAgain() {
        if (!guest) return
        guest = false
        tuckWhenShown = false
        pin = own
        own = null
    }

    private fun seen(): Boolean = if (foreground) (floatIn || (floatOut && fan != null)) else floatOut

    // Whether the blobs show their names under them, as chosen in Prism. Without them the
    // blobs sit a little nearer.
    var blobNames = true

    // A lens has been dropped on the cross and is being closed. Until that is done no new lens is made.
    private var swallowing = false
    private var afterSwallow: (() -> Unit)? = null

    /** Takes the lens itself off the screen, leaving the cross to finish. */
    private fun dropLens(context: Context) {
        closeReach(context)
        closeGrip(context)
        val v = view ?: return
        view = null
        try { wm(context).removeView(v) } catch (e: Exception) {}
    }

    // A lens put in place for a blob that is still on its way to it is not seen until the blob lands.
    private var unseen = false

    // A blob put down somewhere becomes the lens there, and then does what any lens does when
    // let go: this is how fast it was going when it was.
    private var flingX = 0f
    private var flingY = 0f
    private var placedDown = false

    /**
     * A blob is on its way from Prism's blobs to become the lens, or to go into it. The lens is
     * put in its place, unseen if there was none: its usual place, or, if the blob was put down
     * somewhere ([at], the middle of where, on the screen), there. [done] is told where the lens
     * is on the screen: its corner and its size, in pixels. Nothing, if it cannot float here.
     */
    fun incoming(context: Context, blob: Pin?, at: FloatArray?, fling: FloatArray, done: (Map<String, Int>?) -> Unit) {
        // Should a lens still be closing on the cross, that is finished first. Then this blob is the one in the lens.
        afterSwallow?.invoke()
        if (blob != null) pin = blob
        if (at != null && !docked && sheet == null) {
            // Put down somewhere. The lens is made right there, not made elsewhere and moved:
            // Android moves a window a frame or two after it is told to, and for that long the
            // lens was seen where it had been. One that is somewhere else goes, and a new one
            // is made where the blob is.
            val size = lensSizeNow(context)
            val wantX = Math.round(at[0] - size / 2f) - lensOffX
            val wantY = Math.round(at[1] - size / 2f) - lensOffY
            val old = view
            if (old != null) {
                old.rest()
                if (Math.abs(old.lp.x - wantX) > 1 || Math.abs(old.lp.y - wantY) > 1) remove(context)
            }
            if (view == null) {
                lensX = wantX; lensY = wantY
                placed = true
                tucked = false
            }
        }
        if (view == null) unseen = true
        refresh(context)
        val v = view
        if (v == null) {
            unseen = false
            done(null)
            return
        }
        placedDown = at != null
        flingX = fling[0]
        flingY = fling[1]
        // What is in the lens, or its dot on the rim, is not drawn until the blob arrives.
        v.hideInner = true
        v.invalidate()
        var tries = 0
        var moved = false
        val answer = object : Runnable {
            override fun run() {
                if (!v.isLaidOut && tries++ < 20) {
                    v.postDelayed(this, 16)
                    return
                }
                val here = IntArray(2)
                if (v.roamingNow()) {
                    // Its window was covering its way: where the lens is comes from where its window is asked to be.
                    v.rest()
                    here[0] = v.lp.x + lensOffX
                    here[1] = v.lp.y + lensOffY
                } else {
                    v.getLocationOnScreen(here)
                    // How far a window's own place is from its place on the screen (the top bar, a
                    // camera cut-out). Found here, and used to make the next lens in the right place.
                    if (v.scaleX == 1f && v.scaleY == 1f) {
                        lensOffX = here[0] - v.lp.x
                        lensOffY = here[1] - v.lp.y
                    }
                }
                var late = 0L
                if (at != null && !moved) {
                    moved = true
                    val dx = Math.round(at[0] - v.width / 2f) - here[0]
                    val dy = Math.round(at[1] - v.height / 2f) - here[1]
                    if (dx != 0 || dy != 0) {
                        // Not quite where the blob is (the first time, before that distance is
                        // known): it is moved, and given time to have arrived before it is shown.
                        v.jumpBy(dx, dy)
                        here[0] += dx
                        here[1] += dy
                        late = 60L
                    }
                }
                val spot = mapOf("x" to here[0], "y" to here[1], "size" to v.width)
                if (late > 0L) watcher.postDelayed({ done(spot) }, late) else done(spot)
            }
        }
        v.post(answer)
        // Should the blob never arrive, the lens is not left there unseen.
        watcher.postDelayed({ if (view === v && (unseen || v.hideInner)) landed() }, 2500)
    }

    /** The blob has landed: the lens shows itself and what is in it, with the give of something just caught. */
    /** How large the lens is, in real pixels: as it is now, or as it was last left. */
    fun lensSizeNow(context: Context): Int {
        if (lensSize > 0) return lensSize
        val dp = context.resources.displayMetrics.density
        val saved = try { context.getSharedPreferences("prism_lens", Context.MODE_PRIVATE).getFloat(if (timer) "timerSize" else "size", 84f) } catch (e: Exception) { 84f }
        return ((if (timer) saved else saved.coerceIn(84f, 84f * 1.1f)) * dp).toInt()
    }

    // A lens let go among Prism's own blobs waits here until Prism has drawn the blob in its place.
    private var handBack: Runnable? = null

    fun taken() {
        val go = handBack ?: return
        handBack = null
        watcher.removeCallbacks(go)
        go.run()
    }

    /**
     * The blob has arrived where the lens is. [done] is called once the lens can be seen, so
     * that Prism takes its own blob away then and not before.
     */
    fun landed(done: (() -> Unit)? = null) {
        unseen = false
        val v = view
        if (v == null || (!v.hideInner && v.alpha == 1f)) {
            done?.invoke()
            return
        }
        if (placedDown && container && mode() == 2) {
            // Put down somewhere. The lens is first drawn as exactly the blob that was put down,
            // the same size in the same place; then the glass comes in around it. Nothing
            // jumps. If it is not at a side already it then goes to the nearer one, carrying
            // on with a flick if it was flicked.
            placedDown = false
            val fx = flingX
            val fy = flingY
            v.arrive(done) { if (view === v) v.letFly(fx, fy) }
            return
        }
        v.hideInner = false
        v.alpha = 1f
        v.invalidate()
        v.thump()
        // Prism is told once the lens has had time to be drawn.
        if (done != null) watcher.postDelayed({ done() }, 70)
        if (placedDown) {
            // Put down somewhere: it is seen there first, where it was put. A moment later it
            // goes to the nearer side, carrying on with a flick if it was flicked.
            placedDown = false
            val fx = flingX
            val fy = flingY
            watcher.postDelayed({ if (view === v) v.letFly(fx, fy) }, 130)
        }
    }

    // The pictures of the blobs, by what each blob is. Prism sends them again whenever anything
    // about the blobs changes; a picture that is the same as last time is kept, not decoded again.
    private val icons = HashMap<String, Pair<Int, android.graphics.Bitmap>>()

    fun blobOf(a: Map<*, *>): Pin {
        val bytes = a["icon"] as? ByteArray
        var bmp: android.graphics.Bitmap? = null
        if (bytes != null) {
            val key = a["key"] as String
            val mark = java.util.Arrays.hashCode(bytes)
            val had = icons[key]
            if (had != null && had.first == mark) {
                bmp = had.second
            } else {
                bmp = android.graphics.BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                if (bmp != null) {
                    if (icons.size > 48) icons.clear()
                    icons[key] = Pair(mark, bmp)
                }
            }
        }
        return Pin(
            a["key"] as String, a["kind"] as String, (a["index"] as Number).toInt(), a["package"] as String,
            a["name"] as String, (a["color"] as Number).toInt(), bmp, a["picture"] as Boolean,
            (a["badge"] as? Number)?.toInt() ?: 0xFFE5484D.toInt(), (a["notesFor"] as? String) ?: (a["package"] as String),
            (a["slot"] as? Number)?.toInt() ?: -1,
        )
    }

    private val badgePaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)

    /** The small number on an app: how many notifications it has. Drawn with its middle at the given place. */
    private fun paintBadge(canvas: android.graphics.Canvas, b: Pin, cx: Float, cy: Float, dp: Float, scale: Float = 1f) {
        val count = if (b.kind == "app") notes[b.notesFor] ?: 0 else 0
        if (count <= 0) return
        val text = if (count > 99) "99+" else count.toString()
        val p = badgePaint
        p.typeface = boldFace
        p.textSize = 11.5f * dp * scale
        p.textAlign = android.graphics.Paint.Align.CENTER
        val r = 10.5f * dp * scale
        val half = Math.max(r, (p.measureText(text) + 9 * dp * scale) / 2f)
        val edge = 1.8f * dp * scale
        p.style = android.graphics.Paint.Style.FILL
        // A dark edge, so it stands clear of whatever it lies on.
        p.color = 0xEB101216.toInt()
        canvas.drawRoundRect(cx - half - edge, cy - r - edge, cx + half + edge, cy + r + edge, r + edge, r + edge, p)
        p.color = b.badge
        canvas.drawRoundRect(cx - half, cy - r, cx + half, cy + r, r, r, p)
        p.color = 0xFFFFFFFF.toInt()
        canvas.drawText(text, cx, cy - (p.descent() + p.ascent()) / 2f, p)
    }
    var weight = 80.0
    var kcalLeft = 0
    var meals: List<Meal> = emptyList()


    private var view: Dot? = null
    private var target: Target? = null
    private var sheet: Sheet? = null

    /**
     * While a sheet is open the lens sits on the sheet's top corner, as the button that folds
     * it away again. It goes back to where it was when the sheet closes.
     */
    private var docked = false
    private var homeX = 0
    private var homeY = 0
    private var dockX = -1
    private var dockY = -1
    private var lensOffX = 0
    private var lensOffY = 0
    private var dismissed = false
    private var fullMode = false
    private var lensX = -1
    private var lensY = -1
    // Whether the lens has been put somewhere. (Tucked into the left side, its place is past the edge.)
    private var placed = false
    private var grip: Grip? = null
    // How large the lens is, in pixels. Nothing until it is first shown; then its usual size, or the
    // size two fingers last gave it.
    private var lensSize = 0
    private var reach: Reach? = null
    // Tucked into a side of the screen, and which side.
    private var tucked = false
    private var tuckRight = true

    /** Prism's theme. The sheets follow it. The lens is always dark glass, so it reads over any app. */
    var light = false

    private fun ink(): Int = if (light) 0xFF17150F.toInt() else WHITE

    private fun muted(): Int = if (light) 0xFF5E5A50.toInt() else GREY


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
        // (A test left running overnight makes no noise.)
        if (!hapticsOn || testQuiet) return
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

    /**
     * What the lens shows. There is one lens. A workout has it while it is on (1); otherwise the
     * thing put in it has it (2); otherwise there is no lens (0).
     *
     * As a container, the two are a stack: the workout lies on top and the other thing waits
     * underneath, so closing the workout's timer shows what is underneath. As the lens was
     * before, a workout that is on keeps the lens to itself even after its timer is closed.
     */
    // What it is showing: 1 the timer, 2 a blob, 0 nothing. The timer shows only the timer,
    // the blob only a blob; neither ever turns into the other.
    private fun mode(): Int = when {
        timer -> if (active && !dismissed) 1 else 0
        pin != null -> 2
        else -> 0
    }

    /** The colour the lens is tinted with. A container is always Prism's colour, whatever is in it. */
    private fun lensColor(): Int = if (container || active) accent else (pin?.color ?: accent)

    private val blobPaint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG or android.graphics.Paint.FILTER_BITMAP_FLAG)
    private val blobClip = android.graphics.Path()
    private val blobBox = android.graphics.RectF()

    private fun mix(a: Int, b: Int, t: Float): Int {
        fun ch(shift: Int): Int {
            val x = (a shr shift) and 0xFF
            val y = (b shr shift) and 0xFF
            return (x + (y - x) * t).toInt().coerceIn(0, 255)
        }
        return (ch(24) shl 24) or (ch(16) shl 16) or (ch(8) shl 8) or ch(0)
    }

    /**
     * One blob: a disc of its colour, lighter at the top, with its mark or its picture in the
     * middle. It is the same blob wherever it is drawn: in the menu, and inside the lens.
     * [kept] gives it the bright ring of the one that is in the lens.
     */
    // A blob's colour, lighter at the top. There is one of these for each colour, made the first
    // time that colour is drawn, for a blob one pixel across; each time a blob is drawn it is set
    // to that blob's place and size. So nothing is made while drawing, however many blobs move.
    private val blobShades = android.util.SparseArray<android.graphics.LinearGradient>()
    private val blobMatrix = android.graphics.Matrix()
    private val boldFace: android.graphics.Typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)

    private fun blobShade(color: Int, cx: Float, cy: Float, radius: Float): android.graphics.Shader {
        var g = blobShades.get(color)
        if (g == null) {
            g = android.graphics.LinearGradient(0f, -1f, 0f, 1f, mix(color, WHITE, 0.14f), color, android.graphics.Shader.TileMode.CLAMP)
            blobShades.put(color, g)
        }
        blobMatrix.setScale(radius, radius)
        blobMatrix.postTranslate(cx, cy)
        g.setLocalMatrix(blobMatrix)
        return g
    }

    private fun paintBlob(
        canvas: android.graphics.Canvas, b: Pin, cx: Float, cy: Float, radius: Float, dp: Float,
        face: Boolean = true, alpha: Int = 255,
    ) {
        val p = blobPaint
        val scale = radius / (31 * dp)
        p.style = android.graphics.Paint.Style.FILL
        p.shader = blobShade(b.color, cx, cy, radius)
        p.alpha = alpha
        canvas.drawCircle(cx, cy, radius, p)
        p.shader = null
        p.style = android.graphics.Paint.Style.STROKE
        p.strokeWidth = dp * Math.max(scale, 0.6f)
        p.color = tint(WHITE, (0.2f * alpha).toInt())
        canvas.drawCircle(cx, cy, radius - p.strokeWidth / 2f, p)
        p.style = android.graphics.Paint.Style.FILL
        if (!face) return
        p.color = tint(WHITE, alpha)
        val bmp = b.icon
        if (bmp != null) {
            // Prism's own marks, an app's outline, and an app's picture are drawn at the sizes the menu in Prism draws them.
            val half = (if (b.picture) 18f else if (b.kind == "app") 17f else 15f) * dp * scale
            blobBox.set(cx - half, cy - half, cx + half, cy + half)
            if (b.picture) {
                blobClip.reset()
                blobClip.addCircle(cx, cy, half, android.graphics.Path.Direction.CW)
                canvas.save()
                canvas.clipPath(blobClip)
                canvas.drawBitmap(bmp, null, blobBox, p)
                canvas.restore()
            } else {
                canvas.drawBitmap(bmp, null, blobBox, p)
            }
        } else if (b.name.isNotEmpty()) {
            p.textAlign = android.graphics.Paint.Align.CENTER
            p.typeface = boldFace
            p.textSize = 24 * dp * scale
            canvas.drawText(b.name.substring(0, 1).uppercase(), cx, cy - (p.descent() + p.ascent()) / 2f, p)
        }
    }

    /**
     * Does what a blob is, once, from the lens's menu: its app opens, or its action is done in
     * place where that is possible. What is in the lens does not change.
     */
    private fun use(context: Context, b: Pin) {
        if (b.key == pin?.key && mode() == 2) {
            // It is the one in the lens: it does what it is.
            usePinned(context)
        } else if (b.kind == "app") {
            val i = context.packageManager.getLaunchIntentForPackage(b.pkg)
            if (i != null) {
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                try {
                    context.startActivity(i)
                    frontApp = b.pkg
                    // Opened from the lens's own menu: with following on, this one is in the lens now.
                    followTo(context, b)
                } catch (e: Exception) {}
            } else {
                haptic(context, "thud")
            }
        } else if (b.kind == "screen") {
            openScreen(context, b.index)
        } else if (b.index == 1 || b.index == 3) {
            // Logging food and weighing in are done right here, over whatever is open.
            openSheet(context, b.index)
        } else if (b.index == 0 && active) {
            // The workout that is on: its sheet, right here.
            openSheet(context, SHEET_WORKOUT)
        } else {
            openAction(context, b.index)
        }
    }

    private fun openMenu(context: Context) {
        val v = view ?: return
        if (menu != null || blobs.isEmpty()) return
        v.rest()
        try {
            val dp = context.resources.displayMetrics.density
            val at = IntArray(2)
            v.getLocationOnScreen(at)
            // The lens is still pressed in a little; its middle is found from the size it is drawn at.
            val m = Menu(context, at[0] + v.width * v.scaleX / 2f, at[1] + v.height * v.scaleY / 2f, v.width / 2f - 5 * dp)
            // It can be given the back button, so it takes the focus while it is open.
            val lp = android.view.WindowManager.LayoutParams(
                android.view.WindowManager.LayoutParams.MATCH_PARENT, android.view.WindowManager.LayoutParams.MATCH_PARENT,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            if (Build.VERSION.SDK_INT >= 28) {
                lp.layoutInDisplayCutoutMode = android.view.WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
            wm(context).addView(m, lp)
            menu = m
            listenForMenu(context)
        } catch (e: Exception) {
            menu = null
        }
    }

    private fun removeMenu(context: Context) {
        val m = menu ?: return
        menu = null
        try { wm(context).removeView(m) } catch (e: Exception) {}
        val r = menuListener
        menuListener = null
        if (r != null) try { context.applicationContext.unregisterReceiver(r) } catch (e: Exception) {}
    }

    /** Closes the lens's own menu, if it is open. */
    fun closeMenu() {
        menu?.close()
    }

    // While the lens's own menu is open, and only then, this hears Android announce that the
    // person is heading for the home screen or the recent apps, and closes the menu. The menu
    // holds the focus, so it is not told any other way.
    private var menuListener: android.content.BroadcastReceiver? = null

    private fun listenForMenu(context: Context) {
        if (menuListener != null) return
        val app = context.applicationContext
        val r = object : android.content.BroadcastReceiver() {
            override fun onReceive(c: Context, i: android.content.Intent) {
                menu?.close()
            }
        }
        try {
            @Suppress("DEPRECATION")
            val filter = android.content.IntentFilter(android.content.Intent.ACTION_CLOSE_SYSTEM_DIALOGS)
            if (Build.VERSION.SDK_INT >= 33) app.registerReceiver(r, filter, Context.RECEIVER_EXPORTED) else app.registerReceiver(r, filter)
            menuListener = r
        } catch (e: Exception) {
            menuListener = null
        }
    }

    private val watcher = android.os.Handler(android.os.Looper.getMainLooper())

    // =====================================================================================
    // The long test, Android's part. Prism's robot asks for one thing at a time: a finger on
    // the lens along a path, a touch in the lens's menu or on a sheet, a minute of measuring,
    // a minute with another app in front. The finger is not there: the lens is handed the
    // same touch events a real one would send, so the code a person exercises is the code that
    // runs. Each answer says what state everything is in afterwards and how evenly the lens
    // was drawn meanwhile. None of this does anything unless the test asks.
    // =====================================================================================

    private var stamps: ArrayList<Long>? = null
    private var draws = 0L
    private var testQuiet = false
    private var awake: android.view.View? = null

    /** The lens or its menu has just been drawn. */
    private fun drawn() {
        draws++
        stamps?.add(System.nanoTime())
    }

    private fun state(context: Context): HashMap<String, Any?> {
        val d = context.resources.displayMetrics
        val m = HashMap<String, Any?>()
        val v = view
        m["ok"] = true
        m["allowed"] = android.provider.Settings.canDrawOverlays(context)
        m["w"] = d.widthPixels
        m["h"] = d.heightPixels
        m["dp"] = d.density.toDouble()
        m["lens"] = v != null
        m["mode"] = mode()
        if (v != null) {
            m["x"] = v.lensLeft() + lensOffX
            m["y"] = v.lensTop() + lensOffY
            m["size"] = v.ownSize()
            m["window"] = v.lp.width
            m["roaming"] = v.roamingNow()
            m["moving"] = v.movingNow()
            m["seen"] = v.alpha.toDouble()
        }
        m["tucked"] = tucked
        m["guest"] = guest
        m["paused"] = pausedAt > 0
        m["off"] = timerOff
        m["closed"] = dismissed
        m["tray"] = tray != null
        m["docked"] = docked
        m["pin"] = pin?.key
        m["menu"] = menu != null
        m["menuCount"] = menu?.testCount() ?: 0
        m["menuEditing"] = menu?.testEditing() ?: false
        m["sheet"] = sheet != null
        m["closing"] = swallowing
        m["blobs"] = blobs.size
        m["active"] = active
        m["endsAt"] = endsAt
        m["buzzAt"] = buzzAt
        m["cpu"] = android.os.Process.getElapsedCpuTime()
        m["draws"] = draws
        m["now"] = System.currentTimeMillis()
        m["fg"] = foreground
        m["front"] = frontApp
        return m
    }

    /** How evenly something was drawn between the stamps: how many times, how far apart, and how many gaps. */
    private fun paced(into: HashMap<String, Any?>, times: List<Long>) {
        val gaps = ArrayList<Double>()
        for (i in 1 until times.size) gaps.add((times[i] - times[i - 1]) / 1e6)
        into["frames"] = times.size
        if (gaps.isEmpty()) return
        val sorted = gaps.sorted()
        val usual = sorted[sorted.size / 2]
        // A gap is a frame that did not come: longer than a frame and a half, but not a pause
        // between two movements, which is not a stutter.
        val late = gaps.count { it > usual * 1.6 && it < 120.0 }
        into["usualMs"] = usual
        into["late"] = late
        into["worstMs"] = gaps.filter { it < 120.0 }.maxOrNull() ?: 0.0
    }

    private fun touch(v: android.view.View, action: Int, sx: Float, sy: Float, down: Long, local: Boolean = false) {
        val e = android.view.MotionEvent.obtain(down, android.os.SystemClock.uptimeMillis(), action, sx, sy, 0)
        e.source = android.view.InputDevice.SOURCE_TOUCHSCREEN
        if (!local) {
            // Given as a place on the screen; the view is told where that is in itself as well.
            val at = IntArray(2)
            v.getLocationOnScreen(at)
            e.offsetLocation(-at[0].toFloat(), -at[1].toFloat())
        }
        try { v.dispatchTouchEvent(e) } catch (ex: Exception) {}
        e.recycle()
    }

    private fun points(a: Any?): List<FloatArray> = (a as? List<*>)?.mapNotNull {
        val p = it as? List<*>
        if (p != null && p.size >= 2) floatArrayOf((p[0] as Number).toFloat(), (p[1] as Number).toFloat()) else null
    } ?: emptyList()

    /**
     * A finger on [v] along [path] (places on the screen, or in the view if [local]): down at
     * the first, [holdMs] still, then to each of the others in [legMs], [endMs] still, and up.
     * With [flick] the last stretch speeds up, so the finger is moving when it lets go. Then
     * it waits until [settled] says everything has come to rest, or [settleMs] at most.
     */
    private fun finger(
        v: android.view.View, path: List<FloatArray>, local: Boolean, holdMs: Long, legMs: Long, endMs: Long, flick: Boolean,
        settleMs: Long, settled: () -> Boolean, done: () -> Unit,
    ) {
        val frames = android.view.Choreographer.getInstance()
        val down = android.os.SystemClock.uptimeMillis()
        touch(v, android.view.MotionEvent.ACTION_DOWN, path[0][0], path[0][1], down, local)
        var leg = 1
        var legStart = 0L
        var upAt = 0L
        val moveFrom = down + holdMs
        var x = path[0][0]
        var y = path[0][1]
        frames.postFrameCallback(object : android.view.Choreographer.FrameCallback {
            override fun doFrame(nanos: Long) {
                val now = android.os.SystemClock.uptimeMillis()
                if (now < moveFrom) {
                    frames.postFrameCallback(this)
                    return
                }
                if (leg < path.size) {
                    if (legStart == 0L) legStart = now
                    val t = ((now - legStart).toFloat() / Math.max(1L, legMs)).coerceIn(0f, 1f)
                    val last = leg == path.size - 1
                    val e = if (flick && last) t * t else t * t * (3 - 2 * t)
                    x = path[leg - 1][0] + (path[leg][0] - path[leg - 1][0]) * e
                    y = path[leg - 1][1] + (path[leg][1] - path[leg - 1][1]) * e
                    touch(v, android.view.MotionEvent.ACTION_MOVE, x, y, down, local)
                    if (t >= 1f) {
                        leg++
                        legStart = 0L
                    }
                    frames.postFrameCallback(this)
                    return
                }
                if (upAt == 0L) upAt = now + endMs
                if (now < upAt) {
                    frames.postFrameCallback(this)
                    return
                }
                touch(v, android.view.MotionEvent.ACTION_UP, x, y, down, local)
                val until = now + settleMs
                val wait = object : Runnable {
                    override fun run() {
                        val t = android.os.SystemClock.uptimeMillis()
                        if (t >= until || (t > now + 250 && settled())) done() else watcher.postDelayed(this, 50)
                    }
                }
                watcher.postDelayed(wait, 120)
            }
        })
    }

    private fun texts(v: android.view.View, into: ArrayList<android.widget.TextView>) {
        if (v.visibility != android.view.View.VISIBLE) return
        if (v is android.widget.TextView && v.text.isNotEmpty()) into.add(v)
        if (v is android.view.ViewGroup) for (i in 0 until v.childCount) texts(v.getChildAt(i), into)
    }

    fun test(activity: MainActivity, a: Map<*, *>, done: (Map<String, Any?>) -> Unit) {
        val context: Context = activity.applicationContext
        fun fail(why: String) {
            val m = state(context)
            m["ok"] = false
            m["note"] = why
            done(m)
        }
        fun num(k: String, d: Long): Long = (a[k] as? Number)?.toLong() ?: d
        try {
            when (a["op"] as? String) {
                "begin" -> {
                    activity.window.addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    done(state(context))
                }
                "end" -> {
                    activity.window.clearFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    stamps = null
                    testQuiet = false
                    done(state(context))
                }
                // No buzzes, for a test left running while someone sleeps.
                "quiet" -> {
                    testQuiet = a["on"] == true
                    done(state(context))
                }
                // How much memory Prism is using, in kilobytes.
                "memory" -> {
                    val m = state(context)
                    m["pss"] = android.os.Debug.getPss()
                    done(m)
                }
                // Prism is brought back to the front, from whatever app is there.
                "front" -> {
                    try {
                        context.startActivity(
                            android.content.Intent(context, MainActivity::class.java)
                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
                        )
                    } catch (e: Exception) {}
                    watcher.postDelayed({ done(state(context)) }, num("settleMs", 2500))
                }
                "state" -> done(state(context))
                // It is given a size, as two fingers would give it, within what it allows.
                "size" -> {
                    lensSize = (num("dp", 84) * context.resources.displayMetrics.density).toInt()
                    remove(context)
                    refresh(context)
                    watcher.postDelayed({ done(state(context)) }, num("settleMs", 900))
                }
                // A tap on one of the timer's controls under it: 0 pause, 1 the cross, 2 count up.
                "tray" -> {
                    val t = tray ?: return fail("the timer has no controls under it")
                    val l = t.layoutParams as android.view.WindowManager.LayoutParams
                    val i = num("i", 0).toInt().coerceIn(0, 2)
                    val at = floatArrayOf(l.x + t.width / 6f + i * t.width / 3f, l.y + t.height / 2f)
                    finger(t, listOf(at), false, 60, 0, 0, false, num("settleMs", 900), { true }) { done(state(context)) }
                }
                // A finger on the lens.
                "press" -> {
                    val v = view ?: return fail("there is no lens")
                    v.rest()
                    var path = points(a["path"])
                    if (path.isEmpty() || a["fromLens"] == true) {
                        val mid = floatArrayOf(v.lensLeft() + lensOffX + v.ownSize() / 2f, v.lensTop() + lensOffY + v.ownSize() / 2f)
                        path = listOf(mid) + path
                    }
                    val kept = ArrayList<Long>()
                    stamps = kept
                    finger(v, path, false, num("holdMs", 60), num("legMs", 300), num("endMs", 0), a["flick"] == true, num("settleMs", 1600),
                        { val now = view; now == null || (!now.movingNow() && !swallowing) }) {
                        stamps = null
                        val m = state(context)
                        paced(m, kept)
                        done(m)
                    }
                }
                // A finger in the lens's own menu.
                "menu" -> {
                    val m = menu ?: return fail("the lens's menu is not open")
                    val i = num("i", 0).toInt()
                    val spot = m.testSpot(i)
                    val kept = ArrayList<Long>()
                    stamps = kept
                    val after = {
                        stamps = null
                        val st = state(context)
                        paced(st, kept)
                        done(st)
                    }
                    when (a["what"] as? String) {
                        "key" -> {
                            stamps = null
                            val st = state(context)
                            st["key"] = m.testKey(i)
                            st["spotX"] = spot[0].toDouble()
                            st["spotY"] = spot[1].toDouble()
                            done(st)
                        }
                        "tap" -> finger(m, listOf(spot), true, 50, 0, 0, false, num("settleMs", 900), { true }, after)
                        "middle" -> finger(m, listOf(m.testMiddle()), true, 50, 0, 0, false, num("settleMs", 900), { true }, after)
                        "hold" -> finger(m, listOf(spot), true, 50, 0, android.view.ViewConfiguration.getLongPressTimeout().toLong().coerceIn(300L, 600L) + 200, false, 500, { true }, after)
                        "drag" -> {
                            val to = points(a["to"])
                            finger(m, listOf(spot) + to, true, 60, num("legMs", 450), num("endMs", 150), false, num("settleMs", 900), { true }, after)
                        }
                        "outside" -> {
                            val at = points(a["to"])
                            finger(m, if (at.isEmpty()) listOf(floatArrayOf(4f, 4f)) else at, true, 50, 0, 0, false, num("settleMs", 700), { true }, after)
                        }
                        "back" -> {
                            m.testBack()
                            watcher.postDelayed({ after() }, num("settleMs", 600))
                        }
                        else -> fail("unknown menu step")
                    }
                }
                // A finger on a sheet.
                "sheet" -> {
                    val sh = sheet ?: return fail("no sheet is open")
                    val all = ArrayList<android.widget.TextView>()
                    texts(sh, all)
                    when (a["what"] as? String) {
                        "texts" -> {
                            val st = state(context)
                            st["texts"] = all.map { it.text.toString() }
                            done(st)
                        }
                        "tap" -> {
                            val want = a["text"] as? String ?: ""
                            val t = all.firstOrNull { it.text.toString().startsWith(want) } ?: return fail("nothing on the sheet says \"$want\"")
                            val at = IntArray(2)
                            t.getLocationOnScreen(at)
                            finger(sh, listOf(floatArrayOf(at[0] + t.width / 2f, at[1] + t.height / 2f)), false, 60, 0, 0, false, num("settleMs", 900), { true }) { done(state(context)) }
                        }
                        "back" -> {
                            sh.testBack()
                            watcher.postDelayed({ done(state(context)) }, num("settleMs", 900))
                        }
                        "outside" -> {
                            touch(sh, android.view.MotionEvent.ACTION_OUTSIDE, 2f, 2f, android.os.SystemClock.uptimeMillis())
                            watcher.postDelayed({ done(state(context)) }, num("settleMs", 900))
                        }
                        else -> fail("unknown sheet step")
                    }
                }
                // Nothing is touched for a while; what the battery, the processor and the lens do meanwhile is written down.
                "measure" -> measure(context, num("ms", 60000), done)
                // The same, with another app in front: Android's own Settings.
                "away" -> {
                    if (!android.provider.Settings.canDrawOverlays(context)) return fail("not allowed over other apps")
                    try {
                        // A speck of a window that keeps the screen on while Prism is not in front.
                        val speck = android.view.View(context)
                        val slp = android.view.WindowManager.LayoutParams(
                            1, 1, android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                            android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                                android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                            android.graphics.PixelFormat.TRANSLUCENT,
                        )
                        slp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
                        slp.alpha = 0.02f
                        wm(context).addView(speck, slp)
                        awake = speck
                    } catch (e: Exception) {}
                    activity.startActivity(
                        android.content.Intent(android.provider.Settings.ACTION_SETTINGS).addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK),
                    )
                    frontApp = "com.android.settings"
                    watcher.postDelayed({
                        val away = !foreground
                        measure(context, num("ms", 60000)) { told ->
                            val m = HashMap(told)
                            m["away"] = away
                            m["lensAway"] = view != null
                            try {
                                context.startActivity(
                                    android.content.Intent(context, MainActivity::class.java)
                                        .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
                                )
                            } catch (e: Exception) {}
                            watcher.postDelayed({
                                awake?.let { try { wm(context).removeView(it) } catch (e: Exception) {} }
                                awake = null
                                m["back"] = foreground
                                done(m)
                            }, 2500)
                        }
                    }, 4000)
                }
                else -> fail("unknown step")
            }
        } catch (e: Throwable) {
            fail("it threw: $e")
        }
    }

    private fun measure(context: Context, ms: Long, done: (Map<String, Any?>) -> Unit) {
        val bm = context.getSystemService(Context.BATTERY_SERVICE) as android.os.BatteryManager
        val readings = ArrayList<Int>()
        val cpu0 = android.os.Process.getElapsedCpuTime()
        val draws0 = draws
        val t0 = android.os.SystemClock.uptimeMillis()
        val tick = object : Runnable {
            override fun run() {
                readings.add(bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CURRENT_NOW))
                if (android.os.SystemClock.uptimeMillis() - t0 < ms) {
                    watcher.postDelayed(this, 1000)
                    return
                }
                val m = state(context)
                val sticky = try {
                    context.registerReceiver(null, android.content.IntentFilter(android.content.Intent.ACTION_BATTERY_CHANGED))
                } catch (e: Exception) { null }
                m["current"] = readings
                m["cpuMs"] = android.os.Process.getElapsedCpuTime() - cpu0
                m["lensDraws"] = draws - draws0
                m["ms"] = android.os.SystemClock.uptimeMillis() - t0
                m["plugged"] = ((sticky?.getIntExtra(android.os.BatteryManager.EXTRA_PLUGGED, 0) ?: 0) != 0)
                m["level"] = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                m["temp"] = (sticky?.getIntExtra(android.os.BatteryManager.EXTRA_TEMPERATURE, 0) ?: 0)
                m["bright"] = try { android.provider.Settings.System.getInt(context.contentResolver, android.provider.Settings.System.SCREEN_BRIGHTNESS) } catch (e: Exception) { -1 }
                done(m)
            }
        }
        watcher.postDelayed(tick, 1000)
    }

    // The buzz when a rest ends. It is planned when the rest is, for the moment it ends, and
    // given then whether or not a lens is on the screen. (It used to be given by the lens as it
    // drew itself: a lens closed on the cross, or switched off for where the person is, gave none.)
    private var buzzedFor = 0L
    private var buzzAt = 0L
    private var buzz: Runnable? = null

    fun planBuzz(context: Context) {
        buzz?.let { watcher.removeCallbacks(it) }
        buzz = null
        // (Only the timer gives the buzz: the blob is told of the rest too, and must not give a second.)
        if (!timer || !active || timerOff || pausedAt > 0 || endsAt <= 0) return
        val left = endsAt - System.currentTimeMillis()
        if (left <= 0) return
        val rest = endsAt
        val app = context.applicationContext
        val give = Runnable {
            if (active && !timerOff && pausedAt == 0L && endsAt == rest && buzzedFor != rest) {
                buzzedFor = rest
                buzzAt = System.currentTimeMillis()
                haptic(app, "thud")
            }
        }
        buzz = give
        watcher.postDelayed(give, left)
    }

    /**
     * A pinned thing's lens was tapped. Where the person is somewhere else, it takes them to
     * the thing. Where they already are (its app is the one in front, or its page is the one
     * showing) there is nowhere to take them: it opens the lens's menu, with everything else.
     * Should Prism be wrong about where they are, the tap that did nothing is followed by one
     * that opens the menu, and in the menu a tap on the lens itself goes to the thing.
     */
    private fun tapPinned(context: Context) {
        val p = pin ?: return
        val there = when (p.kind) {
            "app" -> !foreground && frontApp == p.pkg
            "screen" -> foreground && tab == p.index
            else -> false
        }
        if (there && container && blobs.isNotEmpty()) {
            haptic(context, "click")
            openMenu(context)
        } else {
            usePinned(context)
        }
    }

    /** Does what the pinned thing is, wherever the person is. */
    private fun usePinned(context: Context) {
        val p = pin ?: return
        if (p.kind == "app") {
            val i = context.packageManager.getLaunchIntentForPackage(p.pkg)
            if (i != null) {
                i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                // The lens stays where it is, over the app it has opened. From now that app is
                // the one in front, and a tap on the lens is for its menu.
                try {
                    context.startActivity(i)
                    frontApp = p.pkg
                } catch (e: Exception) {}
            } else {
                haptic(context, "thud")
            }
        } else if (p.kind == "screen") {
            openScreen(context, p.index)
        } else if (p.index == 1 || p.index == 3) {
            // Logging food and weighing in are done right here, over whatever is open.
            openSheet(context)
        } else {
            // No floating version of this one yet: it opens in Prism.
            openAction(context, p.index)
        }
    }

    /** Opens Prism at one of its own actions. */
    private fun openAction(context: Context, index: Int) {
        closeSheet(context)
        val i = android.content.Intent(context, MainActivity::class.java)
            .setAction(OPEN_ACTION)
            .putExtra("index", index)
            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK or android.content.Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
        try { context.startActivity(i) } catch (ex: Exception) {}
    }

    /** Opens Prism on one of its own pages. (Sent the same way as an action, numbered from a hundred.) */
    private fun openScreen(context: Context, index: Int) = openAction(context, 100 + index)

    /** Something changed: decide whether the lens should be there, and bring what is shown up to date. */
    fun refresh(context: Context) {
        // A lens is being closed on the cross: what should be there is settled when that is done.
        if (swallowing) return
        val want = mode() != 0 && seen() && android.provider.Settings.canDrawOverlays(context)
        if (!want) {
            remove(context)
            return
        }
        if (view == null) add(context)
        sheet?.sync()
        view?.invalidate()
        syncTray(context)
    }

    /** Prism's workout page came on screen or left it. Going to it brings back a lens that was closed. */
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
            // (The timer's has a place either side of the cross: to pause it, and to count up from nothing.)
            val wide = ((if (timer) 150 + 2 * SIDE else 150) * dp).toInt()
            val tlp = android.view.WindowManager.LayoutParams(
                wide, (150 * dp).toInt(),
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                    android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            tlp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            tlp.x = d.widthPixels / 2 - wide / 2
            tlp.y = d.heightPixels - (104 * dp).toInt() - (75 * dp).toInt()
            // Until a lens is picked up its window counts for nothing: a window that cannot be
            // touched but is not see-through makes Android refuse touches on the app under it.
            tlp.alpha = 0f
            t.lp = tlp
            t.alpha = 0f
            wm(context).addView(t, tlp)
            target = t

            val least = (84 * dp).toInt()
            // (A blob gives a tenth and no more; one kept larger from before comes back to that.)
            val most = if (timer) Math.max(least, minOf(d.widthPixels, d.heightPixels) - (16 * dp).toInt()) else (least * 1.1f).toInt()
            if (lensSize == 0) {
                // The size it was last given, kept from one day to the next.
                val saved = try { context.getSharedPreferences("prism_lens", Context.MODE_PRIVATE).getFloat(if (timer) "timerSize" else "size", 84f) } catch (e: Exception) { 84f }
                lensSize = (saved * dp).toInt()
            }
            lensSize = lensSize.coerceIn(least, most)
            val size = lensSize
            val lp = android.view.WindowManager.LayoutParams(
                size, size,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            // It goes exactly where it is put: Android adds no slide of its own.
            if (Build.VERSION.SDK_INT >= 34) lp.setCanPlayMoveAnimation(false)
            // Where it was last left, so it is in the same spot everywhere.
            if (!placed) tucked = false
            lp.x = if (placed) lensX else d.widthPixels - size - (8 * dp).toInt()
            // (The timer starts lower than the blob, so the two are never one on top of the other.)
            lp.y = if (placed) lensY else (d.heightPixels * (if (timer) 0.50f else 0.30f)).toInt()
            val v = Dot(context, lp)
            wm(context).addView(v, lp)
            view = v
            // It arrives with a short bounce: a little small, then just past its size and back.
            // It can be touched from the first moment; the bounce is only how it is drawn.
            // (Not one that is being put down from Prism: that one must be exactly where and as
            // large as the blob it takes over from.)
            if (!unseen) {
                v.scaleX = 0.8f
                v.scaleY = 0.8f
                v.animate().scaleX(1f).scaleY(1f).setDuration(190)
                    .setInterpolator(android.view.animation.OvershootInterpolator(1.7f)).start()
            }
            // A blob that came along with an app starts tucked at the side.
            if (tuckWhenShown) v.post { if (tuckWhenShown) { tuckWhenShown = false; v.tuckNow() } }
            listenForFront(context)
            // Tucked away, it has its handle along that edge.
            if (tucked) openGrip(context, lp.y)
        } catch (e: Exception) {
            view = null
        }
    }

    private fun remove(context: Context) {
        closeTray(context)
        removeMenu(context)
        closeReach(context)
        closeGrip(context)
        removeSheet(context)
        val t = target
        target = null
        if (t != null) try { wm(context).removeView(t) } catch (e: Exception) {}
        val r = frontListener
        frontListener = null
        if (r != null) try { context.applicationContext.unregisterReceiver(r) } catch (e: Exception) {}
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

    // Which sheet to open: the one that goes with what the lens shows, the workout's, or (0 and up) an action's.

    private fun openSheet(context: Context, what: Int = SHEET_AUTO) {
        if (sheet != null) return
        try {
            val d = context.resources.displayMetrics
            val dp = d.density
            val p = pin
            val host: Sheet = when {
                what >= 0 -> ActionSheet(context, what)
                what == SHEET_WORKOUT || mode() == 1 || p == null -> WorkoutSheet(context)
                else -> ActionSheet(context, p.index)
            }
            val lp = android.view.WindowManager.LayoutParams(
                minOf(d.widthPixels - (16 * dp).toInt(), (440 * dp).toInt()), android.view.WindowManager.LayoutParams.WRAP_CONTENT,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                // The sheet takes the focus while it is open, so that the back button is the sheet's
                // (it folds the sheet away) and does nothing to the app underneath. A touch outside
                // it still goes to that app, and still folds the sheet away.
                android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or android.view.WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            // Always at the bottom, wherever the lens is: that is where a thumb reaches.
            lp.gravity = android.view.Gravity.BOTTOM or android.view.Gravity.CENTER_HORIZONTAL
            lp.y = (14 * dp).toInt()
            // When it changes size it is simply the new size: Android adds no slide of its own.
            if (Build.VERSION.SDK_INT >= 34) lp.setCanPlayMoveAnimation(false)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // And to keep it clear of a keyboard: when one is up, the sheet sits on top of it.
                lp.fitInsetsTypes = android.view.WindowInsets.Type.systemBars() or android.view.WindowInsets.Type.ime()
            }
            wm(context).addView(host, lp)
            sheet = host
            val v = view
            if (v != null) {
                // The lens stays, and moves to the sheet's corner. Where it is on the screen and
                // where its window was asked to be can differ by a fixed amount; measure it once.
                if (v.roamingNow()) {
                    v.rest()
                } else {
                    val at = IntArray(2)
                    v.getLocationOnScreen(at)
                    // (Less what being pressed in has moved its corner by.)
                    lensOffX = at[0] - ((1f - v.scaleX) * v.width / 2f).toInt() - v.lp.x
                    lensOffY = at[1] - ((1f - v.scaleY) * v.height / 2f).toInt() - v.lp.y
                }
                homeX = v.lp.x
                homeY = v.lp.y
                dockX = -1
                dockY = -1
                docked = true
            }
            host.arrive()
        } catch (e: Exception) {
            sheet = null
        }
    }

    /** Folds the sheet away. The lens sets off for its own place at the same moment. */
    private fun closeSheet(context: Context) {
        val s = sheet ?: return
        undock()
        s.leave { if (sheet === s) removeSheet(context) }
    }

    /** The lens leaves the sheet's corner and goes back to where it was. */
    private fun undock() {
        val v = view
        if (docked && v != null) {
            docked = false
            v.glideTo(homeX.toFloat(), homeY.toFloat(), 300, lensSize)
        }
        docked = false
    }

    private fun removeSheet(context: Context) {
        val s = sheet ?: return
        sheet = null
        try { wm(context).removeView(s) } catch (e: Exception) {}
        undock()
    }

    /**
     * Puts the lens on the open sheet's top right corner, just above it. Called again whenever
     * the sheet may have moved or changed size; [ms] is how long the lens takes to get there.
     */
    private fun dock(context: Context, ms: Long = 300) {
        val v = view ?: return
        val s = sheet ?: return
        if (!docked || s.width == 0) return
        val dp = context.resources.displayMetrics.density
        val at = IntArray(2)
        s.getLocationOnScreen(at)
        // On the corner it is always its usual size, however large it has been made.
        val small = (84 * dp).toInt()
        val x = at[0] + s.width - small - (2 * dp).toInt() - lensOffX
        val y = at[1] + s.glassTop() - small - (2 * dp).toInt() - lensOffY
        if (Math.abs(x - dockX) < 2 && Math.abs(y - dockY) < 2) return
        dockX = x
        dockY = y
        v.glideTo(x.toFloat(), y.toFloat(), ms, small)
    }

    /**
     * The blob menu, opened by holding the lens when it is a container. These are the blobs
     * Prism's own button shows, shot out on the same spring, in the same fan, turned to face into
     * the screen from wherever the lens is. As in Prism: a tap on a blob uses it once and leaves
     * the lens as it is; a blob dragged out of its place and let go goes into the lens; a blob
     * held still is to be changed for something else, which is done in Prism.
     * A tap anywhere else, or the back button, closes the menu.
     */
    private inner class Menu(context: Context, val ox: Float, val oy: Float, val lensR: Float) : android.view.View(context) {
        private val dp = resources.displayMetrics.density
        private var items = blobs
        private val n = items.size
        // Where each blob is at rest now and where its seat is, and the lens's own middle, in this
        // view. The two differ only while the blobs are moving over: when one is dragged clear
        // of the others, they close ranks, as they do in Prism.
        private val restX = FloatArray(n)
        private val restY = FloatArray(n)
        private val seatX = FloatArray(n)
        private val seatY = FloatArray(n)
        private var axis = 0.0
        private var reach = 0f
        // The seat kept open among the others for the blob being carried: where it would sit if
        // let go now. None (-1) while it is clear of them, and then the others close ranks.
        private var room = -1
        private var cx = 0f
        private var cy = 0f
        private var laid = false
        // How far out each blob is (0 in the lens, 1 at rest) and how fast it is going.
        private val out = FloatArray(n)
        private val speed = FloatArray(n)
        private var dim = 0f
        private var dimSpeed = 0f
        private var opening = true
        private var born = 0L
        private var running = false
        private var last = 0L
        private var pressedAt = -1
        private var hot = -1
        private var downX = 0f
        private var downY = 0f
        private var moved = false
        private var kept = false
        // The blobs are being changed: each wears an edit mark, and a tap on one changes it.
        private var editing = false
        private val mark = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val pencil = android.graphics.Path()
        // A blob picked up and being dragged, and where the finger has it.
        private var dragging = -1
        private var dragX = 0f
        private var dragY = 0f
        private var flyFromX = 0f
        private var flyFromY = 0f
        // A blob on its way into the lens.
        private var flying = -1
        private var fly = 0f
        private var hadFocus = false
        private var back: Any? = null
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val hole = android.graphics.Path()
        private val thread = android.graphics.Path()
        private val names = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)

        init {
            names.color = WHITE
            names.textAlign = android.graphics.Paint.Align.CENTER
            names.textSize = 13.5f * dp
            // Prism's own lettering, at the weight the menu in Prism uses.
            try {
                names.typeface = android.graphics.Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Inter.ttf")
                if (Build.VERSION.SDK_INT >= 26) names.fontVariationSettings = "'wght' 650"
            } catch (e: Exception) {
                names.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            }
            // Over another app there is no telling what is behind the names.
            names.setShadowLayer(5 * dp, 0f, 1 * dp, 0x99000000.toInt())
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            isFocusableInTouchMode = true
            requestFocus()
            if (Build.VERSION.SDK_INT >= 33) {
                val callback = android.window.OnBackInvokedCallback { backPressed() }
                back = callback
                findOnBackInvokedDispatcher()?.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback)
            }
        }

        /** Back first ends the changing, then closes the blobs. */
        private fun backPressed() {
            if (editing) {
                editing = false
                haptic(context, "tick")
                invalidate()
            } else {
                close()
            }
        }

        override fun onDetachedFromWindow() {
            if (Build.VERSION.SDK_INT >= 33) {
                val callback = back as? android.window.OnBackInvokedCallback
                if (callback != null) findOnBackInvokedDispatcher()?.unregisterOnBackInvokedCallback(callback)
            }
            removeCallbacks(keep)
            running = false
            super.onDetachedFromWindow()
        }

        override fun dispatchKeyEvent(e: android.view.KeyEvent): Boolean {
            if (e.keyCode == android.view.KeyEvent.KEYCODE_BACK) {
                if (e.action == android.view.KeyEvent.ACTION_UP) backPressed()
                return true
            }
            return super.dispatchKeyEvent(e)
        }

        // Something else came to the front (the home screen, the notification shade): the menu goes.
        override fun onWindowFocusChanged(has: Boolean) {
            super.onWindowFocusChanged(has)
            if (has) hadFocus = true else if (hadFocus) close()
        }

        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            val at = IntArray(2)
            getLocationOnScreen(at)
            cx = ox - at[0]
            cy = oy - at[1]
            if (!laid) {
                fan()
                laid = true
                born = android.os.SystemClock.uptimeMillis()
                run()
            }
        }

        /** The direction a seat lies in, for a fan whose middle points along [axis]: Prism's own fan, turned. Seats are counted in places from the middle. */
        private fun angle(axis: Double, seat: Float): Double = axis + Math.PI * seat * step()

        /**
         * How far apart, round the fan, one seat is from the next. With the names switched off
         * the blobs sit nearer, and are spread wider by as much, so that the gap between one and
         * the next stays what it is with names. As in Prism.
         */
        private fun step(): Double =
            if (blobNames || reach <= 0f) 0.155 else (0.155 * 178.0 * dp / reach).coerceIn(0.155, 0.1769)

        /**
         * Lays the fan out. It points straight into the screen from the side the lens is on, and
         * turns up or down only as far as it must for every blob and its name to be on the screen.
         */
        private fun fan() {
            val w = width.toFloat()
            val h = height.toFloat()
            reach = if (blobNames) Math.max(178 * dp, lensR + 75 * dp) else Math.max(156 * dp, lensR + 58 * dp)
            val left = 45 * dp
            val right = Math.max(left, w - 45 * dp)
            val top = 78 * dp
            val bottom = Math.max(top, h - 100 * dp)
            val onRight = cx > w / 2f
            val inward = if (onRight) Math.PI else 0.0
            // Which way the fan turns to point further down the screen, and which way to try first.
            val down = if (onRight) -1.0 else 1.0
            val first = if (cy < h / 2f) down else -down
            var best = inward
            var least = Float.MAX_VALUE
            search@ for (j in 0..11) {
                for (way in doubleArrayOf(first, -first)) {
                    val turned = inward + way * j * Math.toRadians(8.0)
                    var over = 0f
                    for (i in 0 until n) {
                        val a = angle(turned, i - (n - 1) / 2f)
                        val x = cx + reach * Math.cos(a).toFloat()
                        val y = cy + reach * Math.sin(a).toFloat()
                        over += Math.max(0f, left - x) + Math.max(0f, x - right) + Math.max(0f, top - y) + Math.max(0f, y - bottom)
                    }
                    if (over < least) {
                        least = over
                        best = turned
                    }
                    if (over == 0f) break@search
                    if (j == 0) break
                }
            }
            axis = best
            seats(-1)
            for (i in 0 until n) {
                restX[i] = seatX[i]
                restY[i] = seatY[i]
            }
        }

        /**
         * Gives every blob but [without] its seat: the ones left sit evenly around the middle of
         * the fan, with the seat [open] among them left empty if there is one.
         */
        private fun seats(without: Int, open: Int = -1) {
            val left = 45 * dp
            val right = Math.max(left, width - 45 * dp)
            val top = 78 * dp
            val bottom = Math.max(top, height - 100 * dp)
            val count = (if (without in 0 until n) n - 1 else n) + (if (open >= 0) 1 else 0)
            var j = 0
            for (i in 0 until n) {
                if (i == without) continue
                val a = angle(axis, (if (open >= 0 && j >= open) j + 1 else j) - (count - 1) / 2f)
                seatX[i] = (cx + reach * Math.cos(a).toFloat()).coerceIn(left, right)
                seatY[i] = (cy + reach * Math.sin(a).toFloat()).coerceIn(top, bottom)
                j++
            }
        }

        /**
         * Which seat a blob carried to this place would take among the others, or none (-1) if
         * the place is not among them. [now] is the seat it has at the moment: it keeps that one
         * until it is clearly over another. The same rule as in Prism.
         */
        private fun seatFor(x: Float, y: Float, now: Int): Int {
            val vx = x - cx
            val vy = y - cy
            val d = Math.hypot(vx.toDouble(), vy.toDouble()).toFloat()
            val slack = if (now >= 0) 14 * dp else 0f
            if (d < reach - 58 * dp - slack || d > reach + 62 * dp + slack) return -1
            var turn = Math.atan2(vy.toDouble(), vx.toDouble()) - axis
            while (turn > Math.PI) turn -= 2 * Math.PI
            while (turn < -Math.PI) turn += 2 * Math.PI
            val seat = (turn / (Math.PI * step())).toFloat()
            if (Math.abs(seat) > (n - 1) / 2f + 0.75f + (if (now >= 0) 0.1f else 0f)) return -1
            val place = seat + (n - 1) / 2f
            if (now >= 0 && Math.abs(place - now) < 0.62f) return now
            return Math.round(place).coerceIn(0, n - 1)
        }

        /**
         * Blob [d] was let go among the others, in seat [g]: it sits there. If that is not the
         * seat it had, the order changes, here at once and in Prism, where it is kept.
         */
        private fun settle(d: Int, g: Int) {
            var at = d
            if (g != d && items.all { it.slot >= 0 }) {
                val order = (0 until n).filter { it != d }.toMutableList()
                order.add(g.coerceIn(0, order.size), d)
                // The places these blobs are in, as Prism knows them, are handed out again in the new order.
                val places = items.map { it.slot }.sorted()
                val next = order.mapIndexed { j, k -> items[k].inPlace(places[j]) }
                val rx = FloatArray(n) { restX[order[it]] }
                val ry = FloatArray(n) { restY[order[it]] }
                val o = FloatArray(n) { out[order[it]] }
                val sp = FloatArray(n) { speed[order[it]] }
                for (i in 0 until n) {
                    restX[i] = rx[i]; restY[i] = ry[i]; out[i] = o[i]; speed[i] = sp[i]
                }
                channel?.invokeMethod("blobOrder", order.map { items[it].slot })
                items = next
                blobs = next
                at = order.indexOf(d)
                haptic(context, "click")
            } else {
                haptic(context, "tick")
            }
            // It goes from where it was let go to its seat.
            restX[at] = dragX
            restY[at] = dragY
            seats(-1)
            run()
        }

        private fun run() {
            if (running) return
            running = true
            last = 0L
            android.view.Choreographer.getInstance().postFrameCallback(frame)
        }

        // The same springs as the menu in Prism: out on a quick one with a little give, each blob
        // a moment after the one before; back in on a firm one, all together.
        private val frame = object : android.view.Choreographer.FrameCallback {
            override fun doFrame(nanos: Long) {
                if (!running || !isAttachedToWindow) {
                    running = false
                    return
                }
                val dt = if (last == 0L) 1f / 120f else ((nanos - last) / 1e9f).coerceIn(0.001f, 0.034f)
                last = nanos
                val since = android.os.SystemClock.uptimeMillis() - born
                val steps = Math.ceil((dt / 0.005f).toDouble()).toInt().coerceAtLeast(1)
                val h = dt / steps
                val to = if (opening) 1f else 0f
                val k = if (opening) 1150f else 1400f
                val c = if (opening) 40.7f else 67.3f
                for (step in 0 until steps) {
                    for (i in 0 until n) {
                        if (i == flying || (opening && since < i * 18L)) continue
                        speed[i] += (-k * (out[i] - to) - c * speed[i]) * h
                        out[i] += speed[i] * h
                    }
                    dimSpeed += (-1400f * (dim - to) - 67.3f * dimSpeed) * h
                    dim += dimSpeed * h
                }
                var moving = flying >= 0 || Math.abs(dim - to) > 0.004f
                // The blobs move over to their seats.
                val ease = 1f - Math.exp(-22.0 * dt).toFloat()
                for (i in 0 until n) {
                    val dx = seatX[i] - restX[i]
                    val dy = seatY[i] - restY[i]
                    if (Math.abs(dx) > 0.5f || Math.abs(dy) > 0.5f) {
                        restX[i] += dx * ease
                        restY[i] += dy * ease
                        moving = true
                    } else {
                        restX[i] = seatX[i]
                        restY[i] = seatY[i]
                    }
                }
                for (i in 0 until n) {
                    if (i == flying) continue
                    if (opening && since < i * 18L) moving = true
                    if (Math.abs(out[i] - to) > 0.002f || Math.abs(speed[i]) > 0.02f) moving = true
                }
                if (!opening && flying < 0) {
                    // Closing: once everything is back in and the dim is gone, the menu is gone.
                    var gone = dim < 0.03f
                    for (i in 0 until n) if (out[i] > 0.03f) gone = false
                    if (gone) {
                        running = false
                        removeMenu(context)
                        return
                    }
                    moving = true
                }
                invalidate()
                if (moving) android.view.Choreographer.getInstance().postFrameCallback(this) else running = false
            }
        }

        /** For the long test: where a blob sits in this view, how many there are, and what state the menu is in. */
        fun testSpot(i: Int): FloatArray = floatArrayOf(restX[i.coerceIn(0, n - 1)], restY[i.coerceIn(0, n - 1)])
        fun testCount() = n
        fun testEditing() = editing
        fun testBack() = backPressed()
        fun testKey(i: Int): String = items[i.coerceIn(0, n - 1)].key
        fun testMiddle(): FloatArray = floatArrayOf(cx, cy)

        override fun onDraw(canvas: android.graphics.Canvas) {
            if (!laid) return
            drawn()
            // The dim, as behind the blobs in Prism, with the lens showing through it untouched.
            val shade = (0.46f * dim.coerceIn(0f, 1f) * 255).toInt()
            if (shade > 0) {
                hole.reset()
                hole.fillType = android.graphics.Path.FillType.EVEN_ODD
                hole.addRect(0f, 0f, width.toFloat(), height.toFloat(), android.graphics.Path.Direction.CW)
                hole.addCircle(cx, cy, lensR + 1 * dp, android.graphics.Path.Direction.CW)
                paint.shader = null
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = shade shl 24
                canvas.drawPath(hole, paint)
            }
            // The threads: each blob stays tied to the lens until it arrives. Only on the way out.
            if (opening) {
                for (i in 0 until n) {
                    val p = out[i]
                    if (p <= 0.02f || p >= 0.97f) continue
                    val bx = cx + (restX[i] - cx) * p
                    val by = cy + (restY[i] - cy) * p
                    val dx = bx - cx
                    val dy = by - cy
                    val len = Math.hypot(dx.toDouble(), dy.toDouble()).toFloat()
                    if (len < 1f) continue
                    val nx = -dy / len
                    val ny = dx / len
                    // Thick at the lens, thin at the blob.
                    val thick = (1.5f + 9f * (1 - p)) * dp / 2f
                    val thin = 0.9f * dp / 2f
                    thread.reset()
                    thread.moveTo(cx + nx * thick, cy + ny * thick)
                    thread.lineTo(bx + nx * thin, by + ny * thin)
                    thread.lineTo(bx - nx * thin, by - ny * thin)
                    thread.lineTo(cx - nx * thick, cy - ny * thick)
                    thread.close()
                    paint.color = items[i].color
                    canvas.save()
                    // Not over the lens itself.
                    canvas.clipPath(hole)
                    canvas.drawPath(thread, paint)
                    canvas.restore()
                }
            }
            for (i in 0 until n) {
                val p = out[i]
                if (p <= 0.02f && i != flying) continue
                var bx = cx + (restX[i] - cx) * p
                var by = cy + (restY[i] - cy) * p
                // It starts as a speck and swells on the way, stretched along its travel while it is fast.
                val reached = p.coerceIn(0f, 1f)
                var size = 0.14f + 0.86f * Math.pow(reached.toDouble(), 1.5).toFloat() + (if (p > 1f) (p - 1f) * 0.35f else 0f)
                var stretch = (Math.abs(speed[i]) * 0.04f).coerceIn(0f, 0.46f)
                var alpha = (p * 12f).coerceIn(0f, 1f)
                if (i == dragging) {
                    // Picked up: it is where the finger has it.
                    bx = dragX
                    by = dragY
                    size = 1.08f
                    stretch = 0f
                } else if (i == flying) {
                    // Let go: it goes into the lens, coming down to the size it has in there.
                    val f = EASE.getInterpolation(fly)
                    bx = flyFromX + (cx - flyFromX) * f
                    by = flyFromY + (cy - flyFromY) * f
                    size = 1f + (22.5f / 31f - 1f) * f
                    stretch = 0f
                    alpha = 1f
                } else if (i == pressedAt) {
                    size *= 0.94f
                } else if (i == hot) {
                    size *= 1.1f
                }
                val turn = Math.toDegrees(Math.atan2((restY[i] - cy).toDouble(), (restX[i] - cx).toDouble())).toFloat()
                canvas.save()
                canvas.translate(bx, by)
                canvas.rotate(turn)
                canvas.scale(size * (1 + stretch), size * (1 - stretch * 0.5f))
                canvas.rotate(-turn)
                paintBlob(canvas, items[i], 0f, 0f, 31 * dp, dp, true, (alpha * 255).toInt())
                if (editing) {
                    // The edit mark: a small white disc with a pencil, at the blob's upper right.
                    // The same size and place as the marks in Prism.
                    val mx = 21 * dp
                    val my = -21 * dp
                    val a = (alpha * 255).toInt().coerceIn(0, 255)
                    mark.style = android.graphics.Paint.Style.FILL
                    mark.color = 0x000000 or (a * 85 / 255 shl 24)
                    canvas.drawCircle(mx, my + 1.5f * dp, 14.5f * dp, mark)
                    mark.color = 0xFFFFFF or (a shl 24)
                    canvas.drawCircle(mx, my, 14 * dp, mark)
                    mark.color = 0x15171C or (a shl 24)
                    canvas.save()
                    canvas.translate(mx, my)
                    canvas.rotate(45f)
                    canvas.scale(1.2f, 1.2f)
                    pencil.rewind()
                    pencil.addRect(-1.9f * dp, -6 * dp, 1.9f * dp, 2.6f * dp, android.graphics.Path.Direction.CW)
                    pencil.moveTo(-1.9f * dp, 3.6f * dp)
                    pencil.lineTo(1.9f * dp, 3.6f * dp)
                    pencil.lineTo(0f, 6.6f * dp)
                    pencil.close()
                    canvas.drawPath(pencil, mark)
                    canvas.restore()
                }
                canvas.restore()
                // Once it is out: how many notifications it has. Not while the blobs are being changed.
                if (!editing && p >= 0.9f && i != flying && i != dragging) paintBadge(canvas, items[i], bx + 22 * dp, by - 22 * dp, dp)
                // The name appears once the blob is nearly there, not while it is a speck.
                val show = if (i == dragging) 0f else if (i == flying) 1f - fly * 3f else (p - 0.6f) / 0.4f
                if (show > 0f && blobNames) {
                    names.alpha = (show.coerceIn(0f, 1f) * 255).toInt()
                    canvas.drawText(items[i].name, bx, by + 50 * dp, names)
                }
            }
        }

        /** Which blob is at this place in the view, or none. A blob's name counts as the blob. */
        private fun at(x: Float, y: Float): Int {
            for (i in 0 until n) {
                if (out[i] < 0.5f) continue
                val dx = x - restX[i]
                val dy = y - restY[i]
                if (dx * dx + dy * dy < (40 * dp) * (40 * dp)) return i
                if (blobNames && Math.abs(dx) < 40 * dp && dy > 0 && dy < 62 * dp) return i
            }
            return -1
        }

        // Held still on any blob: all of them can now be changed, and each wears an edit mark.
        // The blob stays under the finger: moved from here without letting go, it comes along.
        private val keep = Runnable {
            val i = pressedAt
            if (i >= 0 && !kept && opening) {
                kept = true
                if (!editing) {
                    editing = true
                    haptic(context, "click")
                    invalidate()
                }
            }
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            if (!opening || flying >= 0) return true
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    downX = e.x; downY = e.y
                    kept = false
                    moved = false
                    dragging = -1
                    pressedAt = at(e.x, e.y)
                    if (pressedAt >= 0) postDelayed(keep, android.view.ViewConfiguration.getLongPressTimeout().toLong().coerceIn(300L, 600L))
                    invalidate()
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    if (!moved && Math.hypot((e.x - downX).toDouble(), (e.y - downY).toDouble()) > 14 * dp) {
                        // Moved: neither a tap nor a hold. If it began on a blob, the blob comes along.
                        moved = true
                        removeCallbacks(keep)
                        if (pressedAt >= 0) {
                            dragging = pressedAt
                            // Picked up, its own seat is kept open for it.
                            room = dragging
                            haptic(context, "tick")
                        }
                        pressedAt = -1
                    }
                    if (dragging >= 0) {
                        dragX = seatX[dragging] + (e.x - downX)
                        dragY = seatY[dragging] + (e.y - downY)
                        // Over the others they make room where it would sit; clear of them, they close ranks.
                        // While the blobs are being changed a drag only puts them in another order:
                        // the seat last made for it stays open wherever the finger goes.
                        val found = seatFor(dragX, dragY, room)
                        val g = if (found < 0 && editing) room else found
                        if (g != room) {
                            room = g
                            seats(dragging, g)
                            haptic(context, "tick")
                            run()
                        }
                    }
                    invalidate()
                }
                android.view.MotionEvent.ACTION_UP -> {
                    removeCallbacks(keep)
                    val i = pressedAt
                    val d = dragging
                    pressedAt = -1
                    dragging = -1
                    if (d >= 0) {
                        // Let go among the others, it sits in the seat they made for it. Let go clear of them, it goes into the lens.
                        val g = room
                        room = -1
                        // (While they are being changed it never goes into the lens: it sits in the seat kept for it.)
                        if (g < 0 && !editing) put(d, dragX, dragY) else settle(d, if (g < 0) d else g)
                    } else if (kept) {
                        // Already being changed, by the hold.
                    } else if (i >= 0) {
                        if (editing) change(i) else choose(i)
                    } else if (!moved) {
                        // A tap beside the blobs closes the menu. A tap on the lens itself, in
                        // the middle of its own menu, closes it and goes to what is in the lens.
                        val onLens = mode() == 2 && Math.hypot((downX - cx).toDouble(), (downY - cy).toDouble()) < lensR + 6 * dp
                        val c = context
                        close()
                        if (onLens) watcher.postDelayed({ usePinned(c) }, 110)
                    }
                    invalidate()
                }
                android.view.MotionEvent.ACTION_CANCEL -> {
                    removeCallbacks(keep)
                    pressedAt = -1
                    dragging = -1
                    room = -1
                    seats(-1)
                    run()
                    invalidate()
                }
            }
            return true
        }

        /** The finger that opened the menu is still down and sliding: the blob under it swells. Places are on the screen. */
        fun hover(sx: Float, sy: Float) {
            if (!opening || flying >= 0) return
            val here = IntArray(2)
            getLocationOnScreen(here)
            val i = if (sx < 0f) -1 else at(sx - here[0], sy - here[1])
            if (i != hot) {
                hot = i
                if (i >= 0) haptic(context, "tick")
                invalidate()
            }
        }

        /** That finger let go: over a blob, the blob is used; anywhere else the menu stays open for a tap. */
        fun release(sx: Float, sy: Float) {
            hover(sx, sy)
            val i = hot
            hot = -1
            if (i >= 0) choose(i) else invalidate()
        }

        /** Tapped: it is done once. The lens stays as it is. */
        private fun choose(i: Int) {
            haptic(context, "tick")
            val b = items[i]
            val c = context
            close()
            // Once the blobs are on their way back in.
            watcher.postDelayed({ use(c, b) }, 110)
        }

        /** Tapped while the blobs are being changed: Prism comes to the front with its apps to choose from. */
        private fun change(i: Int) {
            val c = context
            haptic(c, "click")
            val slot = if (items[i].slot >= 0) items[i].slot else i
            close()
            openPrism(c)
            // Once Prism is in front.
            watcher.postDelayed({ channel?.invokeMethod("editSlot", slot) }, 220)
        }

        /** Dragged out of its place and let go, at this spot: it goes into the lens. */
        private fun put(i: Int, fromX: Float, fromY: Float) {
            val b = items[i]
            val c = context
            haptic(c, "thud")
            flyFromX = fromX
            flyFromY = fromY
            flying = i
            fly = 0f
            opening = false
            val lens = view
            lens?.hideInner = true
            // Put there by hand: it is the person's own now, not a guest.
            guest = false
            own = null
            pin = b
            channel?.invokeMethod("pinned", b.key)
            lens?.invalidate()
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = 280
            a.interpolator = android.view.animation.LinearInterpolator()
            a.addUpdateListener {
                fly = it.animatedValue as Float
                invalidate()
            }
            a.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    // It has arrived: from here the lens draws it, and gives a little as it catches it.
                    view?.hideInner = false
                    view?.invalidate()
                    view?.thump()
                    flying = -1
                    out[i] = 0f
                    speed[i] = 0f
                    refresh(c)
                    run()
                }
            })
            a.start()
            run()
        }

        fun close() {
            if (!opening) return
            opening = false
            removeCallbacks(keep)
            pressedAt = -1
            hot = -1
            invalidate()
            run()
        }
    }

    /**
     * While a finger is on the lens, the rest of the screen listens for a second one, so that two
     * fingers can resize the lens wherever the second one lands. It is there only for as long as
     * the lens is being touched, and it shows nothing.
     */
    private inner class Reach(context: Context) : android.view.View(context) {
        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            view?.reach(e)
            return true
        }
    }

    /**
     * The handle of a lens tucked into a side: a strip along that edge, wider than the sliver
     * that shows and wider than the phone's own swipe-in-from-the-edge zone. It shows nothing. A
     * touch on it is a touch on the lens. It is there only while the lens is tucked.
     */
    private inner class Grip(context: Context) : android.view.View(context) {
        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            // A touch here is for the lens and is not a "back".
            if (Build.VERSION.SDK_INT >= 29) systemGestureExclusionRects = listOf(android.graphics.Rect(0, 0, w, h))
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            view?.onTouchEvent(e)
            return true
        }
    }

    /** Puts the handle beside the tucked lens, whose top is at [y]. */
    private fun openGrip(context: Context, y: Int) {
        val v = view ?: return
        closeGrip(context)
        try {
            val d = context.resources.displayMetrics
            val dp = d.density
            val wide = (76 * dp).toInt()
            val lp = android.view.WindowManager.LayoutParams(
                wide, v.ownSize() + (16 * dp).toInt(),
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            lp.gravity = android.view.Gravity.TOP or android.view.Gravity.START
            lp.x = if (tuckRight) d.widthPixels - wide else 0
            lp.y = y - (8 * dp).toInt()
            val g = Grip(context)
            wm(context).addView(g, lp)
            grip = g
        } catch (e: Exception) {
            grip = null
        }
    }

    private fun closeGrip(context: Context) {
        val g = grip ?: return
        grip = null
        try { wm(context).removeView(g) } catch (e: Exception) {}
    }

    private fun openReach(context: Context) {
        if (reach != null) return
        try {
            val r = Reach(context)
            val lp = android.view.WindowManager.LayoutParams(
                android.view.WindowManager.LayoutParams.MATCH_PARENT, android.view.WindowManager.LayoutParams.MATCH_PARENT,
                android.view.WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                android.view.WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or android.view.WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                    android.view.WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or android.view.WindowManager.LayoutParams.FLAG_SPLIT_TOUCH,
                android.graphics.PixelFormat.TRANSLUCENT,
            )
            wm(context).addView(r, lp)
            reach = r
        } catch (e: Exception) {
            reach = null
        }
    }

    private fun closeReach(context: Context) {
        val r = reach ?: return
        reach = null
        try { wm(context).removeView(r) } catch (e: Exception) {}
    }

    // How everything here moves: quickly at first, then slowing into its place. Nothing goes
    // past its place and comes back.
    private val EASE = android.view.animation.PathInterpolator(0.2f, 0f, 0f, 1f)

    private fun smooth(x: Float): Float {
        val t = x.coerceIn(0f, 1f)
        return t * t * (3f - 2f * t)
    }

    /** What the timer shows, the same for the lens and for the sheet. */
    private class Reading(
        val text: String, val part: Float, val resting: Boolean, val go: Boolean, val urgent: Boolean, val what: String,
        val paused: Boolean = false, val off: Boolean = false,
    )

    /** The moment the timer is read at: now, or, while it is paused, the moment it was paused. */
    private fun timerNow(wall: Long): Long = if (pausedAt > 0) pausedAt else wall

    private fun reading(wall: Long): Reading {
        // Switched off, there is no time to show: it says which set this is.
        if (timerOff) return Reading(short, -1f, false, false, false, "TIMER OFF", off = true)
        val paused = pausedAt > 0
        val now = timerNow(wall)
        val left = endsAt - now
        val resting = left > 0
        val go = endsAt > 0 && !resting && now - endsAt < 3000 && !paused
        val since = now - sinceAt
        if (go) return Reading("GO", 1f, false, true, false, "REST IS OVER")
        if (resting) {
            val gone = (total * 1000L - left).coerceAtLeast(0)
            return if (countUp) {
                Reading(clock(gone), (gone / (total * 1000f)).coerceIn(0f, 1f), true, false, left <= 10000 && !paused, if (paused) "PAUSED" else "RESTING", paused)
            } else {
                Reading(clock(left + 999), (left / (total * 1000f)).coerceIn(0f, 1f), true, false, left <= 10000 && !paused, if (paused) "PAUSED" else "REST LEFT", paused)
            }
        }
        return Reading(clock(since), -1f, false, false, false, if (paused) "PAUSED" else "SINCE LAST SET", paused)
    }

    /**
     * How long, in thousandths of a second, until the timer next needs drawing. While a rest
     * runs that is when the ring's head has moved about a pixel ([ring] is how far round the
     * ring is, in pixels) or the number changes, whichever comes first: on a 90 second rest in
     * the lens at its usual size that is about six times a second, where it used to be drawn
     * fifteen times a second whether anything had moved or not. Between sets it is the next
     * whole second, so the number changes on time and nothing is drawn in between.
     */
    private fun beat(wall: Long, t: Reading, ring: Float): Long {
        if (t.go) return 250L
        val now = timerNow(wall)
        if (t.resting) {
            val left = (endsAt - now).coerceAtLeast(0L)
            val gone = (total * 1000L - left).coerceAtLeast(0L)
            val toNumber = if (countUp) 1000L - gone % 1000L else left % 1000L
            val aPixel = if (ring > 1f && total > 0) (total * 1000f / ring).toLong() else 1000L
            return Math.min(toNumber + 4L, aPixel).coerceIn(66L, 1000L)
        }
        val since = (now - sinceAt).coerceAtLeast(0L)
        return (1000L - since % 1000L + 4L).coerceIn(66L, 1000L)
    }

    /** Two short bars: the timer is paused. */
    private fun pauseMark(canvas: android.graphics.Canvas, paint: android.graphics.Paint, cx: Float, cy: Float, h: Float, color: Int) {
        paint.style = android.graphics.Paint.Style.FILL
        paint.color = color
        val w = h * 0.34f
        canvas.drawRoundRect(cx - w * 1.6f, cy - h / 2, cx - w * 0.6f, cy + h / 2, w / 2, w / 2, paint)
        canvas.drawRoundRect(cx + w * 0.6f, cy - h / 2, cx + w * 1.6f, cy + h / 2, w / 2, w / 2, paint)
    }

    /**
     * The cross at the bottom of the screen that a lens is dropped on to close it. When the
     * lens falls in, the cross takes its colour for a moment, gives once, and sinks out of sight.
     * Its window counts for nothing except while a lens is being carried.
     */
    private inner class Target(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val dp = resources.displayMetrics.density
        private val mix = android.animation.ArgbEvaluator()
        private var gulp = -1f
        private var taken = 0
        var lp: android.view.WindowManager.LayoutParams? = null
        private var up = false

        // Which place the lens is over: 0 the cross, 1 pause, 2 count up. Only the cross swells
        // to take the lens in; the other two light up.
        var which = 0
        var held = false
            set(v) {
                if (field != v) {
                    field = v
                    val grow = v && which == 0
                    animate().scaleX(if (grow) 1.22f else 1f).scaleY(if (grow) 1.22f else 1f).setDuration(160).setInterpolator(EASE).start()
                    invalidate()
                }
            }

        private fun window(alpha: Float) {
            val l = lp ?: return
            if (l.alpha == alpha) return
            l.alpha = alpha
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, l) } catch (e: Exception) {}
        }

        /** A lens has been picked up: the cross shows. */
        fun rise() {
            if (!up) {
                up = true
                gulp = -1f
                translationY = 0f
                window(1f)
            }
            animate().alpha(1f).setDuration(160).start()
        }

        /** The lens was let go somewhere else: the cross goes, and its window counts for nothing again. */
        fun fall() {
            if (!up) return
            animate().alpha(0f).setDuration(180).withEndAction { rest() }.start()
        }

        private fun rest() {
            up = false
            window(0f)
        }

        /** A lens was dropped on it: it takes the lens's colour for a moment, settles, and sinks away. Short. */
        fun swallow(color: Int, done: () -> Unit) {
            taken = color
            animate().cancel()
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = 380
            a.interpolator = android.view.animation.LinearInterpolator()
            a.addUpdateListener {
                val t = it.animatedValue as Float
                gulp = t
                // It was swollen to hold the lens; it comes back to its own size, with one small give.
                val base = 1.22f - 0.22f * EASE.getInterpolation(Math.min(1f, t / 0.5f))
                val w = 0.07f * Math.exp(-6.0 * t).toFloat() * Math.cos(2 * Math.PI * 2.4 * t).toFloat()
                scaleX = base * (1 + w)
                scaleY = base * (1 - w)
                // Then it sinks a little way and is gone.
                val s = ((t - 0.5f) / 0.5f).coerceIn(0f, 1f)
                translationY = s * s * 36 * dp
                alpha = 1f - s
                invalidate()
            }
            a.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    rest()
                    done()
                }
            })
            a.start()
        }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val c = width / 2f
            val cy = height / 2f
            // The small timer has a place either side of the cross. (Not while the cross is swallowing.)
            if (timer && !big(context) && gulp < 0f) {
                for (k in 1..2) {
                    val x = c + (if (k == 1) -SIDE else SIDE) * dp
                    val on = held && which == k
                    val r2 = (if (on) 36 else 32) * dp
                    paint.style = android.graphics.Paint.Style.FILL
                    paint.color = if (on) 0xE6181A20.toInt() else 0xCC101216.toInt()
                    canvas.drawCircle(x, cy, r2, paint)
                    paint.style = android.graphics.Paint.Style.STROKE
                    paint.strokeWidth = (if (on) 2.2f else 1.4f) * dp
                    paint.color = if (on) accent else 0x66FFFFFF
                    canvas.drawCircle(x, cy, r2 - paint.strokeWidth / 2, paint)
                    paintSign(canvas, k, x, cy, dp, paint)
                }
            }
            val r = 40 * dp
            val held = this.held && which == 0
            val dark = if (held) 0xE6181A20.toInt() else 0xCC101216.toInt()
            // While swallowing, the colour of what fell in shows through and then fades.
            val colour = if (gulp >= 0f) (Math.max(0f, 1f - gulp / 0.6f)) else 0f
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = if (colour > 0f) mix.evaluate(colour, dark, tint(taken, 0xF0)) as Int else dark
            canvas.drawCircle(c, cy, r, paint)
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = (if (held) 2.2f else 1.4f) * dp
            paint.color = if (held || gulp >= 0f) accent else 0x66FFFFFF
            canvas.drawCircle(c, cy, r - paint.strokeWidth / 2, paint)
            // The cross closes as it swallows.
            val a = 9 * dp * (if (gulp >= 0f) Math.max(0f, 1f - gulp / 0.25f) else 1f)
            if (a > 0.5f) {
                paint.strokeWidth = 2.6f * dp
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = WHITE
                canvas.drawLine(c - a, cy - a, c + a, cy + a, paint)
                canvas.drawLine(c - a, cy + a, c + a, cy - a, paint)
            }
        }
    }

    /**
     * The lens: a see-through tinted disc (what is underneath shows through it), a rim lit from
     * above and a soft highlight across the top. During a workout it carries the timer.
     *
     * As a container it is always that same glass in Prism's colour, and what was put in it sits
     * inside as its blob, smaller, with the glass around it; held, it opens the blob menu. As it
     * was before, it takes the pinned thing's colour and shows its picture.
     */
    private inner class Dot(context: Context, val lp: android.view.WindowManager.LayoutParams) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val arc = android.graphics.RectF()
        private val dst = android.graphics.RectF()
        private val clip = android.graphics.Path()
        private val round = android.graphics.Path()
        private var body: android.graphics.Shader? = null
        private var bodyDone: android.graphics.Shader? = null
        private var rim: android.graphics.Shader? = null
        private var shine: android.graphics.Shader? = null
        private var glow: android.graphics.Shader? = null
        private var shadow: android.graphics.Shader? = null
        private var shadersFor = 0
        private var shadersPinned = false
        private var downX = 0f; private var downY = 0f; private var startX = 0; private var startY = 0
        private var dragged = false
        private var snapped = false

        // Which of the places at the foot it is snapped to: 0 the cross, 1 pause, 2 count up.
        // Only the small timer has the other two.
        private var spot = 0

        /** Whether it is in the hand or on its way somewhere. */
        fun busy() = pressed || springing || roaming || glide?.isRunning == true
        // The rest whose end the lens has swelled for.
        private var swelledFor = 0L
        private val dp = resources.displayMetrics.density
        private var tracker: android.view.VelocityTracker? = null
        // The springs that carry it to rest after a throw.
        private var px = 0f; private var py = 0f; private var vx = 0f; private var vy = 0f
        private var tx = 0f; private var ty = 0f
        private var springing = false
        private var lastFrame = 0L
        private var leaving = false
        private var glide: android.animation.ValueAnimator? = null
        private var wouldTuck = false
        // Pulled out of a side, it comes under the finger over a moment while it follows: how far
        // it has to come, and how much of that it has covered.
        private var catchX = 0f; private var catchY = 0f; private var catchUp = 0f
        private var catching: android.animation.ValueAnimator? = null
        // The rest of this touch is not for the lens.
        private var ignoring = false
        // The size everything in the lens is drawn for. It is then scaled to the size the lens is.
        private val base = 84 * dp
        // Two fingers resizing it: where each is on the screen, how far apart they began, and the
        // size the lens had then.
        private var pressed = false
        private var sizing = false
        private var sized = false
        private var stretching = false
        private var atEnd = false
        private var wantSize = 0f
        private var p1x = 0f; private var p1y = 0f; private var p2x = 0f; private var p2y = 0f
        private var startDist = 1f
        private var startSize = 0f
        private var midX = 0f; private var midY = 0f
        // The finger elsewhere on the screen is down; and, once the one on the lens has lifted,
        // that finger is the one dragging the lens.
        private var reachDown = false
        private var adopted = false
        // Held until its menu opened: the rest of that touch belongs to the menu.
        private var menuTouch = false
        // The blob in a container hangs back a little when the container moves, and comes to rest in its middle.
        private var lagX = 0f; private var lagY = 0f
        private var wasX = lp.x; private var wasY = lp.y; private var wasSize = lp.width
        private var resting: android.animation.ValueAnimator? = null
        // While a blob is on its way in from the menu, the one inside is not drawn yet.
        var hideInner = false

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            if (unseen) {
                // In place for a blob that is on its way: it shows itself when the blob lands.
                alpha = 0f
                return
            }
            scaleX = 0.8f; scaleY = 0.8f; alpha = 0f
            animate().scaleX(1f).scaleY(1f).alpha(1f).setDuration(220).setInterpolator(EASE).start()
        }

        /** Moves the lens at once, by this much. Used to put it where a blob was put down. */
        fun jumpBy(dx: Int, dy: Int) {
            springing = false
            glide?.cancel()
            rest()
            lp.x += dx; lp.y += dy
            place()
        }

        /** Lets the lens go from where it is, at this speed: it carries on and settles at the nearer side. */
        fun letFly(velX: Float, velY: Float) {
            if (docked || tucked) return
            snapped = false
            if (velX == 0f && velY == 0f) toSide() else throwIt(velX, velY)
        }

        /** Let go with no speed: straight to the nearer side, with nothing springing. At a side already, it stays. */
        private fun toSide() {
            val screen = resources.displayMetrics
            val margin = 8 * dp
            val w = lp.width; val h = lp.height
            val tx = if (lp.x + w / 2f < screen.widthPixels / 2f) margin else screen.widthPixels - w - margin
            val ty = lp.y.toFloat().coerceIn(48 * dp, Math.max(48 * dp, screen.heightPixels - h - 48 * dp))
            if (Math.abs(tx - lp.x) < 1.5f && Math.abs(ty - lp.y) < 1.5f) return
            glideTo(tx, ty, 220)
        }

        // How far a blob that was put down has become the lens: 0 it is just that blob, 1 it is the lens.
        private var come = 1f

        // While the lens travels by itself (thrown, going to a side, tucking away) its window
        // stays still. Android moves a window a frame or two after it is told to, and not in step
        // with the screen, which is seen as a stutter. So the window is made, once, to cover the
        // whole of the way; the lens is drawn at its place inside it, frame by frame, which is in
        // step; and at the end the window is the lens's own size again, around where it stopped.
        private var roaming = false
        private var roamSize = 0
        private var offX = 0f
        private var offY = 0f

        /** Where the lens is and how large, whether its window is its own size or covers its way. */
        private fun posX() = if (roaming) Math.round(lp.x + offX) else lp.x
        private fun posY() = if (roaming) Math.round(lp.y + offY) else lp.y
        private fun sizeNow() = if (roaming) roamSize else lp.width

        private fun relay() {
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
        }

        /** The window is made to cover every place the lens will be, between these corners. From now the lens is drawn inside it. */
        private fun roam(minX: Float, minY: Float, maxX: Float, maxY: Float) {
            if (roaming || stretching || docked) return
            val size = lp.width
            val pad = (6 * dp).toInt()
            val wx = Math.floor(Math.min(minX, lp.x.toFloat()).toDouble()).toInt() - pad
            val wy = Math.floor(Math.min(minY, lp.y.toFloat()).toDouble()).toInt() - pad
            offX = (lp.x - wx).toFloat()
            offY = (lp.y - wy).toFloat()
            roamSize = size
            lp.width = Math.ceil((Math.max(maxX, lp.x.toFloat()) - wx).toDouble()).toInt() + size + pad
            lp.height = Math.ceil((Math.max(maxY, lp.y.toFloat()) - wy).toDouble()).toInt() + size + pad
            lp.x = wx; lp.y = wy
            roaming = true
            pivotX = offX + size / 2f
            pivotY = offY + size / 2f
            relay()
            invalidate()
        }

        /** Puts the lens at this place: drawn there while its window covers its way, or by moving its window otherwise. */
        private fun moveTo(x: Float, y: Float) {
            if (!roaming) {
                lp.x = x.toInt(); lp.y = y.toInt()
                place()
                return
            }
            offX = (x - lp.x).coerceIn(0f, (lp.width - roamSize).toFloat())
            offY = (y - lp.y).coerceIn(0f, (lp.height - roamSize).toFloat())
            pivotX = offX + roamSize / 2f
            pivotY = offY + roamSize / 2f
            if (!docked) {
                lensX = posX(); lensY = posY()
                placed = true
            }
            lag()
            invalidate()
        }

        /** Whether its window is covering its way just now, and how large the lens itself is. */
        fun roamingNow() = roaming
        fun ownSize() = sizeNow()

        /** The travelling is over, or something else needs the lens: its window is its own size again, around where it is. */
        fun rest() {
            if (!roaming) return
            val x = posX(); val y = posY()
            roaming = false
            lp.width = roamSize; lp.height = roamSize
            lp.x = x; lp.y = y
            if (Build.VERSION.SDK_INT >= 28) resetPivot() else { pivotX = roamSize / 2f; pivotY = roamSize / 2f }
            wasX = x; wasY = y; wasSize = roamSize
            place()
            invalidate()
        }

        /**
         * A blob was put down here and this lens takes over from it. It is drawn as that blob
         * first. Two frames later it is on the screen and [shown] is called; then the glass
         * comes in around it and the blob comes down to the size it has inside, and [then] runs.
         */
        fun arrive(shown: (() -> Unit)?, then: () -> Unit) {
            animate().cancel()
            scaleX = 1f; scaleY = 1f
            come = 0f
            hideInner = false
            alpha = 1f
            invalidate()
            val frames = android.view.Choreographer.getInstance()
            frames.postFrameCallback {
                frames.postFrameCallback {
                    shown?.invoke()
                    val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
                    a.startDelay = 30
                    a.duration = 240
                    a.interpolator = android.view.animation.AccelerateDecelerateInterpolator()
                    a.addUpdateListener {
                        come = it.animatedValue as Float
                        invalidate()
                    }
                    a.addListener(object : android.animation.AnimatorListenerAdapter() {
                        override fun onAnimationEnd(animation: android.animation.Animator) {
                            come = 1f
                            invalidate()
                        }
                    })
                    a.start()
                    postDelayed({ then() }, 160)
                }
            }
        }

        /** Something has just landed in it: it gives a little, wider then taller, and is still again. */
        fun thump() {
            animate().cancel()
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = 420
            a.interpolator = android.view.animation.LinearInterpolator()
            a.addUpdateListener {
                val t = it.animatedValue as Float
                val w = if (t >= 1f) 0f else 0.13f * Math.exp(-5.5 * t).toFloat() * Math.cos(2 * Math.PI * 2.6 * t).toFloat()
                scaleX = 1f + w
                scaleY = 1f - w
            }
            a.start()
        }

        /** Filled with the pinned thing's colour: only the lens as it was before, showing a pinned thing. */
        private fun filled() = !container && mode() != 1

        private fun shaders() {
            val c = lensColor()
            val pinned = filled()
            val r = base / 2f
            val disc = r - 5 * dp
            // A workout's lens is nearly clear, with a breath of the colour. A pinned thing's lens is
            // filled with its own colour, like the blob it came from, but still lets the app show through.
            body = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                if (pinned) intArrayOf(shade(c, 1.06f, 0xD2), shade(c, 0.82f, 0xDC), shade(c, 0.5f, 0xEA))
                else intArrayOf(shade(c, 0.36f, 0x78), shade(c, 0.18f, 0xB4), 0xD60A0B0E.toInt()),
                floatArrayOf(0f, 0.55f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            bodyDone = android.graphics.RadialGradient(
                r - disc * 0.35f, r - disc * 0.45f, disc * 1.7f,
                intArrayOf(shade(c, 1.18f, 0xFF), c, shade(c, 0.72f, 0xFF)),
                floatArrayOf(0f, 0.5f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            rim = android.graphics.LinearGradient(0f, r - disc, 0f, r + disc, 0xB8FFFFFF.toInt(), 0x14FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            shine = android.graphics.LinearGradient(0f, r - disc, 0f, r - disc * 0.1f, 0x34FFFFFF, 0x00FFFFFF, android.graphics.Shader.TileMode.CLAMP)
            glow = android.graphics.RadialGradient(
                r, r + disc * 0.95f, disc * 0.9f,
                intArrayOf(shade(c, 1.2f, 0x50), shade(c, 1.0f, 0x00)), floatArrayOf(0f, 1f), android.graphics.Shader.TileMode.CLAMP,
            )
            shadow = android.graphics.RadialGradient(r, r + 2 * dp, r, intArrayOf(0x55000000, 0x55000000, 0x00000000), floatArrayOf(0f, 0.78f, 1f), android.graphics.Shader.TileMode.CLAMP)
            clip.reset()
            clip.addCircle(r, r, disc, android.graphics.Path.Direction.CW)
            shadersFor = c
            shadersPinned = pinned
        }

        override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
            // (The lens's colours are made when it is first drawn, and again only if its colour
            // changes. They do not depend on the size of its window, which changes whenever the
            // lens travels by itself.)
            if (body == null) shaders()
            // All of it is the lens's to touch, even where it lies over the phone's own
            // swipe-in-from-the-edge zone: a touch there is for the lens and is not a "back".
            if (Build.VERSION.SDK_INT >= 29) systemGestureExclusionRects = listOf(android.graphics.Rect(0, 0, w, h))
        }

        /** For the long test: where the lens itself is, and whether it is on its way anywhere. */
        fun lensLeft() = posX()
        fun lensTop() = posY()
        fun movingNow() = springing || roaming || (glide?.isRunning ?: false)

        override fun onDraw(canvas: android.graphics.Canvas) {
            drawn()
            // The lens is drawn as it is at its usual size, and scaled to the size it is. While two
            // fingers resize it, that size follows the fingers, and the lens sits in the middle of
            // a window as large as it can get: nothing has to be resized on the way.
            val size = if (stretching) wantSize else if (roaming) roamSize.toFloat() else width.toFloat()
            val k = size / base
            canvas.save()
            if (roaming) canvas.translate(offX, offY) else canvas.translate((width - size) / 2f, (height - size) / 2f)
            canvas.scale(k, k)
            val arriving = pin
            if (come < 1f && arriving != null && container && mode() == 2) {
                // Taking over from a blob that was put down: the glass comes in around it, and
                // it comes down from the size it was put down at to the size it has inside.
                val mid = base / 2f
                val layer = canvas.saveLayerAlpha(0f, 0f, base, base + 2 * dp, (come * 255).toInt().coerceIn(0, 255))
                val grown = 0.84f + 0.16f * come
                canvas.scale(grown, grown, mid, mid)
                paintLens(canvas, k, false)
                canvas.restoreToCount(layer)
                val full = Math.min(31 * dp, size / 2f) / k
                paintBlob(canvas, arriving, mid, mid, full + (22.5f * dp - full) * come, dp)
            } else {
                paintLens(canvas, k)
            }
            canvas.restore()
        }

        private fun paintLens(canvas: android.graphics.Canvas, k: Float, inner: Boolean = true) {
            if (shadersFor != lensColor() || shadersPinned != filled()) shaders()
            val colour = lensColor()
            val w = base; val r = w / 2f
            val disc = r - 5 * dp
            val now = System.currentTimeMillis()
            // A workout shows its timer. A pinned thing shows its picture, and has no timer to read.
            // On a sheet's corner it shows the same, and a tap there folds the sheet away.
            val t = if (mode() == 1) reading(now) else null
            val go = t != null && t.go
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
            if (t != null && t.resting) {
                // The ring: the rest running down, or filling up, with a bright bead at its head.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 3.6f * dp
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = 0x24FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                paint.color = colour
                canvas.drawArc(arc, -90f, 360f * t.part, false, paint)
                val a = Math.toRadians((-90f + 360f * t.part).toDouble())
                val bx = r + (arc.width() / 2f) * Math.cos(a).toFloat(); val by = r + (arc.height() / 2f) * Math.sin(a).toFloat()
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = shade(colour, 1.3f, 0x55)
                canvas.drawCircle(bx, by, 5.2f * dp, paint)
                paint.color = WHITE
                canvas.drawCircle(bx, by, 2.1f * dp, paint)
            } else if (t != null && !go && !t.off) {
                // No rest running: a quiet ring with one bead going round once a minute, like a second hand.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = 2.2f * dp
                paint.color = 0x22FFFFFF
                canvas.drawArc(arc, 0f, 360f, false, paint)
                val a = Math.toRadians((-90.0 + 360.0 * (((timerNow(now) - sinceAt) % 60000L) / 60000.0)))
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = colour
                canvas.drawCircle(r + (arc.width() / 2f) * Math.cos(a).toFloat(), r + (arc.height() / 2f) * Math.sin(a).toFloat(), 2.6f * dp, paint)
            }
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 1.3f * dp
            paint.shader = rim
            canvas.drawCircle(r, r, disc - 0.65f * dp, paint)
            paint.shader = null
            paint.style = android.graphics.Paint.Style.FILL
            if (t == null && container) {
                // The container: what was put in it sits inside as the blob it is, with the glass around it.
                val inside = pin
                if (inside != null && !hideInner && inner) {
                    paintBlob(canvas, inside, r + lagX / k, r + lagY / k, 22.5f * dp, dp)
                    paintBadge(canvas, inside, r + disc * 0.66f, r - disc * 0.66f, dp, 0.9f)
                }
                return
            }
            if (t == null) {
                // The pinned thing's picture: its white mark, or its own icon cut round.
                val p = pin
                val bmp = p?.icon
                paint.color = WHITE
                if (p != null && bmp != null) {
                    val half = (if (p.picture) 23f else 19f) * dp
                    dst.set(r - half, r - half, r + half, r + half)
                    paint.isFilterBitmap = true
                    if (p.picture) {
                        round.reset()
                        round.addCircle(r, r, half, android.graphics.Path.Direction.CW)
                        canvas.save()
                        canvas.clipPath(round)
                        canvas.drawBitmap(bmp, null, dst, paint)
                        canvas.restore()
                    } else {
                        canvas.drawBitmap(bmp, null, dst, paint)
                    }
                } else if (p != null && p.name.isNotEmpty()) {
                    paint.textAlign = android.graphics.Paint.Align.CENTER
                    paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                    paint.textSize = 26 * dp
                    canvas.drawText(p.name.substring(0, 1).uppercase(), r, r - (paint.descent() + paint.ascent()) / 2f, paint)
                }
                return // Nothing in it moves, so it is drawn once and left alone.
            }
            // Paused, the time is dimmed and two bars sit under it.
            paint.color = if (go) onAccent else if (t.paused) 0x99FFFFFF.toInt() else if (t.urgent) shade(colour, 1.25f, 0xFF) else WHITE
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.letterSpacing = if (go) 0.06f else -0.01f
            paint.textSize = (if (go) 19f else 17.5f) * dp
            canvas.drawText(t.text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            if (t.paused && k <= 1.45f) pauseMark(canvas, paint, r, r + 15.5f * dp, 7 * dp, shade(colour, 1.25f, 0xFF))
            val under = pin
            if (container && under != null && !hideInner) {
                // What was put in the container waits underneath while a workout has it: a small
                // dot of it on the rim says it is still there.
                val a = Math.toRadians(42.0)
                val out = disc - 2.5f * dp
                val bx = r + (out * Math.cos(a)).toFloat(); val by = r + (out * Math.sin(a)).toFloat()
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = 0xF2101216.toInt()
                canvas.drawCircle(bx, by, 9.6f * dp, paint)
                paintBlob(canvas, under, bx, by, 8f * dp, dp, face = false)
            }
            if (k > 1.45f && !go) {
                // Made large enough, it has room to say more: what the time is, above it, and
                // which set this is, below.
                val show = ((k - 1.45f) / 0.35f).coerceIn(0f, 1f)
                paint.letterSpacing = 0.08f
                paint.textSize = 4.6f * dp
                paint.color = tint(if (t.resting) shade(colour, 1.25f, 0xFF) else WHITE, (show * 0xD0).toInt())
                canvas.drawText(t.what, r, r - 13.5f * dp, paint)
                paint.letterSpacing = 0f
                paint.textSize = 5.2f * dp
                paint.color = tint(WHITE, (show * 0xB8).toInt())
                canvas.drawText(setLabel, r, r + 18.5f * dp, paint)
            }
            // The rest is over: the lens swells once. (The buzz is given on its own, lens or no lens.)
            if (go && swelledFor != endsAt) {
                swelledFor = endsAt
                animate().scaleX(1.12f).scaleY(1.12f).setDuration(180).setInterpolator(EASE).withEndAction {
                    animate().scaleX(1f).scaleY(1f).setDuration(380).setInterpolator(EASE).start()
                }.start()
            }
            // Drawn again when the ring or the number has changed enough to see. Paused or
            // switched off, nothing in it moves, so it is drawn once and left alone.
            if (!t.paused && !t.off) postInvalidateDelayed(beat(now, t, (Math.PI * arc.width() * k).toFloat()))
        }

        /**
         * Takes the lens somewhere in one even movement, nothing springy: to a side, into a side,
         * to a sheet's corner or back from it. Keeping its size, it is drawn moving inside a
         * window that stays still; changing size on the way, its window moves and grows with it.
         */
        fun glideTo(x: Float, y: Float, ms: Long, size: Int = lp.width) {
            springing = false
            leaving = false
            glide?.cancel()
            rest()
            val fromX = lp.x.toFloat(); val fromY = lp.y.toFloat()
            val fromSize = lp.width
            if (size == fromSize) roam(Math.min(fromX, x), Math.min(fromY, y), Math.max(fromX, x), Math.max(fromY, y))
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = ms
            a.interpolator = EASE
            a.addUpdateListener {
                if (isAttachedToWindow) {
                    val f = it.animatedValue as Float
                    if (roaming) {
                        moveTo(fromX + (x - fromX) * f, fromY + (y - fromY) * f)
                    } else {
                        lp.x = Math.round(fromX + (x - fromX) * f); lp.y = Math.round(fromY + (y - fromY) * f)
                        if (size != fromSize) {
                            val now = Math.round(fromSize + (size - fromSize) * f)
                            lp.width = now; lp.height = now
                        }
                        place()
                    }
                }
            }
            a.addListener(object : android.animation.AnimatorListenerAdapter() {
                // Arrived, or stopped on the way by something else: the window is the lens's own again.
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (glide === animation) glide = null
                    if (isAttachedToWindow) rest()
                }
            })
            glide = a
            a.start()
        }

        /** Where the lens sits when it is tucked into a side: past the edge, with a sliver of it left showing. */
        private fun parkedX(right: Boolean): Float {
            val k = lp.width / base
            return if (right) resources.displayMetrics.widthPixels - 22 * dp * k else -(lp.width - 22 * dp * k)
        }

        /** Pushed into a side of the screen and let go: it goes away there, leaving a sliver to see it by. */
        private fun tuckIn(right: Boolean) {
            val screen = resources.displayMetrics
            tucked = true
            tuckRight = right
            target?.held = false
            target?.fall()
            val y = lp.y.toFloat().coerceIn(48 * dp, Math.max(48 * dp, screen.heightPixels - lp.height - 48 * dp))
            glideTo(parkedX(right), y, 260)
            openGrip(context, y.toInt())
        }

        /** Goes to the side it is nearer and tucks in there, unless a finger has it. */
        fun tuckNow() {
            if (tucked || pressed) return
            tuckIn(lp.x + lp.width / 2 > resources.displayMetrics.widthPixels / 2)
        }

        /** Tapped while tucked away: it comes back out to where a lens rests at that side. */
        private fun untuck() {
            val screen = resources.displayMetrics
            haptic(context, "tick")
            tucked = false
            glideTo(if (tuckRight) screen.widthPixels - lp.width - 8 * dp else 8 * dp, lp.y.toFloat(), 260)
        }

        /**
         * Pulled while tucked away. From this moment it is a lens being dragged: it follows the
         * finger at once, and closes the distance to the finger over a moment as it goes.
         */
        private fun pullOut(e: android.view.MotionEvent) {
            tucked = false
            pressed = true
            sizing = false
            atEnd = false
            menuTouch = false
            springing = false
            leaving = false
            glide?.cancel()
            rest()
            tracker?.recycle()
            tracker = android.view.VelocityTracker.obtain()
            downX = e.rawX; downY = e.rawY; startX = lp.x; startY = lp.y
            dragged = true
            snapped = false
            // It starts past the edge, where letting go would tuck it again. The tick comes when it is clear of that.
            wouldTuck = true
            target?.rise()
            haptic(context, "tick")
            val at = IntArray(2)
            getLocationOnScreen(at)
            catchX = e.rawX - (at[0] + width * scaleX / 2f)
            catchY = e.rawY - (at[1] + height * scaleY / 2f)
            catchUp = 0f
            catching?.cancel()
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = 180
            a.interpolator = EASE
            a.addUpdateListener {
                catchUp = it.animatedValue as Float
                // The finger may be holding still: the lens keeps coming to it all the same.
                if (pressed && dragged && !sized) follow()
            }
            catching = a
            a.start()
        }

        /** Puts the lens where the finger has it: moved as far as the finger has moved, and onto the cross when near it. */
        private fun follow() {
            var x = startX + (p1x - downX) + catchX * catchUp
            var y = startY + (p1y - downY) + catchY * catchUp
            // Near the cross the lens is pulled onto it, and lets go again if dragged clear.
            val cx = x + lp.width / 2f; val cy = y + lp.height / 2f
            // The small timer has three places there, and is pulled onto the nearest.
            val three = timer && !big(context)
            var near = 0
            var dist = Math.hypot((cx - crossX()).toDouble(), (cy - crossY()).toDouble()).toFloat()
            if (three) for (k in 1..2) {
                val d2 = Math.hypot((cx - placeX(k)).toDouble(), (cy - crossY()).toDouble()).toFloat()
                if (d2 < dist) { dist = d2; near = k }
            }
            val was = snapped
            val wasSpot = spot
            // (With three side by side each one's pull reaches less far, so that they do not fight.)
            val reach = if (three) (if (snapped && spot == near) 66 else 52) else (if (snapped) 118 else 92)
            snapped = dist < reach * dp
            if (snapped) {
                spot = near
                x = placeX(near) - lp.width / 2f + (cx - placeX(near)) * 0.18f
                y = crossY() - lp.height / 2f + (cy - crossY()) * 0.18f
            }
            if (snapped != was || (snapped && spot != wasSpot)) {
                haptic(context, if (snapped) "click" else "tick")
                target?.held = false
                target?.which = spot
                target?.held = snapped
            }
            lp.x = x.toInt(); lp.y = y.toInt()
            place()
            overBlobs()
            // Pushed a quarter of the way past a side, letting go tucks it away there. A tick says so.
            val past = 0.25f * lp.width
            val would = !snapped && (lp.x < -past || lp.x + lp.width > resources.displayMetrics.widthPixels + past)
            if (would != wouldTuck) {
                wouldTuck = would
                haptic(context, "tick")
            }
        }

        private fun lag() {
            val hereX = posX(); val hereY = posY(); val hereSize = sizeNow()
            val dx = hereX - wasX; val dy = hereY - wasY
            val resized = hereSize != wasSize
            wasX = hereX; wasY = hereY; wasSize = hereSize
            // Only a container showing its blob has anything to hang back, and a change of size is not a movement.
            if (!container || mode() != 2 || resized || stretching || (dx == 0 && dy == 0)) return
            val most = 4.5f * dp
            lagX += ((-dx * 0.8f).coerceIn(-most, most) - lagX) * 0.4f
            lagY += ((-dy * 0.8f).coerceIn(-most, most) - lagY) * 0.4f
            invalidate()
            resting?.cancel()
            removeCallbacks(comeToRest)
            postDelayed(comeToRest, 50)
        }

        private val comeToRest = Runnable {
            val fromX = lagX; val fromY = lagY
            if (fromX != 0f || fromY != 0f) {
                val a = android.animation.ValueAnimator.ofFloat(1f, 0f)
                a.duration = 260
                a.interpolator = EASE
                a.addUpdateListener {
                    val f = it.animatedValue as Float
                    lagX = fromX * f; lagY = fromY * f
                    invalidate()
                }
                resting = a
                a.start()
            }
        }

        // Held still for as long as the phone counts as a hold: the blob menu opens out of the container.
        private val holder = Runnable {
            if (pressed && !dragged && !sized && !docked && !tucked && container && menu == null && isAttachedToWindow && blobs.isNotEmpty()) {
                menuTouch = true
                closeReach(context)
                animate().scaleX(1f).scaleY(1f).setDuration(160).setInterpolator(EASE).start()
                // The same click the button in Prism gives when it is held.
                haptic(context, "click")
                openMenu(context)
            }
        }

        private fun rawX(e: android.view.MotionEvent, i: Int): Float =
            if (Build.VERSION.SDK_INT >= 29) e.getRawX(i) else e.getX(i) + (e.rawX - e.getX(0))

        private fun rawY(e: android.view.MotionEvent, i: Int): Float =
            if (Build.VERSION.SDK_INT >= 29) e.getRawY(i) else e.getY(i) + (e.rawY - e.getY(0))

        private fun largest(): Int {
            val screen = resources.displayMetrics
            // A blob is an app's sign and stays about that size: it gives a tenth and no more.
            // The timer is for reading from across a room, and may be as large as the screen.
            if (!timer) return (base * 1.1f).toInt()
            return Math.max(base.toInt(), minOf(screen.widthPixels, screen.heightPixels) - (16 * dp).toInt())
        }

        /**
         * A second finger, wherever on the screen it is. With the one on the lens it resizes the
         * lens: apart to make it larger, together to make it smaller. The lens stays where it is
         * while they do.
         */
        fun second(down: Boolean, x: Float, y: Float) {
            if (!pressed || docked || tucked) return
            if (!down) {
                sizing = false
                return
            }
            p2x = x; p2y = y
            if (menuTouch) return
            removeCallbacks(holder)
            if (!sizing) {
                sizing = true
                sized = true
                if (!stretching) {
                    // This touch is no longer a drag: the cross goes, and a tap will not follow.
                    stretching = true
                    dragged = true
                    snapped = false
                    wouldTuck = false
                    springing = false
                    glide?.cancel()
                    rest()
                    target?.held = false
                    target?.fall()
                    animate().scaleX(1f).scaleY(1f).setDuration(120).start()
                    haptic(context, "tick")
                    wantSize = lp.width.toFloat()
                    midX = lp.x + lp.width / 2f; midY = lp.y + lp.height / 2f
                    val big = largest()
                    lp.width = big; lp.height = big
                    lp.x = Math.round(midX - big / 2f); lp.y = Math.round(midY - big / 2f)
                    place()
                }
                startDist = Math.max(Math.hypot((p1x - p2x).toDouble(), (p1y - p2y).toDouble()).toFloat(), 40 * dp)
                startSize = wantSize
            }
            stretch()
        }

        private fun stretch() {
            if (!sizing) return
            val apart = Math.hypot((p1x - p2x).toDouble(), (p1y - p2y).toDouble()).toFloat()
            val least = base; val most = largest().toFloat()
            val want = startSize * apart / startDist
            // A click where it will go no further, either way.
            val end = want <= least || want >= most
            if (end && !atEnd) haptic(context, "click")
            atEnd = end
            val now = want.coerceIn(least, most)
            if (now != wantSize) {
                wantSize = now
                invalidate()
            }
        }

        /** After a resize the window goes back to being exactly the lens, at the size it now is, and that size is kept. */
        private fun fit() {
            if (!stretching) return
            stretching = false
            val size = Math.round(wantSize)
            lp.width = size; lp.height = size
            lp.x = Math.round(midX - size / 2f); lp.y = Math.round(midY - size / 2f)
            place()
            lensSize = size
            try {
                context.getSharedPreferences("prism_lens", Context.MODE_PRIVATE).edit().putFloat(if (timer) "timerSize" else "size", size / dp).apply()
            } catch (ex: Exception) {}
        }

        /** Both fingers are off: the lens keeps the size it was given, and settles at the nearer side. */
        private fun endStretch() {
            pressed = false
            sizing = false
            sized = false
            adopted = false
            reachDown = false
            catching?.cancel()
            closeReach(context)
            closeGrip(context)
            tracker?.recycle()
            tracker = null
            val was = stretching
            fit()
            if (was) throwIt(0f, 0f)
        }

        /**
         * Resizing is over and one finger is still down, at this place on the screen: the lens
         * keeps its new size and goes on with that finger, as a lens being dragged.
         */
        private fun resumeDrag(x: Float, y: Float) {
            sizing = false
            sized = false
            fit()
            p1x = x; p1y = y
            downX = x; downY = y; startX = lp.x; startY = lp.y
            dragged = true
            snapped = false
            wouldTuck = false
            catching?.cancel()
            catchX = 0f; catchY = 0f; catchUp = 0f
            tracker?.recycle()
            tracker = android.view.VelocityTracker.obtain()
            target?.rise()
        }

        private fun track(e: android.view.MotionEvent) {
            // Positions on the screen, not in a window, which may be moving under the finger.
            val copy = android.view.MotionEvent.obtain(e)
            copy.setLocation(e.rawX, e.rawY)
            tracker?.addMovement(copy)
            copy.recycle()
        }

        /** A touch on the rest of the screen while a finger is, or has just been, on the lens. */
        fun reach(e: android.view.MotionEvent) {
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    reachDown = true
                    second(true, e.rawX, e.rawY)
                }
                android.view.MotionEvent.ACTION_MOVE -> {
                    if (adopted) {
                        p1x = e.rawX; p1y = e.rawY
                        follow()
                        track(e)
                    } else {
                        second(true, e.rawX, e.rawY)
                    }
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    reachDown = false
                    if (adopted) {
                        letGo(e.actionMasked == android.view.MotionEvent.ACTION_UP)
                    } else if (sized && pressed) {
                        // This finger lifted; the one on the lens carries on dragging it.
                        resumeDrag(p1x, p1y)
                    } else {
                        second(false, 0f, 0f)
                    }
                }
            }
        }

        // Whether Prism has been told the lens is being carried near its blobs, and where it last was told.
        private var toldBlobs = false
        private var toldX = 0f
        private var toldY = 0f

        /** Whether the middle of the lens is among Prism's own blobs, which are out, with something in it to put back. */
        private fun amongBlobs(): Boolean {
            val f = fan ?: return false
            if (f.size < 4 || !this@Floater.foreground || pin == null || snapped) return false
            val vx = lp.x + lp.width / 2f - f[0]
            val vy = lp.y + lp.height / 2f - f[1]
            val d = Math.hypot(vx.toDouble(), vy.toDouble()).toFloat()
            // (How far round from straight up still counts comes from Prism, with the rest.)
            return d >= f[2] && d <= f[3] && -vy > (if (f.size > 4) f[4] else 0.23f) * d
        }

        /** While the lens is carried near Prism's blobs, Prism is told where it is, so they can make room for it. */
        private fun overBlobs() {
            val f = fan
            if (f == null || f.size < 4 || !this@Floater.foreground || pin == null) return
            val cx = lp.x + lp.width / 2f
            val cy = lp.y + lp.height / 2f
            val near = !snapped && Math.hypot((cx - f[0]).toDouble(), (cy - f[1]).toDouble()) < f[3] + 60 * dp
            if (near) {
                if (!toldBlobs || Math.abs(cx - toldX) + Math.abs(cy - toldY) > 3 * dp) {
                    toldBlobs = true
                    toldX = cx; toldY = cy
                    channel?.invokeMethod("lensAt", listOf(cx.toDouble(), cy.toDouble()))
                }
            } else if (toldBlobs) {
                toldBlobs = false
                channel?.invokeMethod("lensAt", null)
            }
        }

        /**
         * Let go among Prism's own blobs: what was in the lens is one of them again. Prism draws
         * it from here, where it was let go, to its seat. A lens that was only that goes; one
         * that is also a workout's stays, and goes to its side.
         */
        private fun putBack() {
            val c = context
            toldBlobs = false
            target?.fall()
            val at = listOf((lp.x + lp.width / 2f).toDouble(), (lp.y + lp.height / 2f).toDouble())
            if (mode() != 2) {
                channel?.invokeMethod("returnedAt", at + listOf(62.0 * dp))
                throwIt(0f, 0f)
                return
            }
            // From this moment it takes no touch. Prism draws the blob where the lens is, at the
            // size it has in the lens, and says when it has. Then what is inside the lens goes,
            // the glass fades from around where it was, and Prism's blob travels to its seat.
            swallowing = true
            lp.flags = lp.flags or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
            val finish: () -> Unit = {
                if (swallowing) {
                    swallowing = false
                    afterSwallow = null
                    pin = null
                    lensX = -1; lensY = -1
                    placed = false
                    tucked = false
                    remove(c)
                    refresh(c)
                }
            }
            afterSwallow = finish
            var gone = false
            val go = Runnable {
                if (!gone) {
                    gone = true
                    handBack = null
                    if (view === this && swallowing) {
                        hideInner = true
                        invalidate()
                        animate().alpha(0f).setDuration(120).setInterpolator(EASE).withEndAction { dropLens(c); finish() }.start()
                    } else {
                        finish()
                    }
                }
            }
            handBack = go
            // Should Prism never answer, the lens still goes.
            watcher.postDelayed(go, 400)
            channel?.invokeMethod("returnedAt", at + listOf((if (container) 45.0 * dp * lp.width / base else 62.0 * dp)))
        }

        /** The finger dragging the lens has lifted: into a side, onto the cross, back among Prism's blobs, or thrown to rest. */
        private fun letGo(up: Boolean) {
            pressed = false
            adopted = false
            removeCallbacks(holder)
            catching?.cancel()
            closeReach(context)
            // The handle of a lens that was pulled out of a side has done its work.
            closeGrip(context)
            var velX = 0f; var velY = 0f
            val t = tracker
            if (t != null) {
                t.computeCurrentVelocity(1000)
                velX = t.xVelocity; velY = t.yVelocity
            }
            tracker?.recycle()
            tracker = null
            // Let go among Prism's blobs, and not flicked through them: it is put back with them.
            if (up && !wouldTuck && amongBlobs() && Math.hypot(velX.toDouble(), velY.toDouble()) < 900 * dp) {
                putBack()
                return
            }
            if (toldBlobs) {
                toldBlobs = false
                channel?.invokeMethod("lensAt", null)
            }
            animate().scaleX(1f).scaleY(1f).setDuration(200).setInterpolator(EASE).start()
            trayAfter(450)
            // (A touch that was taken away while on pause or count up does neither, and is no throw at the cross.)
            if (!up && spot != 0) { snapped = false; spot = 0; target?.held = false }
            if (up && snapped && spot != 0) {
                // Let go on pause or on count up: that is done, and the timer goes back to
                // where it was picked up from.
                val what = spot
                snapped = false
                spot = 0
                target?.held = false
                target?.fall()
                haptic(context, "thud")
                timerDo(context, what)
                glideTo(startX.toFloat(), startY.toFloat(), 300)
                return
            }
            if (up && wouldTuck) {
                tuckIn(lp.x + lp.width / 2f > resources.displayMetrics.widthPixels / 2f)
            } else {
                throwIt(velX, velY)
            }
        }

        private fun place() {
            // Its place on a sheet's corner is not where it lives; only its own place is remembered.
            if (!docked) {
                lensX = lp.x; lensY = lp.y
                placed = true
            }
            lag()
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
        }

        /** The middle of each of the timer's places at the foot: 0 the cross, 1 pause to its left, 2 count up to its right. */
        private fun placeX(k: Int) = crossX() + (if (k == 1) -SIDE else if (k == 2) SIDE else 0) * dp

        /** The middle of the cross, on the screen. */
        private fun crossX() = resources.displayMetrics.widthPixels / 2f
        private fun crossY() = resources.displayMetrics.heightPixels - 104 * dp

        // A firm spring for a thrown lens: it carries on a little with the throw and comes to rest
        // without bouncing.
        private val frame = object : android.view.Choreographer.FrameCallback {
            override fun doFrame(nanos: Long) {
                // (Whatever stopped it has already seen to its window.)
                if (!springing || !isAttachedToWindow) { springing = false; return }
                val dt = if (lastFrame == 0L) 1f / 120f else ((nanos - lastFrame) / 1e9f).coerceIn(0.001f, 0.032f)
                lastFrame = nanos
                val k = if (leaving) 320f else 240f; val c = if (leaving) 30f else 31f
                vx += (-k * (px - tx) - c * vx) * dt; px += vx * dt
                vy += (-k * (py - ty) - c * vy) * dt; py += vy * dt
                val near = if (leaving) 6f else 0.6f
                val still = Math.abs(px - tx) < near && Math.abs(py - ty) < near && (leaving || (Math.abs(vx) < 12f && Math.abs(vy) < 12f))
                if (still) {
                    springing = false
                    // It ends exactly at its place, and its window is its own size again around it.
                    // (On the cross it is about to be gone: it is closed as it is.)
                    moveTo(tx, ty)
                    if (leaving) close() else rest()
                } else {
                    moveTo(px, py)
                    android.view.Choreographer.getInstance().postFrameCallback(this)
                }
            }
        }

        /**
         * Dropped on the cross. The lens falls into it and the cross swallows it. A workout's lens
         * then stays away until the workout page is opened; a pinned thing is unpinned.
         */
        private fun close() {
            haptic(context, "thud")
            val c = context
            val wasWorkout = mode() == 1
            val colour = lensColor()
            // From this moment it takes no touch: a tap where it was goes to what is underneath.
            // It shrinks into the cross and is taken off the screen; the cross finishes alone.
            swallowing = true
            lp.flags = lp.flags or android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
            try { (context.getSystemService(Context.WINDOW_SERVICE) as android.view.WindowManager).updateViewLayout(this, lp) } catch (ex: Exception) {}
            animate().scaleX(0f).scaleY(0f).setDuration(150).setInterpolator(android.view.animation.AccelerateInterpolator(1.6f))
                .withEndAction { dropLens(c) }.start()
            val finish: () -> Unit = {
                if (swallowing) {
                    swallowing = false
                    afterSwallow = null
                    if (wasWorkout) {
                        // The timer on the cross: it is stopped, and off the screen. A new rest brings it back.
                        dismissed = true
                        if (!timerOff) channel?.invokeMethod("timerOff", null)
                    } else {
                        // Dropped on the cross, nothing floats: a guest goes, and so does what it stood in for.
                        guest = false
                        own = null
                        pin = null
                        channel?.invokeMethod("unpinned", null)
                    }
                    // It comes back at its usual place, not on the cross. If something is still due (a
                    // container's other thing, once the workout's timer is closed), that is a fresh lens.
                    lensX = -1; lensY = -1
                    placed = false
                    tucked = false
                    remove(c)
                    refresh(c)
                }
            }
            afterSwallow = finish
            val t = target
            if (t != null) t.swallow(colour, finish) else finish()
        }

        private fun throwIt(velX: Float, velY: Float) {
            val screen = resources.displayMetrics
            val margin = 8 * dp
            glide?.cancel()
            rest()
            px = lp.x.toFloat(); py = lp.y.toFloat(); vx = velX; vy = velY
            // Where it would coast to decides where it ends up, so a flick carries it.
            val coastX = px + velX * 0.16f
            val coastY = py + velY * 0.18f
            // A flick down toward the middle is a throw at the cross.
            val w = lp.width; val h = lp.height
            val atCross = velY > 700 && coastY + h / 2f > screen.heightPixels * 0.70f && Math.abs(coastX + w / 2f - crossX()) < 120 * dp
            leaving = snapped || atCross
            if (leaving) {
                tx = crossX() - w / 2f; ty = crossY() - h / 2f
                target?.held = true
            } else {
                tx = if (coastX + w / 2f < screen.widthPixels / 2f) margin else screen.widthPixels - w - margin
                ty = coastY.coerceIn(48 * dp, Math.max(48 * dp, screen.heightPixels - h - 48 * dp))
                target?.held = false
                target?.fall()
            }
            // The whole of the way it will go, worked out ahead, so that its window can cover it once and stay still.
            val k = if (leaving) 320f else 240f
            val c = if (leaving) 30f else 31f
            var sx = px; var sy = py; var svx = vx; var svy = vy
            var loX = Math.min(px, tx); var hiX = Math.max(px, tx)
            var loY = Math.min(py, ty); var hiY = Math.max(py, ty)
            val step = 1f / 240f
            for (n in 0 until 720) {
                svx += (-k * (sx - tx) - c * svx) * step; sx += svx * step
                svy += (-k * (sy - ty) - c * svy) * step; sy += svy * step
                if (sx < loX) loX = sx
                if (sx > hiX) hiX = sx
                if (sy < loY) loY = sy
                if (sy > hiY) hiY = sy
            }
            roam(loX, loY, hiX, hiY)
            lastFrame = 0L
            if (!springing) {
                springing = true
                android.view.Choreographer.getInstance().postFrameCallback(frame)
            }
        }

        override fun onTouchEvent(e: android.view.MotionEvent): Boolean {
            if (roaming && e.actionMasked == android.view.MotionEvent.ACTION_DOWN) {
                // Its window covers the way it is going. Only the lens itself is the lens's to
                // touch; caught, it stops there and its window is its own size again.
                val dx = e.x - (offX + roamSize / 2f)
                val dy = e.y - (offY + roamSize / 2f)
                if (dx * dx + dy * dy > (roamSize / 2f) * (roamSize / 2f)) return false
                springing = false
                glide?.cancel()
                rest()
            }
            if (docked) {
                // On a sheet's corner it is one thing only: the button that folds the sheet away.
                when (e.actionMasked) {
                    android.view.MotionEvent.ACTION_DOWN -> animate().scaleX(0.9f).scaleY(0.9f).setDuration(90).start()
                    android.view.MotionEvent.ACTION_UP -> {
                        animate().scaleX(1f).scaleY(1f).setDuration(200).setInterpolator(EASE).start()
                        haptic(context, "tick")
                        closeSheet(context)
                    }
                    android.view.MotionEvent.ACTION_CANCEL -> animate().scaleX(1f).scaleY(1f).setDuration(160).start()
                }
                return true
            }
            if (e.actionMasked == android.view.MotionEvent.ACTION_DOWN) ignoring = false
            if (ignoring) return true
            if (tucked) {
                // Tucked away. A tap brings it back out to rest at that side. A pull brings it out
                // under the finger, and from there on it is being dragged like at any other time.
                when (e.actionMasked) {
                    android.view.MotionEvent.ACTION_DOWN -> {
                        downX = e.rawX; downY = e.rawY
                        return true
                    }
                    android.view.MotionEvent.ACTION_MOVE -> {
                        if (Math.hypot((e.rawX - downX).toDouble(), (e.rawY - downY).toDouble()) < 6 * dp) return true
                        pullOut(e)
                    }
                    android.view.MotionEvent.ACTION_UP -> {
                        ignoring = true
                        untuck()
                        closeGrip(context)
                        return true
                    }
                    else -> return true
                }
            }
            p1x = e.rawX; p1y = e.rawY
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_POINTER_DOWN -> {
                    // A second finger, on a phone that sends it to the lens wherever it lands.
                    if (e.pointerCount >= 2) second(true, rawX(e, 1), rawY(e, 1))
                    return true
                }
                android.view.MotionEvent.ACTION_POINTER_UP -> {
                    // One of two fingers that are both the lens's own has lifted: the other carries on dragging it.
                    val keep = if (e.actionIndex == 0) 1 else 0
                    if (sized && e.pointerCount >= 2) resumeDrag(rawX(e, keep), rawY(e, keep)) else second(false, 0f, 0f)
                    return true
                }
            }
            if (sized) {
                // Two fingers are resizing it, or were: this touch no longer moves it or taps it.
                when (e.actionMasked) {
                    android.view.MotionEvent.ACTION_MOVE -> {
                        if (sizing && e.pointerCount >= 2) {
                            p2x = rawX(e, 1); p2y = rawY(e, 1)
                        }
                        stretch()
                    }
                    android.view.MotionEvent.ACTION_UP -> {
                        if (reachDown) {
                            // The finger on the lens lifted first; the other one carries on dragging it.
                            adopted = true
                            resumeDrag(p2x, p2y)
                        } else {
                            endStretch()
                        }
                    }
                    android.view.MotionEvent.ACTION_CANCEL -> endStretch()
                }
                return true
            }
            if (menuTouch) {
                // The menu is open under this same touch: slide onto a blob and let go to use it,
                // or just let go and then tap one.
                when (e.actionMasked) {
                    android.view.MotionEvent.ACTION_MOVE -> menu?.hover(e.rawX, e.rawY)
                    android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                        menuTouch = false
                        pressed = false
                        tracker?.recycle()
                        tracker = null
                        if (e.actionMasked == android.view.MotionEvent.ACTION_UP) menu?.release(e.rawX, e.rawY) else menu?.hover(-1f, -1f)
                    }
                }
                return true
            }
            when (e.actionMasked) {
                android.view.MotionEvent.ACTION_DOWN -> {
                    closeTray(context)
                    spot = 0
                    target?.which = 0
                    pressed = true
                    sizing = false
                    atEnd = false
                    menuTouch = false
                    adopted = false
                    reachDown = false
                    if (container) {
                        postDelayed(holder, android.view.ViewConfiguration.getLongPressTimeout().toLong().coerceIn(300L, 600L))
                    }
                    // From now until the finger lifts, a second finger anywhere resizes the lens.
                    openReach(context)
                    springing = false
                    leaving = false
                    wouldTuck = false
                    glide?.cancel()
                    catching?.cancel()
                    catchX = 0f; catchY = 0f; catchUp = 0f
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
                        removeCallbacks(holder)
                        // The cross appears as soon as the lens is picked up.
                        target?.rise()
                    }
                    if (dragged) follow()
                }
                android.view.MotionEvent.ACTION_UP, android.view.MotionEvent.ACTION_CANCEL -> {
                    if (e.actionMasked == android.view.MotionEvent.ACTION_UP && !dragged) {
                        pressed = false
                        removeCallbacks(holder)
                        closeReach(context)
                        closeGrip(context)
                        animate().scaleX(1f).scaleY(1f).setDuration(200).setInterpolator(EASE).start()
                        haptic(context, "tick")
                        // Tapped. A workout opens its sheet; a pinned thing does what it is.
                        if (mode() == 1) openSheet(context) else tapPinned(context)
                        tracker?.recycle()
                        tracker = null
                    } else {
                        letGo(e.actionMasked == android.view.MotionEvent.ACTION_UP)
                    }
                    return true
                }
            }
            track(e)
            return true
        }
    }

    /** The timer in the sheet: a ring with the time in it. */
    private inner class Clock(context: Context) : android.view.View(context) {
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
            if (t.off) {
                // Switched off: an empty ring, and the words. A tap switches it on again.
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = stroke
                paint.color = tint(ink(), 0x18)
                canvas.drawArc(arc, 0f, 360f, false, paint)
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = muted()
                paint.textAlign = android.graphics.Paint.Align.CENTER
                paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
                paint.textSize = Math.max(w * 0.13f, 10 * dp)
                if (w > 100 * dp) {
                    canvas.drawText("Timer off", r, r - (paint.descent() + paint.ascent()) / 2f, paint)
                } else {
                    canvas.drawText("Off", r, r - (paint.descent() + paint.ascent()) / 2f, paint)
                }
                return
            }
            if (t.go) {
                paint.style = android.graphics.Paint.Style.FILL
                paint.color = accent
                canvas.drawCircle(r, r, r - stroke / 2, paint)
            } else {
                paint.style = android.graphics.Paint.Style.STROKE
                paint.strokeWidth = stroke
                paint.strokeCap = android.graphics.Paint.Cap.ROUND
                paint.color = tint(ink(), 0x22)
                canvas.drawArc(arc, 0f, 360f, false, paint)
                // Paused, the ring is dimmed.
                paint.color = if (t.paused) tint(accent, 0x80) else accent
                if (t.resting) {
                    canvas.drawArc(arc, -90f, 360f * t.part, false, paint)
                } else {
                    val a = Math.toRadians((-90.0 + 360.0 * (((timerNow(now) - sinceAt) % 60000L) / 60000.0)))
                    paint.style = android.graphics.Paint.Style.FILL
                    canvas.drawCircle(r + (arc.width() / 2f) * Math.cos(a).toFloat(), r + (arc.height() / 2f) * Math.sin(a).toFloat(), stroke * 0.8f, paint)
                }
            }
            paint.style = android.graphics.Paint.Style.FILL
            paint.color = if (t.go) onAccent else if (t.paused) tint(ink(), 0x99) else if (t.urgent) shade(accent, 1.25f, 0xFF) else ink()
            paint.textAlign = android.graphics.Paint.Align.CENTER
            paint.typeface = android.graphics.Typeface.create("sans-serif-medium", android.graphics.Typeface.BOLD)
            paint.fontFeatureSettings = "tnum"
            paint.textSize = w * 0.27f
            canvas.drawText(t.text, r, r - (paint.descent() + paint.ascent()) / 2f, paint)
            if (t.paused) {
                pauseMark(canvas, paint, r, r + w * 0.24f, w * 0.1f, accent)
            } else {
                postInvalidateDelayed(beat(now, t, (Math.PI * arc.width()).toFloat()))
            }
        }
    }

    /**
     * A thumb dial, the same as the ones on Prism's workout page: drag sideways and the number
     * turns under the thumb with a click for every step; slow down and it changes to fine
     * steps with a different click; a tap on either half nudges it one step.
     */
    private inner class Dial(context: Context, val unit: String, val step: Double, val fine: Double, val min: Double, val max: Double) : android.view.View(context) {
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
            paint.color = if (dragging) tint(accent, 0x2E) else tint(ink(), 0x14)
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
            val base = if (dragging) accent else muted()
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
            paint.color = ink()
            canvas.drawText(num, x0, baseline, paint)
            paint.textSize = 12 * dp
            paint.typeface = android.graphics.Typeface.create("sans-serif", android.graphics.Typeface.NORMAL)
            paint.color = muted()
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
    private inner class Tick(context: Context) : android.view.View(context) {
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
            paint.color = if (done) GREEN else tint(ink(), 0x66)
            canvas.drawCircle(c, cy, r - 1 * dp, paint)
            check.reset()
            check.moveTo(c - 8 * dp, cy + 0.5f * dp)
            check.lineTo(c - 2.5f * dp, cy + 6 * dp)
            check.lineTo(c + 8.5f * dp, cy - 5.5f * dp)
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 2.6f * dp
            paint.strokeCap = android.graphics.Paint.Cap.ROUND
            paint.strokeJoin = android.graphics.Paint.Join.ROUND
            paint.color = if (done) 0xFFFFFFFF.toInt() else tint(ink(), 0x66)
            canvas.drawPath(check, paint)
        }
    }

    /** The grabber at the top of a sheet: a shallow arrow in the colour, pointing the way the sheet can go. */
    private inner class Grab(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val path = android.graphics.Path()
        private val dp = resources.displayMetrics.density
        // How far it is bent, and which way: 1 is toward the bottom, -1 toward the top.
        private var bend = 1f
        private var turning: android.animation.ValueAnimator? = null
        var up = false
            set(v) {
                if (field != v) {
                    field = v
                    val to = if (v) -1f else 1f
                    turning?.cancel()
                    if (isLaidOut) {
                        // It bends over to the other side; it does not flip.
                        val a = android.animation.ValueAnimator.ofFloat(bend, to)
                        a.duration = 280
                        a.interpolator = EASE
                        a.addUpdateListener {
                            bend = it.animatedValue as Float
                            invalidate()
                        }
                        turning = a
                        a.start()
                    } else {
                        bend = to
                        invalidate()
                    }
                }
            }

        override fun onDraw(canvas: android.graphics.Canvas) {
            val cx = width / 2f
            val cy = height / 2f
            // Wide, with a slight bend at the middle: toward the top when the sheet can be pulled up.
            val w = 31 * dp
            val h = 3.4f * dp * bend
            path.reset()
            path.moveTo(cx - w, cy - h)
            path.lineTo(cx, cy + h)
            path.lineTo(cx + w, cy - h)
            paint.style = android.graphics.Paint.Style.STROKE
            paint.strokeWidth = 4.4f * dp
            paint.strokeCap = android.graphics.Paint.Cap.ROUND
            paint.strokeJoin = android.graphics.Paint.Join.ROUND
            paint.color = accent
            canvas.drawPath(path, paint)
        }
    }

    /**
     * Which set this is and how many there are, at a glance: one segment for each set, the same
     * bar the workout page draws for its exercises. Done is green, the one in hand is in the
     * colour, the rest are faint. The warm-up is the short one at the start.
     */
    private inner class Pips(context: Context) : android.view.View(context) {
        private val paint = android.graphics.Paint(android.graphics.Paint.ANTI_ALIAS_FLAG)
        private val dp = resources.displayMetrics.density

        override fun onDraw(canvas: android.graphics.Canvas) {
            val n = sets.size
            if (n == 0) return
            val gap = 5 * dp
            val h = height.toFloat()
            val short = 0.34f
            val unit = (width - gap * (n - 1)) / ((n - 1) + short)
            var x = 0f
            for (i in 0 until n) {
                val w = if (i == 0) unit * short else unit
                paint.color = when {
                    sets[i].done -> GREEN
                    i == current -> accent
                    else -> tint(ink(), 0x30)
                }
                canvas.drawRoundRect(x, 0f, x + w, h, h / 2f, h / 2f, paint)
                x += w + gap
            }
        }
    }

    private class Row(val root: android.widget.LinearLayout, val name: android.widget.TextView, val kg: Dial, val reps: Dial, val tick: Tick)

    /**
     * A sheet at the bottom of the screen. Every floating sheet is one of these, so they all
     * arrive, lean, settle and leave the same way: a glass card with a grabber, which follows a
     * downward pull, folds away on a touch outside, and tells its owner when it has been pulled
     * down or up.
     */
    private abstract inner class Sheet(context: Context) : android.widget.FrameLayout(context) {
        protected val dp = resources.displayMetrics.density
        protected fun px(v: Float) = (v * dp).toInt()
        protected val wrap = android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
        protected val fill = android.widget.LinearLayout.LayoutParams.MATCH_PARENT
        protected val card = android.widget.LinearLayout(context)
        protected val grab = Grab(context)
        private val grabBox = android.widget.FrameLayout(context)
        // Solid, with a lit edge. It cannot blur what is underneath, and anything showing through
        // unblurred, however faintly, only gets in the way of reading the sheet.
        private val glass = android.graphics.drawable.GradientDrawable(
            android.graphics.drawable.GradientDrawable.Orientation.TL_BR,
            if (light) intArrayOf(0xFFFFFDF8.toInt(), 0xFFF3EEE4.toInt()) else intArrayOf(0xFF1C1F27.toInt(), 0xFF0E0F13.toInt()),
        )
        // How far below the top of [body] the glass starts: nothing, except while the sheet is changing size.
        private var edge = 0
        // What was on the glass before a change of size, fading away where it stood.
        private var ghost: android.graphics.Bitmap? = null
        private var ghostAlpha = 0f
        private var ghostTop = 0
        private val ghostPaint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)

        /** The glass and everything on it. This is what comes up, drops away and follows a pull. */
        protected val body: android.widget.FrameLayout = object : android.widget.FrameLayout(context) {
            override fun onDraw(canvas: android.graphics.Canvas) {
                glass.setBounds(0, edge, width, height)
                glass.draw(canvas)
            }

            override fun dispatchDraw(canvas: android.graphics.Canvas) {
                super.dispatchDraw(canvas)
                val g = ghost
                if (g != null && ghostAlpha > 0.004f) {
                    ghostPaint.alpha = (ghostAlpha * 255).toInt()
                    canvas.drawBitmap(g, 0f, ghostTop.toFloat(), ghostPaint)
                }
            }
        }
        private var downX = 0f
        private var downY = 0f
        private var pulling = false
        private var tracker: android.view.VelocityTracker? = null
        protected var closing = false
            private set

        // A change of size under way.
        private var morphing: android.animation.ValueAnimator? = null
        protected var changing = false
            private set
        private var part = 1f
        private var glassFrom = 0f
        private var glassNow = 0f
        private var through: List<android.view.View> = emptyList()
        private var riders: List<android.view.View> = emptyList()
        private var steady: android.view.View? = null
        private var docking = false
        private var morphMs = 300L

        init {
            // A little room above the glass, so it can lean past its place when pulled up. Kept small:
            // this strip belongs to the sheet's window, and the lens sits just above it.
            setPadding(0, px(8f), 0, 0)
            clipChildren = false
            clipToPadding = false
            card.orientation = android.widget.LinearLayout.VERTICAL
            card.setPadding(px(14f), px(4f), px(14f), px(14f))
            card.clipChildren = false
            card.clipToPadding = false
            glass.cornerRadius = 32 * dp
            glass.setStroke(px(1.2f), if (light) 0x24000000 else 0x40FFFFFF)
            // The glass is drawn by [body], and everything on it is cut to the glass's shape, so
            // that nothing shows past its top edge while that edge is moving.
            body.setWillNotDraw(false)
            body.clipChildren = false
            body.outlineProvider = object : android.view.ViewOutlineProvider() {
                override fun getOutline(view: android.view.View, outline: android.graphics.Outline) {
                    outline.setRoundRect(0, edge, view.width, view.height, 32 * dp)
                }
            }
            body.clipToOutline = true
            body.addView(card, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT, android.view.Gravity.BOTTOM))
            addView(body, LayoutParams(LayoutParams.MATCH_PARENT, LayoutParams.WRAP_CONTENT))
            // The grabber: pull it, or tap it. An arrow in the colour, pointing the way the sheet can go.
            grabBox.addView(grab, LayoutParams(px(88f), px(24f), android.view.Gravity.CENTER))
            grabBox.setOnClickListener { tappedGrabber() }
            card.addView(grabBox, android.widget.LinearLayout.LayoutParams(fill, px(30f)))
            // The lens keeps to this sheet's corner: it is told as soon as the sheet has a size, or a new one.
            addOnLayoutChangeListener { _, left, top, right, bottom, wasLeft, wasTop, wasRight, wasBottom ->
                if (right - left != wasRight - wasLeft || bottom - top != wasBottom - wasTop) post { dock(context) }
            }
        }

        // Keeps the lens on this sheet's corner while the sheet is open, wherever the sheet goes.
        private val keeper = object : Runnable {
            override fun run() {
                if (sheet !== this@Sheet) return
                dock(context)
                postDelayed(this, 200)
            }
        }

        // While the sheet is changing size, everything is put in its place after layout and
        // before each frame is drawn.
        private val beforeDraw = android.view.ViewTreeObserver.OnPreDrawListener {
            if (morphing != null) pose()
            true
        }

        /** Pulled or flicked down. */
        abstract fun pulledDown()

        /** Pulled or flicked up. False if there is nothing taller for it to become. */
        open fun pulledUp(): Boolean = false

        open fun tappedGrabber() {}

        /** Brings what is shown up to date. */
        open fun sync() {}

        /** Where the top of the glass is, or is on its way to, measured from the top of this sheet's window. */
        fun glassTop(): Int = body.top + body.height - card.height

        // The back button folds the sheet away. Android 13 and later hand it over through a
        // callback; before that it arrives as a key.
        private var back: Any? = null

        /** For the long test: what the back button does here. */
        fun testBack() {
            if (!closing) closeSheet(context)
        }

        override fun onAttachedToWindow() {
            super.onAttachedToWindow()
            viewTreeObserver.addOnPreDrawListener(beforeDraw)
            if (Build.VERSION.SDK_INT >= 33) {
                val callback = android.window.OnBackInvokedCallback { if (!closing) closeSheet(context) }
                back = callback
                findOnBackInvokedDispatcher()?.registerOnBackInvokedCallback(android.window.OnBackInvokedDispatcher.PRIORITY_DEFAULT, callback)
            }
        }

        override fun onDetachedFromWindow() {
            if (Build.VERSION.SDK_INT >= 33) {
                val callback = back as? android.window.OnBackInvokedCallback
                if (callback != null) findOnBackInvokedDispatcher()?.unregisterOnBackInvokedCallback(callback)
                back = null
            }
            viewTreeObserver.removeOnPreDrawListener(beforeDraw)
            stopMorph(false)
            super.onDetachedFromWindow()
        }

        override fun dispatchKeyEvent(e: android.view.KeyEvent): Boolean {
            if (e.keyCode == android.view.KeyEvent.KEYCODE_BACK) {
                if (e.action == android.view.KeyEvent.ACTION_UP && !closing) closeSheet(context)
                return true
            }
            return super.dispatchKeyEvent(e)
        }

        /** It comes up a short way into its place. */
        open fun arrive() {
            body.translationY = 26 * dp
            body.alpha = 0f
            body.animate().translationY(0f).alpha(1f).setDuration(300).setInterpolator(EASE).start()
            post(keeper)
        }

        /** It drops a little and is gone. What it shows stays as it was while it goes. */
        fun leave(then: () -> Unit) {
            if (closing) return
            closing = true
            var gone = false
            val finish = Runnable {
                if (!gone) {
                    gone = true
                    then()
                }
            }
            body.animate().translationY(body.translationY + 16 * dp).alpha(0f).setDuration(150)
                .setInterpolator(android.view.animation.AccelerateInterpolator(1.2f)).withEndAction(finish).start()
            // Whatever becomes of that movement, the sheet goes.
            postDelayed(finish, 320)
        }

        /**
         * Changes the sheet's size in one even movement. The top edge of the glass travels to its
         * new place. [fade] is what is swapped on the way: what was there goes first, what
         * replaces it comes after. [ride] keeps its place under the edge as that moves. [keep]
         * is the thing at the bottom that stays exactly as it is.
         */
        protected fun morph(ms: Long, fade: List<android.view.View>, ride: List<android.view.View>, keep: android.view.View?, change: () -> Unit) {
            if (!isLaidOut || card.height == 0 || closing || (changing && morphing == null)) {
                change()
                return
            }
            val again = morphing != null
            val from = if (again) glassNow else card.height.toFloat()
            stopMorph(false)
            changing = true
            ghost = if (!again && fade.isNotEmpty()) snapshot(fade, keep?.top ?: card.height) else null
            // The window keeps its height until the glass has finished moving inside it.
            body.minimumHeight = body.height
            through = fade
            riders = ride
            steady = keep
            glassFrom = from
            part = 0f
            morphMs = ms
            docking = true
            change()
            body.animate().translationY(0f).setDuration(ms).setInterpolator(EASE).start()
            val a = android.animation.ValueAnimator.ofFloat(0f, 1f)
            a.duration = ms
            a.interpolator = android.view.animation.LinearInterpolator()
            a.addUpdateListener {
                part = it.animatedValue as Float
                body.invalidate()
            }
            a.addListener(object : android.animation.AnimatorListenerAdapter() {
                override fun onAnimationEnd(animation: android.animation.Animator) {
                    if (morphing === animation) stopMorph(true)
                }
            })
            morphing = a
            a.start()
        }

        /** Puts everything where it belongs at this moment of a change of size. */
        private fun pose() {
            val to = card.height.toFloat()
            glassNow = glassFrom + (to - glassFrom) * EASE.getInterpolation(part)
            edge = Math.round(body.height - glassNow).coerceAtLeast(0)
            val off = (edge - card.top).toFloat()
            grabBox.translationY = off
            for (v in riders) v.translationY = off
            // What was there goes first and quickly; what replaces it comes up after.
            ghostAlpha = 1f - smooth(part / 0.34f)
            ghostTop = card.top + (steady?.top ?: card.height) - (ghost?.height ?: 0)
            val shown = smooth((part - 0.22f) / 0.6f)
            for (v in through) v.alpha = shown
            body.invalidate()
            body.invalidateOutline()
            if (docking) {
                // The lens sets off for the corner's new place with the edge, and takes as long.
                docking = false
                dock(context, morphMs)
            }
        }

        private fun stopMorph(release: Boolean) {
            val a = morphing
            morphing = null
            changing = false
            if (a != null) {
                a.removeAllListeners()
                a.removeAllUpdateListeners()
                a.cancel()
            }
            grabBox.translationY = 0f
            for (v in riders) v.translationY = 0f
            for (v in through) v.alpha = 1f
            riders = emptyList()
            through = emptyList()
            steady = null
            ghost = null
            ghostAlpha = 0f
            if (release) {
                edge = 0
                body.minimumHeight = 0
            }
            body.invalidate()
            body.invalidateOutline()
        }

        /** A picture of [views] as they stand, from the top of the card down to [until]. */
        private fun snapshot(views: List<android.view.View>, until: Int): android.graphics.Bitmap? {
            if (card.width <= 0 || until <= 0) return null
            return try {
                val b = android.graphics.Bitmap.createBitmap(card.width, until, android.graphics.Bitmap.Config.ARGB_8888)
                val c = android.graphics.Canvas(b)
                for (v in views) {
                    if (v.visibility != android.view.View.VISIBLE) continue
                    c.save()
                    c.translate(v.left.toFloat(), v.top.toFloat())
                    v.draw(c)
                    c.restore()
                }
                b
            } catch (e: Throwable) {
                null
            }
        }

        private fun settle() {
            body.animate().translationY(0f).setDuration(240).setInterpolator(EASE).start()
        }

        override fun dispatchTouchEvent(e: android.view.MotionEvent): Boolean {
            // A touch anywhere outside folds it away; the touch still reaches what is underneath.
            if (e.actionMasked == android.view.MotionEvent.ACTION_OUTSIDE) {
                closeSheet(context)
                return true
            }
            // On its way out it takes no more touches.
            if (closing) return true
            return super.dispatchTouchEvent(e)
        }

        private fun watch(e: android.view.MotionEvent) {
            val copy = android.view.MotionEvent.obtain(e)
            copy.setLocation(e.rawX, e.rawY)
            tracker?.addMovement(copy)
            copy.recycle()
        }

        private fun startsPull(e: android.view.MotionEvent): Boolean {
            val dx = e.rawX - downX
            val dy = e.rawY - downY
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
                        // Down, it follows the finger. Up, it only leans.
                        body.translationY = if (dy > 0) dy else -Math.min(7 * dp, -dy * 0.12f)
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
                                haptic(context, "tick")
                                pulledDown()
                            }
                            dy < -36 * dp || vy < -1100 -> {
                                if (pulledUp()) haptic(context, "tick") else settle()
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

    /** The workout's sheet, in two sizes: the current set, or the whole exercise with a large timer. */
    private inner class WorkoutSheet(context: Context) : Sheet(context) {
        private val header = android.widget.LinearLayout(context)
        private val clock = Clock(context)
        private val info = android.widget.LinearLayout(context)
        private val what = label(context, 11.5f, muted(), true)
        private val name = label(context, 18f, ink(), true)
        private val which = label(context, 12.5f, muted(), false)
        private val controls = android.widget.LinearLayout(context)
        private val add = label(context, 13f, ink(), true)
        private val skip = label(context, 13f, ink(), true)
        private val open = label(context, 13f, ink(), true)
        private val pips = Pips(context)
        private val rows = android.widget.LinearLayout(context)
        private val rowViews = ArrayList<Row>()
        private val done = label(context, 16.5f, onAccent, true)
        // What holding the timer offers: counting the other way, starting over, switching it off.
        private val turnMode = label(context, 13f, ink(), true)
        private val startOver = label(context, 13f, ink(), true)
        private val switchOff = label(context, 13f, ink(), true)
        private val hint = label(context, 11f, muted(), false)
        private var options = false
        private val endOptions = Runnable {
            options = false
            texts()
        }
        private val stop = label(context, 13f, muted(), true)
        private val stopRow = android.widget.LinearLayout(context)
        private var stopArmed = false
        private val disarm = Runnable {
            stopArmed = false
            stopLook()
        }

        // Whether the line that explains the timer has been seen. Once it has, it is not asked again.
        private var hintSeen = false

        private val ticker = object : Runnable {
            override fun run() {
                if (sheet !== this@WorkoutSheet) return
                texts()
                postDelayed(this, 250)
            }
        }

        init {
            // The timer is its own control. A tap pauses it, or starts it again (or switches it
            // back on). Held, it offers the rest: counting the other way, starting over, and off.
            clock.setOnClickListener {
                haptic(context, "click")
                channel?.invokeMethod(if (timerOff) "timerOff" else "timerPause", null)
            }
            clock.setOnLongClickListener {
                haptic(context, "click")
                showOptions()
                true
            }
            what.letterSpacing = 0.08f
            what.maxLines = 1
            name.maxLines = 1
            what.setOnClickListener {
                haptic(context, "tick")
                showOptions()
            }
            what.setPadding(0, px(4f), 0, px(4f))
            info.orientation = android.widget.LinearLayout.VERTICAL
            info.addView(what)
            info.addView(name)
            val whichLp = android.widget.LinearLayout.LayoutParams(wrap, wrap)
            whichLp.topMargin = px(2f)
            info.addView(which, whichLp)
            // Said once, in the tall sheet, until the timer has been held: what the timer does.
            hint.text = "Tap the timer to pause it. Hold it for more."
            val hintLp = android.widget.LinearLayout.LayoutParams(wrap, wrap)
            hintLp.topMargin = px(6f)
            info.addView(hint, hintLp)

            // [click] is false where Prism does the thing and gives its own click for it.
            fun pill(t: android.widget.TextView, text: String, click: Boolean, action: () -> Unit) {
                t.text = text
                t.setPadding(px(14f), px(10f), px(14f), px(10f))
                t.background = rounded(tint(ink(), 0x1F), 100 * dp)
                t.setOnClickListener {
                    if (click) haptic(context, "tick")
                    action()
                }
            }
            pill(add, "+15 s", false) { channel?.invokeMethod("restAdd", null) }
            pill(skip, "Skip", false) { channel?.invokeMethod("restSkip", null) }
            pill(open, "Open workout", true) { openPrism(context) }
            pill(turnMode, "Count up", true) {
                countUp = !countUp
                channel?.invokeMethod("timerMode", null)
                clock.invalidate()
                view?.invalidate()
                endOptionsNow()
            }
            // Prism does these two and gives the click for them.
            pill(startOver, "Start over", false) {
                channel?.invokeMethod("timerReset", null)
                endOptionsNow()
            }
            pill(switchOff, "Switch off", false) {
                channel?.invokeMethod("timerOff", null)
                endOptionsNow()
            }
            controls.gravity = android.view.Gravity.CENTER_VERTICAL
            val gapLp = { android.widget.LinearLayout.LayoutParams(wrap, wrap).also { it.leftMargin = px(8f) } }
            controls.addView(add, android.widget.LinearLayout.LayoutParams(wrap, wrap))
            controls.addView(skip, gapLp())
            controls.addView(open, gapLp())
            controls.addView(turnMode, android.widget.LinearLayout.LayoutParams(wrap, wrap))
            controls.addView(startOver, gapLp())
            controls.addView(switchOff, gapLp())
            turnMode.visibility = android.view.View.GONE
            startOver.visibility = android.view.View.GONE
            switchOff.visibility = android.view.View.GONE

            // Stopping the workout: only in the tall sheet, and it takes two taps, so a thumb
            // cannot do it by passing over it.
            stop.setPadding(px(14f), px(9f), px(14f), px(9f))
            stop.setOnClickListener {
                if (stopArmed) {
                    removeCallbacks(disarm)
                    stopArmed = false
                    // Prism ends the workout and gives the thud for it. With no workout on, the
                    // timer stops floating and nothing of it is left running.
                    channel?.invokeMethod("stop", null)
                    closeSheet(context)
                } else {
                    haptic(context, "click")
                    stopArmed = true
                    stopLook()
                    postDelayed(disarm, 3000)
                }
            }
            stopLook()
            stopRow.gravity = android.view.Gravity.CENTER
            stopRow.addView(stop, android.widget.LinearLayout.LayoutParams(wrap, wrap))

            header.addView(clock)
            header.addView(info)
            header.addView(controls)
            header.addView(stopRow)
            card.addView(header, android.widget.LinearLayout.LayoutParams(fill, wrap))

            // The small sheet shows one set; this bar says which one it is, out of how many.
            val pipsLp = android.widget.LinearLayout.LayoutParams(fill, px(5f))
            pipsLp.topMargin = px(13f)
            pipsLp.leftMargin = px(4f)
            pipsLp.rightMargin = px(4f)
            card.addView(pips, pipsLp)

            rows.orientation = android.widget.LinearLayout.VERTICAL
            val rowsLp = android.widget.LinearLayout.LayoutParams(fill, wrap)
            rowsLp.topMargin = px(12f)
            card.addView(rows, rowsLp)

            done.gravity = android.view.Gravity.CENTER
            done.setOnClickListener {
                // No click here: Prism logs the set and gives the same click it gives on its own page.
                if (current in sets.indices) channel?.invokeMethod("toggle", current)
                // Logging is the errand: the sheet folds away, in either size, and the lens shows the rest.
                closeSheet(context)
            }
            val doneLp = android.widget.LinearLayout.LayoutParams(fill, px(56f))
            doneLp.topMargin = px(10f)
            card.addView(done, doneLp)

            applyMode()
        }

        override fun arrive() {
            super.arrive()
            postDelayed(ticker, 250)
            if (!fullMode) {
                // The arrow lifts once, gently, as the small sheet arrives: there is more above.
                grab.animate().translationY(-4 * dp).setStartDelay(380).setDuration(260).setInterpolator(EASE).withEndAction {
                    grab.animate().translationY(0f).setStartDelay(0).setDuration(420)
                        .setInterpolator(android.view.animation.AccelerateDecelerateInterpolator()).start()
                }.start()
            }
        }

        /** Holding the timer: the row under it offers what else the timer can do, for a few seconds. */
        private fun showOptions() {
            if (timerOff) return
            try {
                context.getSharedPreferences("prism_lens", Context.MODE_PRIVATE).edit().putBoolean("timer_hint_seen", true).apply()
            } catch (e: Exception) {}
            // The small sheet has no room for them: it becomes the tall one first.
            if (!fullMode) resize(true)
            options = true
            removeCallbacks(endOptions)
            postDelayed(endOptions, 6000)
            texts()
        }

        private fun endOptionsNow() {
            removeCallbacks(endOptions)
            options = false
            texts()
        }

        private fun stopLook() {
            val warn = 0xFFE5484D.toInt()
            stop.text = if (stopArmed) "Tap again to stop the workout" else "Stop workout"
            stop.setTextColor(if (stopArmed) warn else muted())
            stop.background = rounded(if (stopArmed) tint(warn, 0x30) else tint(ink(), 0x12), 100 * dp)
        }

        // Where there is no room for the tall sheet (a keyboard is up, say), it is the small one.
        override fun onLayout(changed: Boolean, l: Int, t: Int, r: Int, b: Int) {
            super.onLayout(changed, l, t, r, b)
            if (!fullMode || changing || closing) return
            val at = IntArray(2)
            getLocationOnScreen(at)
            if (at[1] < px(60f)) {
                post {
                    if (fullMode && !changing && !closing) {
                        fullMode = false
                        applyMode()
                    }
                }
            }
        }

        /** Becomes the small sheet or the tall one. The button at the bottom stays as it is throughout. */
        private fun resize(full: Boolean) {
            fullMode = full
            morph(340, listOf(header, pips, rows), emptyList(), done) { applyMode() }
        }

        // Down: the tall sheet becomes the small one; the small one becomes the lens.
        override fun pulledDown() {
            if (fullMode) resize(false) else closeSheet(context)
        }

        override fun pulledUp(): Boolean {
            if (fullMode) return false
            resize(true)
            return true
        }

        override fun tappedGrabber() {
            haptic(context, "tick")
            resize(!fullMode)
        }

        private fun buildRows() {
            rows.removeAllViews()
            rowViews.clear()
            for (i in sets.indices) {
                val root = android.widget.LinearLayout(context)
                root.gravity = android.view.Gravity.CENTER_VERTICAL
                val n = label(context, 15f, ink(), true)
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
        private fun applyMode() {
            val full = fullMode
            // Up while there is a taller sheet to pull out; down once it is out.
            grab.up = !full
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
            val stopLp = android.widget.LinearLayout.LayoutParams(wrap, wrap)
            stopLp.topMargin = px(10f)
            stopRow.layoutParams = stopLp
            stopRow.visibility = if (full) android.view.View.VISIBLE else android.view.View.GONE
            // The tall sheet lists every set. The small one shows one, so it says which: the line
            // under the name is written to be read, and the bar below shows it out of how many.
            pips.visibility = if (full) android.view.View.GONE else android.view.View.VISIBLE
            which.setTextColor(if (full) muted() else ink())
            which.textSize = if (full) 12.5f else 14.5f
            which.typeface = android.graphics.Typeface.create(
                if (full) "sans-serif" else "sans-serif-medium",
                if (full) android.graphics.Typeface.NORMAL else android.graphics.Typeface.BOLD,
            )
            sync()
        }

        private fun texts() {
            // A sheet on its way out stays as it was when it was let go.
            if (closing) return
            val t = reading(System.currentTimeMillis())
            val shown = android.view.View.VISIBLE
            val away = android.view.View.GONE
            // This runs four times a second while the sheet is open. A text is set only when it
            // is a different text: setting the same one again would still lay it out and draw it.
            if (what.text.toString() != t.what) what.text = t.what
            what.setTextColor(if (t.resting || t.paused) accent else muted())
            val turn = if (countUp) "Count down" else "Count up"
            if (turnMode.text.toString() != turn) turnMode.text = turn
            if (!hintSeen) {
                hintSeen = try {
                    context.getSharedPreferences("prism_lens", Context.MODE_PRIVATE).getBoolean("timer_hint_seen", false)
                } catch (e: Exception) { true }
            }
            val seen = hintSeen
            val wantHint = if (fullMode && !seen) shown else away
            // The row under the timer shows what a running rest needs, or, for a few seconds
            // after the timer has been held, what else the timer can do.
            val rest = if (fullMode && !options && t.resting && !t.paused) shown else away
            val more = if (fullMode && options && !t.off) shown else away
            // On Prism's own workout page there is nowhere for "Open workout" to take you.
            val wantOpen = if (options || (this@Floater.foreground && onTrain)) away else shown
            if (add.visibility != rest || turnMode.visibility != more || open.visibility != wantOpen || hint.visibility != wantHint) {
                val fresh = ArrayList<android.view.View>()
                if (rest == shown && add.visibility != shown) { fresh.add(add); fresh.add(skip) }
                if (more == shown && turnMode.visibility != shown) { fresh.add(turnMode); fresh.add(startOver); fresh.add(switchOff) }
                val flip = {
                    add.visibility = rest
                    skip.visibility = rest
                    turnMode.visibility = more
                    startOver.visibility = more
                    switchOff.visibility = more
                    open.visibility = wantOpen
                    hint.visibility = wantHint
                }
                if (fullMode && !changing && isLaidOut) {
                    // The tall sheet may gain or lose a line. The timer keeps its place under the
                    // top edge as that moves, and what is new comes up once there is room for it.
                    morph(260, emptyList(), listOf(clock, info), null, flip)
                    for (v in fresh) {
                        v.alpha = 0f
                        v.animate().alpha(1f).setStartDelay(110).setDuration(180).start()
                    }
                } else {
                    flip()
                }
            }
        }

        override fun sync() {
            // A sheet on its way out stays as it was when it was let go.
            if (closing) return
            if (rowViews.size != sets.size) buildRows()
            val full = fullMode
            pips.invalidate()
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
                r.name.setTextColor(if (i == 0) muted() else ink())
                r.root.visibility = if (full || i == current) android.view.View.VISIBLE else android.view.View.GONE
                r.name.visibility = if (full) android.view.View.VISIBLE else android.view.View.GONE
                r.tick.visibility = if (full) android.view.View.VISIBLE else android.view.View.GONE
                if (full) {
                    r.root.setPadding(px(6f), px(6f), px(4f), px(6f))
                    r.root.background = when {
                        s.done -> rounded(tint(GREEN, 0x1F), 24 * dp)
                        i == current -> rounded(tint(ink(), 0x12), 24 * dp, tint(accent, 0x99), px(1.5f))
                        else -> rounded(tint(ink(), 0x0A), 24 * dp)
                    }
                } else {
                    r.root.setPadding(0, 0, 0, 0)
                    r.root.background = null
                }
            }
            // What it does, and exactly what it will log.
            done.text = if (current in sets.indices) "Set done  \u00B7  " + number(sets[current].kg) + " kg \u00D7 " + sets[current].reps else "Set done"
            done.setTextColor(onAccent)
            done.background = rounded(accent, 100 * dp)
            texts()
            clock.invalidate()
        }
    }

    /**
     * The sheet of a pinned action: the thing itself, done in place, over whatever app is open.
     * Nothing in it runs until it is opened, and nothing is left running when it closes.
     */
    private inner class ActionSheet(context: Context, val index: Int) : Sheet(context) {
        private val title = label(context, 19f, ink(), true)
        private val sub = label(context, 12.5f, muted(), false)
        private val save = label(context, 16.5f, onAccent, true)
        private var dial: Dial? = null

        init {
            val head = android.widget.LinearLayout(context)
            head.gravity = android.view.Gravity.CENTER_VERTICAL
            val names = android.widget.LinearLayout(context)
            names.orientation = android.widget.LinearLayout.VERTICAL
            names.addView(title)
            names.addView(sub, android.widget.LinearLayout.LayoutParams(wrap, wrap).also { it.topMargin = px(3f) })
            head.addView(names, android.widget.LinearLayout.LayoutParams(0, wrap, 1f))
            val open = label(context, 13f, ink(), true)
            // Only where it leads somewhere: inside Prism, the same thing is already at hand.
            open.visibility = if (this@Floater.foreground) android.view.View.GONE else android.view.View.VISIBLE
            open.text = "Open in Prism"
            open.setPadding(px(14f), px(10f), px(14f), px(10f))
            open.background = rounded(tint(ink(), 0x1F), 100 * dp)
            open.setOnClickListener {
                haptic(context, "tick")
                openAction(context, index)
            }
            head.addView(open)
            card.addView(head, android.widget.LinearLayout.LayoutParams(fill, wrap))

            if (index == 3) {
                // Weigh-in: one wide dial in tenths of a kilo, and a button that says what it will save.
                title.text = "Weigh-in"
                val d = Dial(context, "kg", 0.1, 0.1, 20.0, 300.0)
                d.value = Math.round(weight * 10) / 10.0
                d.onChange = { v -> save.text = "Save " + number(v) + " kg" }
                dial = d
                card.addView(d, android.widget.LinearLayout.LayoutParams(fill, px(72f)).also { it.topMargin = px(14f) })
                save.gravity = android.view.Gravity.CENTER
                save.background = rounded(accent, 100 * dp)
                save.setOnClickListener {
                    // Prism saves it and gives the click.
                    channel?.invokeMethod("weigh", d.value)
                    closeSheet(context)
                }
                card.addView(save, android.widget.LinearLayout.LayoutParams(fill, px(56f)).also { it.topMargin = px(12f) })
            } else {
                // Log food: the usual meals, one tap each.
                title.text = "Log food"
                for (m in meals) {
                    val row = android.widget.LinearLayout(context)
                    row.gravity = android.view.Gravity.CENTER_VERTICAL
                    row.background = rounded(tint(ink(), 0x10), 22 * dp)
                    row.setPadding(px(16f), px(9f), px(8f), px(9f))
                    val col = android.widget.LinearLayout(context)
                    col.orientation = android.widget.LinearLayout.VERTICAL
                    val n = label(context, 15.5f, ink(), true)
                    n.text = m.name
                    val w = label(context, 12.5f, muted(), false)
                    w.text = m.what
                    col.addView(n)
                    col.addView(w, android.widget.LinearLayout.LayoutParams(wrap, wrap).also { it.topMargin = px(2f) })
                    row.addView(col, android.widget.LinearLayout.LayoutParams(0, wrap, 1f))
                    val k = label(context, 14f, ink(), true)
                    k.text = m.kcal.toString() + " kcal"
                    row.addView(k, android.widget.LinearLayout.LayoutParams(wrap, wrap).also { it.rightMargin = px(10f) })
                    val plus = label(context, 22f, onAccent, true)
                    plus.text = "+"
                    plus.gravity = android.view.Gravity.CENTER
                    plus.background = rounded(accent, 100 * dp)
                    plus.setOnClickListener {
                        // Prism adds it and gives the click.
                        channel?.invokeMethod("food", m.index)
                    }
                    row.addView(plus, android.widget.LinearLayout.LayoutParams(px(46f), px(46f)))
                    card.addView(row, android.widget.LinearLayout.LayoutParams(fill, wrap).also { it.topMargin = px(8f) })
                }
            }
            sync()
        }

        override fun pulledDown() {
            closeSheet(context)
        }

        override fun sync() {
            val d = dial
            if (d != null) {
                sub.text = "Now " + number(weight) + " kg"
                save.setTextColor(onAccent)
                save.text = "Save " + number(d.value) + " kg"
            } else {
                sub.text = if (kcalLeft >= 0) kcalLeft.toString() + " kcal left today" else (-kcalLeft).toString() + " kcal over today"
            }
        }
    }
}
