package com.sensi.petticoat.ui.components

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.AcUnit
import androidx.compose.material.icons.outlined.Bed
import androidx.compose.material.icons.outlined.DarkMode
import androidx.compose.material.icons.outlined.FitnessCenter
import androidx.compose.material.icons.outlined.LocalFireDepartment
import androidx.compose.material.icons.outlined.Nightlight
import androidx.compose.material.icons.outlined.WbSunny
import androidx.compose.material.icons.outlined.Work
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * Bridges the iOS SF Symbol names stored in shared models (e.g. "house.fill") to Material
 * icons for Android rendering. Stored symbol strings stay in SF-Symbol form so the shared
 * models remain compatible with the iOS app.
 */
data class SymbolChoice(val sfName: String, val icon: ImageVector)

/** The palette offered in the activity-profile symbol picker. */
val PROFILE_SYMBOLS: List<SymbolChoice> = listOf(
    SymbolChoice("house.fill", Icons.Filled.Home),
    SymbolChoice("person.fill", Icons.Filled.Person),
    SymbolChoice("bed.double.fill", Icons.Outlined.Bed),
    SymbolChoice("dumbbell.fill", Icons.Outlined.FitnessCenter),
    SymbolChoice("sun.max.fill", Icons.Outlined.WbSunny),
    SymbolChoice("moon.fill", Icons.Outlined.DarkMode),
    SymbolChoice("snowflake", Icons.Outlined.AcUnit),
    SymbolChoice("flame.fill", Icons.Outlined.LocalFireDepartment),
    SymbolChoice("briefcase.fill", Icons.Outlined.Work),
    SymbolChoice("star.fill", Icons.Filled.Star),
    SymbolChoice("heart.fill", Icons.Filled.Favorite),
    SymbolChoice("moon.stars.fill", Icons.Outlined.Nightlight),
)

/** Extra aliases so sample data using other SF names still renders sensibly. */
private val SYMBOL_ALIASES: Map<String, ImageVector> = mapOf(
    "figure.walk" to Icons.Filled.Person,
    "figure.run" to Icons.Filled.Person,
)

fun iconForSymbol(sfName: String): ImageVector =
    PROFILE_SYMBOLS.firstOrNull { it.sfName == sfName }?.icon
        ?: SYMBOL_ALIASES[sfName]
        ?: Icons.Filled.Home

/** The six preset colors offered in the profile color picker (RGB, no alpha). */
val PROFILE_COLORS: List<Long> = listOf(
    0x30B0C7, 0xFF9500, 0xAF52DE, 0xFF3B30, 0x34C759, 0x0088FF,
)

/** Converts a stored RGB [colorHex] (no alpha) into an opaque Compose [Color]. */
fun composeColor(colorHex: Long): Color = Color(0xFF000000L or colorHex)
