package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.UsageEntry
import com.sensi.petticoat.model.UsageMode
import com.sensi.petticoat.model.UsageRange
import com.sensi.petticoat.model.UsageSample
import com.sensi.petticoat.model.formatUsageDuration

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageScreen(model: AppModel, state: AppState, onBack: () -> Unit) {
    var range by remember { mutableStateOf(UsageRange.Recent) }
    var expanded by remember { mutableStateOf<Set<String>>(emptySet()) }
    val history = remember { UsageSample.history() }
    val periods = if (range == UsageRange.Recent) history.recent else history.monthly

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Usage") },
                navigationIcon = { IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back") } },
                actions = {
                    UsageRange.entries.forEach {
                        FilterChip(
                            selected = range == it,
                            onClick = { range = it },
                            label = { Text(it.label) },
                            modifier = Modifier.testTag("usage-range-${it.name.lowercase()}"),
                        )
                    }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            Modifier.fillMaxSize().padding(padding).padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            periods.forEach { period ->
                item { Text(period.name, style = MaterialTheme.typography.titleMedium) }
                items(period.entries, key = { it.id }) { entry ->
                    UsageCard(
                        entry,
                        expanded = entry.id in expanded,
                        onToggle = { expanded = if (entry.id in expanded) expanded - entry.id else expanded + entry.id },
                        onHelp = { model.setShowHelp(true) },
                    )
                }
            }
        }
    }
}

@Composable
private fun UsageCard(entry: UsageEntry, expanded: Boolean, onToggle: () -> Unit, onHelp: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().testTag(if (entry.insufficient) "usage-entry-insufficient" else "usage-entry-row"),
    ) {
        Column(
            Modifier.clickable(enabled = !entry.insufficient, onClick = onToggle).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(entry.title)
                Text(if (entry.insufficient) "Insufficient data" else formatUsageDuration(entry.totalRuntimeMinutes))
            }
            if (entry.insufficient) {
                TextButton(onClick = onHelp, modifier = Modifier.testTag("usage-learn-more")) { Text("Learn more") }
            } else {
                UsageBar(entry)
                if (expanded) {
                    UsageMode.entries.forEach { mode ->
                        Row(
                            Modifier.fillMaxWidth().testTag("usage-breakdown-${mode.name.lowercase()}"),
                            horizontalArrangement = Arrangement.SpaceBetween,
                        ) {
                            Text(mode.label)
                            Text(formatUsageDuration(entry.minutes[mode] ?: 0))
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun UsageBar(entry: UsageEntry) {
    val colors = mapOf(
        UsageMode.Cool to Color(0xFF0093C8),
        UsageMode.Heat to Color(0xFFF76707),
        UsageMode.Aux to Color(0xFFE61234),
        UsageMode.Fan to Color(0xFFC5B1C2),
    )
    Canvas(Modifier.fillMaxWidth().height(14.dp)) {
        var x = 0f
        UsageMode.entries.forEach { mode ->
            val width = size.width * entry.fraction(mode)
            drawRect(colors.getValue(mode), Offset(x, 0f), Size(width, size.height))
            x += width
        }
        if (x < size.width) drawRect(Color(0xFFE5E5EA), Offset(x, 0f), Size(size.width - x, size.height))
    }
}
