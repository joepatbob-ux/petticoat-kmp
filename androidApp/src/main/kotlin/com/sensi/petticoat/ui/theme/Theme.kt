package com.sensi.petticoat.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.ExperimentalMaterial3ExpressiveApi
import androidx.compose.material3.MaterialExpressiveTheme
import androidx.compose.material3.MotionScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Color roles synced from the Petticoat Android Expressive Figma ("Flow (Light)"
// Schemes/* variables). Dark is a derived counterpart in the same hue family.
private val HeatingOrange = Color(0xFFF76707)
private val CoolingBlue = Color(0xFF0093C8) // Figma System Mode/Cooling Blue
private val FanPurple = Color(0xFFC5B1C2) // Figma System Mode/Fan Purple

// Kept for the (currently dark) Control surface until it is restyled to the Figma light design.
private val ThermostatCard = Color(0xFF485057)
private val ControlFill = Color(0xFF2C3238)

val SensiHeating = HeatingOrange
val SensiCooling = CoolingBlue
val SensiFanPurple = FanPurple
val SensiThermostatSurface = ThermostatCard
val SensiControlFill = ControlFill

private val LightColors = lightColorScheme(
    primary = Color(0xFF485E92),
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFDAE2FF),
    onPrimaryContainer = Color(0xFF001B3E),
    secondary = Color(0xFF575E71),
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFD9DFF6),
    onSecondaryContainer = Color(0xFF404659),
    tertiary = Color(0xFF725572),
    onTertiary = Color(0xFFFFFFFF),
    background = Color(0xFFFAF8FF),
    onBackground = Color(0xFF1A1B21),
    surface = Color(0xFFFFFFFF),
    onSurface = Color(0xFF1A1B21),
    surfaceVariant = Color(0xFFE1E2EC),
    onSurfaceVariant = Color(0xFF44464F),
    outline = Color(0xFF757780),
    error = Color(0xFFBA1A1A),
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFB0C6FF),
    onPrimary = Color(0xFF16305F),
    primaryContainer = Color(0xFF2F4678),
    onPrimaryContainer = Color(0xFFDAE2FF),
    secondary = Color(0xFFC0C6DC),
    onSecondary = Color(0xFF2A3042),
    secondaryContainer = Color(0xFF404659),
    onSecondaryContainer = Color(0xFFD9DFF6),
    tertiary = Color(0xFFE0BBDD),
    onTertiary = Color(0xFF412742),
    background = Color(0xFF111318),
    onBackground = Color(0xFFE2E2E9),
    surface = Color(0xFF1B1B21),
    onSurface = Color(0xFFE2E2E9),
    surfaceVariant = Color(0xFF44464F),
    onSurfaceVariant = Color(0xFFC4C6D0),
    outline = Color(0xFF8E9099),
    error = Color(0xFFFFB4AB),
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
