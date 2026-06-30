/*
 * MIT License — part of precise_compass.
 *
 * A clean-room implementation of the standard Android orientation pipeline
 * (getRotationMatrixFromVector -> remapCoordinateSystem -> getOrientation).
 */
package com.precisecompass.precise_compass

import android.hardware.SensorManager
import android.view.Surface
import kotlin.math.sqrt

/** Device orientation angles, in radians, as returned by `getOrientation`. */
internal data class Orientation(
    val azimuthRadians: Float,
    val pitchRadians: Float,
    val rollRadians: Float,
)

internal object CompassMath {
    private const val MATRIX_SIZE = 9
    private const val ORIENTATION_SIZE = 3

    /**
     * Returns the axis pair to feed [SensorManager.remapCoordinateSystem] so the
     * azimuth stays correct for the given display [rotation] (a [Surface]
     * constant).
     */
    private fun remapAxes(rotation: Int): Pair<Int, Int> = when (rotation) {
        Surface.ROTATION_90 ->
            SensorManager.AXIS_Y to SensorManager.AXIS_MINUS_X
        Surface.ROTATION_180 ->
            SensorManager.AXIS_MINUS_X to SensorManager.AXIS_MINUS_Y
        Surface.ROTATION_270 ->
            SensorManager.AXIS_MINUS_Y to SensorManager.AXIS_X
        else -> SensorManager.AXIS_X to SensorManager.AXIS_Y
    }

    private fun orientationFromMatrix(
        rotationMatrix: FloatArray,
        displayRotation: Int,
    ): Orientation {
        val (axisX, axisY) = remapAxes(displayRotation)
        val remapped = FloatArray(MATRIX_SIZE)
        SensorManager.remapCoordinateSystem(rotationMatrix, axisX, axisY, remapped)
        val angles = FloatArray(ORIENTATION_SIZE)
        SensorManager.getOrientation(remapped, angles)
        return Orientation(angles[0], angles[1], angles[2])
    }

    /** Orientation from a rotation-vector sensor sample. */
    fun orientationFromRotationVector(
        rotationVector: FloatArray,
        displayRotation: Int,
    ): Orientation {
        val rotationMatrix = FloatArray(MATRIX_SIZE)
        SensorManager.getRotationMatrixFromVector(rotationMatrix, rotationVector)
        return orientationFromMatrix(rotationMatrix, displayRotation)
    }

    /** Orientation fused from accelerometer + magnetometer (no gyro). */
    fun orientationFromAccelMag(
        gravity: FloatArray,
        geomagnetic: FloatArray,
        displayRotation: Int,
    ): Orientation? {
        val rotationMatrix = FloatArray(MATRIX_SIZE)
        val inclination = FloatArray(MATRIX_SIZE)
        val ok = SensorManager.getRotationMatrix(
            rotationMatrix,
            inclination,
            gravity,
            geomagnetic,
        )
        if (!ok) return null
        return orientationFromMatrix(rotationMatrix, displayRotation)
    }

    /** Euclidean magnitude of a 3-vector (e.g. magnetic field strength, µT). */
    fun magnitude(values: FloatArray): Float =
        sqrt(values[0] * values[0] + values[1] * values[1] + values[2] * values[2])

    /** Converts a radians azimuth to degrees normalized to `[0, 360)`. */
    fun azimuthDegrees(azimuthRadians: Float): Double {
        val degrees = Math.toDegrees(azimuthRadians.toDouble())
        return (degrees + 360.0) % 360.0
    }

    /**
     * Truncates a rotation vector to at most four elements. Some older Samsung
     * devices throw from getRotationMatrixFromVector when the vector is longer
     * (see crbug.com/335298).
     */
    fun safeRotationVector(values: FloatArray): FloatArray =
        if (values.size > 4) values.copyOfRange(0, 4) else values
}
