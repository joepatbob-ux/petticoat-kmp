package com.sensi.petticoat.ui.screens

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.tooling.preview.Preview
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.ui.screens.reminders.RemindersScreen
import com.sensi.petticoat.ui.screens.schedule.ScheduleScreen
import com.sensi.petticoat.ui.screens.settings.SettingsScreen
import com.sensi.petticoat.ui.theme.PetticoatTheme

@Preview(name = "Schedule", showBackground = true)
@Composable
private fun SchedulePreview() = FeaturePreview { model ->
    ScheduleScreen(model, model.snapshot) {}
}

@Preview(name = "Reminders", showBackground = true)
@Composable
private fun RemindersPreview() = FeaturePreview { model ->
    RemindersScreen(model, model.snapshot) {}
}

@Preview(name = "Settings", showBackground = true)
@Composable
private fun SettingsPreview() = FeaturePreview { model ->
    SettingsScreen(model, model.snapshot) {}
}

@Composable
private fun FeaturePreview(content: @Composable (AppModel) -> Unit) {
    val model = remember { AppModel() }
    PetticoatTheme { content(model) }
}
