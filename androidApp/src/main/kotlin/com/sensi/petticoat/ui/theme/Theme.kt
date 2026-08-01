package com.sensi.petticoat.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Sensi / SMA brand tokens (from Theme.swift)
private val BrandTeal = Color(0xFF006998)
private val BrandNavy = Color(0xFF14435F)
private val Accent = Color(0xFF0088FF)
private val HeatingOrange = Color(0xFFF76707)
private val CoolingBlue = Color(0xFF0093C8)
private val ThermostatCard = Color(0xFF485057)
private val ControlFill = Color(0xFF2C3238)

val SensiHeating = HeatingOrange
val SensiCooling = CoolingBlue
val SensiThermostatSurface = ThermostatCard
val SensiControlFill = ControlFill

private val LightColors = lightColorScheme(
    primary = BrandTeal,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFB3D9EC),
    onPrimaryContainer = BrandNavy,
    secondary = Accent,
    onSecondary = Color.White,
    tertiary = HeatingOrange,
    onTertiary = Color.White,
    background = Color(0xFFF2F2F7),
    onBackground = Color(0xFF1C1C1E),
    surface = Color.White,
    onSurface = Color(0xFF1C1C1E),
    surfaceVariant = Color(0xFFE5E5EA),
    onSurfaceVariant = Color(0xFF3C3C43),
    error = Color(0xFFFF3B30),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFF8FB8CE),
    onPrimary = BrandNavy,
    primaryContainer = BrandTeal,
    onPrimaryContainer = Color.White,
    secondary = Color(0xFF0A84FF),
    onSecondary = Color.White,
    tertiary = HeatingOrange,
    onTertiary = Color.White,
    background = Color(0xFF000000),
    onBackground = Color.White,
    surface = Color(0xFF1C1C1E),
    onSurface = Color.White,
    surfaceVariant = Color(0xFF2C2C2E),
    onSurfaceVariant = Color(0xFFEBEBF5),
    error = Color(0xFFFF453A),
)

@OptIn(ExperimentalMaterial3ExpressiveApi::class)
@Composable
fun PetticoatTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialExpressiveTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        motionScheme = MotionScheme.expressive(),
        content = content,
    )
}
