package com.sensi.petticoat.ui

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.Route
import com.sensi.petticoat.ui.screens.ControlScreen
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
    }
}

@Composable
private fun MainNav(model: AppModel, state: AppState) {
    val selectedId = state.selectedDeviceId
    if (selectedId != null && state.devices.any { it.id == selectedId }) {
        ControlScreen(
            model = model,
            state = state,
            onBack = model::clearSelectedDevice,
        )
    } else {
        DashboardScreen(
            model = model,
            state = state,
            onOpenDevice = model::selectDevice,
        )
    }
}
