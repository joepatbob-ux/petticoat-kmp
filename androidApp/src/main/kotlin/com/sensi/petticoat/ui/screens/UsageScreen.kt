package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilledTonalButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.AppModel
import com.sensi.petticoat.AppState
import com.sensi.petticoat.model.UsageSample
import com.sensi.petticoat.ui.theme.SensiAux
import com.sensi.petticoat.ui.theme.SensiCooling
import com.sensi.petticoat.ui.theme.SensiFanPurple
import com.sensi.petticoat.ui.theme.SensiHeating

/**
 * Usage tab, built to the Android Expressive Figma ("Usage - Recent", 63:81695): a
 * Recent / Monthly Archive tab row, month-grouped rows with a stacked runtime bar
 * (Cool/Heat/AUX/Fan), a per-group Show/Hide Details toggle revealing per-mode durations,
 * and a legend. Backed by the shared UsageSample data.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun UsageScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    var tab by remember { mutableIntStateOf(0) }
    val expandedGroups = remember { mutableStateMapOf<String, Boolean>() }

    val samples = if (tab == 0) state.usageRecent else state.usageMonthly
    val grouped = samples.groupBy { it.monthGroup }

    Scaffold(
        topBar = {
            CenterAlignedTopAppBar(
                title = { Text("Usage") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                colors = TopAppBarDefaults.centerAlignedTopAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(modifier = Modifier.fillMaxSize().padding(padding)) {
            TabRow(selectedTabIndex = tab, containerColor = MaterialTheme.colorScheme.background) {
                Tab(selected = tab == 0, onClick = { tab = 0 }, text = { Text("Recent") })
                Tab(selected = tab == 1, onClick = { tab = 1 }, text = { Text("Monthly Archive") })
            }
            LazyColumn(modifier = Modifier.fillMaxSize()) {
                grouped.forEach { (group, rows) ->
                    val expanded = expandedGroups[group] ?: false
                    item(key = "header-$group") {
                        GroupHeader(
                            title = group,
                            expanded = expanded,
                            onToggle = { expandedGroups[group] = !expanded },
                        )
                    }
                    items(rows.size, key = { rows[it].id }) { i ->
                        DataRow(rows[i], expanded)
                    }
                    item(key = "legend-$group") { UsageLegend() }
                }
            }
        }
    }
}

@Composable
private fun GroupHeader(title: String, expanded: Boolean, onToggle: () -> Unit) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 24.dp, top = 18.dp, bottom = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            title,
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.Medium,
        )
        FilledTonalButton(onClick = onToggle) {
            Text(if (expanded) "Hide Details" else "Show Details")
        }
    }
}

@Composable
private fun DataRow(sample: UsageSample, expanded: Boolean) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    sample.label,
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                Text(
                    sample.keepText,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Text(
                sample.asOf,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        UsageBar(sample)
        if (expanded && sample.hasData) {
            DetailsRow(sample)
        }
    }
}

@Composable
private fun UsageBar(sample: UsageSample) {
    val segments = listOf(
        sample.coolMinutes to SensiCooling,
        sample.heatMinutes to SensiHeating,
        sample.auxMinutes to SensiAux,
        sample.fanMinutes to SensiFanPurple,
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 24.dp, top = 4.dp, bottom = 12.dp)
            .height(12.dp)
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant),
    ) {
        if (sample.hasData && sample.totalMinutes > 0) {
            segments.forEach { (minutes, color) ->
                if (minutes > 0) {
                    Box(
                        modifier = Modifier
                            .weight(minutes.toFloat())
                            .fillMaxHeight()
                            .background(color),
                    )
                }
            }
        }
    }
}

@Composable
private fun DetailsRow(sample: UsageSample) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(start = 16.dp, end = 24.dp, bottom = 12.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        DetailItem("Cooling", sample.coolMinutes, SensiCooling)
        DetailItem("Heating", sample.heatMinutes, SensiHeating)
        DetailItem("AUX Heating", sample.auxMinutes, SensiAux)
        DetailItem("Fan Only", sample.fanMinutes, SensiFanPurple)
    }
}

@Composable
private fun DetailItem(label: String, minutes: Int, color: Color) {
    Column {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = color,
        )
        Text(
            formatDuration(minutes),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}

@Composable
private fun UsageLegend() {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, top = 8.dp, bottom = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        LegendItem("Cooling", SensiCooling)
        LegendItem("Heating", SensiHeating)
        LegendItem("AUX Heating", SensiAux)
        LegendItem("Fan Only", SensiFanPurple)
    }
    HorizontalDivider(color = MaterialTheme.colorScheme.surfaceVariant)
}

@Composable
private fun LegendItem(label: String, color: Color) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(5.dp)) {
        Box(modifier = Modifier.size(8.dp).clip(CircleShape).background(color))
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = MaterialTheme.colorScheme.onSurface,
        )
    }
}

private fun formatDuration(minutes: Int): String {
    val h = minutes / 60
    val m = minutes % 60
    return if (h > 0) "${h}h ${m}m" else "${m}m"
}
