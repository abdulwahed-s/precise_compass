/*
 * MIT License — part of precise_compass.
 */
package com.precisecompass.precise_compass

import android.content.Context
import android.hardware.GeomagneticField
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.location.Location
import android.location.LocationManager
import android.view.Display
import android.view.Surface
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Acquires raw heading data and emits a versioned payload over an event
 * channel. All sensor fusion / accuracy / calibration logic lives in pure Dart;
 * this layer only delivers the highest-fidelity raw signals the device offers,
 * including [SensorEvent.values]`[4]` (estimated heading accuracy, radians) and
 * the magnetic-field magnitude used for interference detection.
 */
class PreciseCompassPlugin :
    FlutterPlugin,
    EventChannel.StreamHandler,
    MethodChannel.MethodCallHandler {

    private var eventChannel: EventChannel? = null
    private var methodChannel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var sensorManager: SensorManager? = null
    private var display: Display? = null

    private var rotationSensor: Sensor? = null
    private var geomagneticRotationSensor: Sensor? = null
    private var accelerometer: Sensor? = null
    private var magnetometer: Sensor? = null
    private var gyroscope: Sensor? = null

    private var listener: SensorEventListener? = null
    private var eventSink: EventChannel.EventSink? = null

    private var activeVectorSensor: Sensor? = null
    private var activeSourceCode: Int = SOURCE_UNAVAILABLE
    private var samplingPeriodUs: Int = DEFAULT_PERIOD_US
    private var declinationDegrees: Double? = null

    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false
    private var fieldMagnitude: Double? = null
    private var osAccuracyStatus: Int = -1

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        sensorManager =
            applicationContext?.getSystemService(Context.SENSOR_SERVICE)
                as? SensorManager
        display = (applicationContext?.getSystemService(Context.DISPLAY_SERVICE)
            as? DisplayManager)?.getDisplay(Display.DEFAULT_DISPLAY)

        sensorManager?.let { sm ->
            rotationSensor = sm.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            geomagneticRotationSensor =
                sm.getDefaultSensor(Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR)
            accelerometer = sm.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            magnetometer = sm.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
            gyroscope = sm.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
        }

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL).apply {
            setStreamHandler(this@PreciseCompassPlugin)
        }
        methodChannel =
            MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).apply {
                setMethodCallHandler(this@PreciseCompassPlugin)
            }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        unregister()
        eventChannel?.setStreamHandler(null)
        methodChannel?.setMethodCallHandler(null)
        eventChannel = null
        methodChannel = null
        sensorManager = null
        applicationContext = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCapabilities" -> result.success(capabilities())
            else -> result.notImplemented()
        }
    }

    private fun capabilities(): Map<String, Any> {
        val hasRv = rotationSensor != null
        val hasGeo = geomagneticRotationSensor != null
        val hasMag = magnetometer != null
        val hasAccel = accelerometer != null
        return mapOf(
            "hasRotationVector" to hasRv,
            "hasGeomagneticRotationVector" to hasGeo,
            "hasMagnetometer" to hasMag,
            "hasGyroscope" to (gyroscope != null),
            "hasAccelerometer" to hasAccel,
            "supportsTrueHeading" to (hasRv || hasGeo || (hasMag && hasAccel)),
        )
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        configure(arguments)
        if (!register()) {
            events?.success(unavailablePayload())
        }
    }

    override fun onCancel(arguments: Any?) {
        unregister()
        eventSink = null
    }

    @Suppress("UNCHECKED_CAST")
    private fun configure(arguments: Any?) {
        val args = arguments as? Map<String, Any?> ?: emptyMap()
        samplingPeriodUs = when (args["rate"] as? String) {
            "fastest" -> 5_000
            "ui" -> 16_000
            "normal" -> 33_000
            "batterySaving" -> 100_000
            else -> DEFAULT_PERIOD_US
        }
        selectSource(args["fusionMode"] as? String ?: "auto")
        declinationDegrees = computeDeclination()
    }

    private fun selectSource(mode: String) {
        activeVectorSensor = when (mode) {
            "geomagnetic" -> geomagneticRotationSensor ?: rotationSensor
            "rotationVector" -> rotationSensor ?: geomagneticRotationSensor
            else -> rotationSensor ?: geomagneticRotationSensor
        }
        activeSourceCode = when {
            activeVectorSensor?.type == Sensor.TYPE_ROTATION_VECTOR ->
                SOURCE_ROTATION_VECTOR
            activeVectorSensor != null -> SOURCE_GEOMAGNETIC
            accelerometer != null && magnetometer != null -> SOURCE_GEOMAGNETIC
            else -> SOURCE_UNAVAILABLE
        }
    }

    private fun register(): Boolean {
        val sm = sensorManager ?: return false
        val newListener = CompassListener()
        listener = newListener
        val vector = activeVectorSensor
        return when {
            vector != null -> {
                sm.registerListener(newListener, vector, samplingPeriodUs)
                magnetometer?.let {
                    sm.registerListener(newListener, it, samplingPeriodUs)
                }
                true
            }
            accelerometer != null && magnetometer != null -> {
                sm.registerListener(newListener, accelerometer, samplingPeriodUs)
                sm.registerListener(newListener, magnetometer, samplingPeriodUs)
                true
            }
            else -> false
        }
    }

    private fun unregister() {
        listener?.let { sensorManager?.unregisterListener(it) }
        listener = null
        hasGravity = false
        hasGeomagnetic = false
        fieldMagnitude = null
        osAccuracyStatus = -1
    }

    private fun computeDeclination(): Double? {
        val ctx = applicationContext ?: return null
        return try {
            val lm = ctx.getSystemService(Context.LOCATION_SERVICE)
                as? LocationManager ?: return null
            val providers = listOf(
                LocationManager.GPS_PROVIDER,
                LocationManager.NETWORK_PROVIDER,
                LocationManager.PASSIVE_PROVIDER,
            )
            var best: Location? = null
            for (provider in providers) {
                val location = lm.getLastKnownLocation(provider) ?: continue
                if (best == null || location.time > best.time) best = location
            }
            best?.let {
                GeomagneticField(
                    it.latitude.toFloat(),
                    it.longitude.toFloat(),
                    it.altitude.toFloat(),
                    it.time,
                ).declination.toDouble()
            }
        } catch (e: SecurityException) {
            null // No location permission: magnetic heading only.
        } catch (e: Exception) {
            null
        }
    }

    private fun displayRotation(): Int = display?.rotation ?: Surface.ROTATION_0

    private inner class CompassListener : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            when (event.sensor.type) {
                Sensor.TYPE_ROTATION_VECTOR,
                Sensor.TYPE_GEOMAGNETIC_ROTATION_VECTOR -> {
                    if (event.sensor == activeVectorSensor) emitFromVector(event)
                }
                Sensor.TYPE_MAGNETIC_FIELD -> {
                    fieldMagnitude = CompassMath.magnitude(event.values).toDouble()
                    if (activeVectorSensor == null) {
                        System.arraycopy(event.values, 0, geomagnetic, 0, 3)
                        hasGeomagnetic = true
                        emitFromAccelMag()
                    }
                }
                Sensor.TYPE_ACCELEROMETER -> {
                    if (activeVectorSensor == null) {
                        System.arraycopy(event.values, 0, gravity, 0, 3)
                        hasGravity = true
                        emitFromAccelMag()
                    }
                }
            }
        }

        override fun onAccuracyChanged(sensor: Sensor, accuracy: Int) {
            if (sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
                osAccuracyStatus = accuracy
            }
        }
    }

    private fun emitFromVector(event: SensorEvent) {
        val orientation = CompassMath.orientationFromRotationVector(
            CompassMath.safeRotationVector(event.values),
            displayRotation(),
        )
        // values[4] = estimated heading accuracy in radians (rotation vector).
        val accuracyDegrees =
            if (event.values.size >= 5 && event.values[4] >= 0f) {
                Math.toDegrees(event.values[4].toDouble())
            } else {
                -1.0
            }
        emit(CompassMath.azimuthDegrees(orientation.azimuthRadians), accuracyDegrees, orientation)
    }

    private fun emitFromAccelMag() {
        if (!hasGravity || !hasGeomagnetic) return
        val orientation = CompassMath.orientationFromAccelMag(
            gravity,
            geomagnetic,
            displayRotation(),
        ) ?: return
        emit(CompassMath.azimuthDegrees(orientation.azimuthRadians), -1.0, orientation)
    }

    private fun emit(
        magneticHeading: Double,
        accuracyDegrees: Double,
        orientation: Orientation,
    ) {
        val sink = eventSink ?: return
        if (magneticHeading.isNaN()) return
        val payload = HashMap<String, Any?>()
        payload["source"] = activeSourceCode
        payload["magneticHeading"] = magneticHeading
        declinationDegrees?.let {
            payload["trueHeading"] = (magneticHeading + it + 360.0) % 360.0
        }
        payload["accuracyDegrees"] = accuracyDegrees
        payload["osAccuracyStatus"] = osAccuracyStatus
        fieldMagnitude?.let { payload["magneticFieldMagnitude"] = it }
        payload["pitch"] = Math.toDegrees(orientation.pitchRadians.toDouble())
        payload["roll"] = Math.toDegrees(orientation.rollRadians.toDouble())
        payload["timestamp"] = System.currentTimeMillis()
        sink.success(payload)
    }

    private fun unavailablePayload(): Map<String, Any?> = mapOf(
        "source" to SOURCE_UNAVAILABLE,
        "accuracyDegrees" to -1.0,
        "timestamp" to System.currentTimeMillis(),
    )

    companion object {
        private const val EVENT_CHANNEL = "precise_compass/events"
        private const val METHOD_CHANNEL = "precise_compass/methods"
        private const val DEFAULT_PERIOD_US = 16_000
        private const val SOURCE_ROTATION_VECTOR = 0
        private const val SOURCE_GEOMAGNETIC = 1
        private const val SOURCE_UNAVAILABLE = -1
    }
}
