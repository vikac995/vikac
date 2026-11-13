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

    // The home button was pressed while Prism is the home screen: tell the app, so it can go back to its first page.
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        if (intent.hasCategory(android.content.Intent.CATEGORY_HOME)) {
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
                    val i = packageManager.getLaunchIntentForPackage(call.arguments as String)
                    if (i != null) startActivity(i)
                    result.success(i != null)
                }
                else -> result.notImplemented()
            }
        }
        // Which phone this is, for the test report.
        device = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/device")
        device!!.setMethodCallHandler { call, result ->
            if (call.method == "battery") {
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
