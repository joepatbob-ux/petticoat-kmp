package com.sensi.petticoat.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.Route
import com.sensi.petticoat.ui.device.DeviceScaffold
import com.sensi.petticoat.ui.navigation.GlobalSheets
import com.sensi.petticoat.ui.screens.DashboardScreen
import com.sensi.petticoat.ui.screens.LoginScreen
import com.sensi.petticoat.ui.screens.SplashScreen

@Composable
fun PetticoatApp(model: AppModel, state: AppState) {
    Surface(modifier = Modifier.fillMaxSize()) {
        AnimatedContent(
            targetState = state.route,
            transitionSpec = { fadeIn() togetherWith fadeOut() },
            label = "route",
        ) { route ->
            when (route) {
                Route.Splash -> SplashScreen()
                Route.Login -> LoginScreen(onLogin = model::signIn)
                Route.Main -> MainNav(model = model, state = state)
            }
        }
        GlobalSheets(model, state)
    }
}

@Composable
private fun MainNav(model: AppModel, state: AppState) {
    val selectedId = state.selectedDeviceId
    val hasSelection = selectedId != null && state.devices.any { it.id == selectedId }
    BoxWithConstraints {
        val expanded = maxWidth >= 840.dp
        if (expanded && hasSelection) {
            Row(Modifier.fillMaxSize()) {
                androidx.compose.foundation.layout.Box(Modifier.width(360.dp)) {
                    DashboardScreen(model, state, model::selectDevice)
                }
                androidx.compose.foundation.layout.Box(Modifier.fillMaxSize()) {
                    DeviceScaffold(model, state, model::clearSelectedDevice)
                }
            }
        } else if (hasSelection) {
            DeviceScaffold(model, state, model::clearSelectedDevice)
        } else {
            DashboardScreen(model, state, model::selectDevice)
        }
    }
}
