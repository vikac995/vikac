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
        // Which phone this is, for the test report.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lumen/device").setMethodCallHandler { call, result ->
            if (call.method == "info") {
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
