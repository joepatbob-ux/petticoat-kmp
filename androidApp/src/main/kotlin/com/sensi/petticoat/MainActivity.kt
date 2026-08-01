package com.sensi.petticoat

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import com.sensi.petticoat.ui.PetticoatApp
import com.sensi.petticoat.ui.theme.PetticoatTheme
import kotlinx.coroutines.delay

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            PetticoatTheme {
                val vm: PetticoatViewModel = viewModel()
                val state by vm.model.state.collectAsStateWithLifecycle()
                SplashAdvance(state.route == Route.Splash) { vm.model.finishSplash() }
                PetticoatApp(model = vm.model, state = state)
            }
        }
    }
}

@Composable
private fun SplashAdvance(isSplash: Boolean, onDone: () -> Unit) {
    LaunchedEffect(isSplash) {
        if (isSplash) {
            delay(900)
            onDone()
        }
    }
}
