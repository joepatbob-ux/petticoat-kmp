package com.sensi.petticoat.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.MoreVert
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
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
import com.sensi.petticoat.model.ActivityProfile
import com.sensi.petticoat.model.SetpointConfig
import com.sensi.petticoat.ui.components.PROFILE_COLORS
import com.sensi.petticoat.ui.components.PROFILE_SYMBOLS
import com.sensi.petticoat.ui.components.RowDivider
import com.sensi.petticoat.ui.components.SectionHeader
import com.sensi.petticoat.ui.components.SettingsCard
import com.sensi.petticoat.ui.components.StepperRow
import com.sensi.petticoat.ui.components.composeColor
import com.sensi.petticoat.ui.components.iconForSymbol

/**
 * Activity Profiles list + editor. Port of iOS `ActivityProfiles.swift`.
 * Backed by shared activityProfiles / saveProfile / deleteProfile / duplicateProfile /
 * activateProfile.
 */
@Composable
fun ActivityProfilesScreen(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
) {
    var editing by remember { mutableStateOf<ActivityProfile?>(null) }

    val target = editing
    if (target != null) {
        ProfileEditor(
            initial = target,
            onSave = {
                model.saveProfile(it)
                editing = null
            },
            onBack = { editing = null },
        )
        return
    }

    ProfilesList(
        model = model,
        state = state,
        onBack = onBack,
        onEdit = { editing = it },
        onNew = { editing = ActivityProfile.newBlank() },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfilesList(
    model: AppModel,
    state: AppState,
    onBack: () -> Unit,
    onEdit: (ActivityProfile) -> Unit,
    onNew: () -> Unit,
) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Activity Profiles") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Back")
                    }
                },
                actions = {
                    IconButton(onClick = onNew) {
                        Icon(Icons.Outlined.Add, contentDescription = "New profile")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
        ) {
            SettingsCard {
                state.activityProfiles.forEachIndexed { index, profile ->
                    if (index > 0) RowDivider()
                    ProfileRow(
                        profile = profile,
                        onEdit = { onEdit(profile) },
                        onActivate = { model.activateProfile(profile) },
                        onDuplicate = { model.duplicateProfile(profile) },
                        onDelete = { model.deleteProfile(profile.id) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ProfileRow(
    profile: ActivityProfile,
    onEdit: () -> Unit,
    onActivate: () -> Unit,
    onDuplicate: () -> Unit,
    onDelete: () -> Unit,
) {
    var menuOpen by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onEdit)
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ProfileIcon(profile)
        Spacer(Modifier.size(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                profile.name.ifBlank { "Untitled" },
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Text(
                "${profile.subtitle} · ${profile.rangeText}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        IconButton(onClick = { menuOpen = true }) {
            Icon(Icons.Outlined.MoreVert, contentDescription = "More")
        }
        DropdownMenu(expanded = menuOpen, onDismissRequest = { menuOpen = false }) {
            DropdownMenuItem(text = { Text("Activate") }, onClick = { onActivate(); menuOpen = false })
            DropdownMenuItem(text = { Text("Duplicate") }, onClick = { onDuplicate(); menuOpen = false })
            DropdownMenuItem(text = { Text("Delete") }, onClick = { onDelete(); menuOpen = false })
        }
    }
}

@Composable
private fun ProfileIcon(profile: ActivityProfile, size: Int = 40) {
    Box(
        modifier = Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(composeColor(profile.colorHex)),
        contentAlignment = Alignment.Center,
    ) {
        Icon(
            iconForSymbol(profile.symbol),
            contentDescription = null,
            tint = Color.White,
            modifier = Modifier.size((size * 0.55).dp),
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ProfileEditor(
    initial: ActivityProfile,
    onSave: (ActivityProfile) -> Unit,
    onBack: () -> Unit,
) {
    var name by remember(initial.id) { mutableStateOf(initial.name) }
    var symbol by remember(initial.id) { mutableStateOf(initial.symbol) }
    var colorHex by remember(initial.id) { mutableStateOf(initial.colorHex) }
    var heatTo by remember(initial.id) { mutableStateOf(initial.heatTo) }
    var coolTo by remember(initial.id) { mutableStateOf(initial.coolTo) }

    val lo = SetpointConfig.MIN_TEMP
    val hi = SetpointConfig.MAX_TEMP
    val gap = SetpointConfig.DEADBAND

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (initial.name.isBlank()) "New Profile" else "Edit Profile") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Outlined.ArrowBack, contentDescription = "Cancel")
                    }
                },
                actions = {
                    TextButton(onClick = {
                        onSave(
                            initial.copy(
                                name = name.ifBlank { "Profile" },
                                symbol = symbol,
                                colorHex = colorHex,
                                heatTo = heatTo,
                                coolTo = coolTo,
                            ),
                        )
                    }) { Text("Save") }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                ),
            )
        },
        containerColor = MaterialTheme.colorScheme.background,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(composeColor(colorHex)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    iconForSymbol(symbol),
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(36.dp),
                )
            }

            OutlinedTextField(
                value = name,
                onValueChange = { name = it },
                label = { Text("Name") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth(),
            )

            SettingsCard {
                StepperRow(
                    title = "Heat To",
                    valueText = "$heatTo°",
                    onDecrement = { heatTo = (heatTo - 1).coerceIn(lo, hi - gap) },
                    onIncrement = {
                        heatTo = (heatTo + 1).coerceIn(lo, hi - gap)
                        if (coolTo < heatTo + gap) coolTo = heatTo + gap
                    },
                )
                RowDivider()
                StepperRow(
                    title = "Cool To",
                    valueText = "$coolTo°",
                    onDecrement = {
                        coolTo = (coolTo - 1).coerceIn(lo + gap, hi)
                        if (heatTo > coolTo - gap) heatTo = coolTo - gap
                    },
                    onIncrement = { coolTo = (coolTo + 1).coerceIn(lo + gap, hi) },
                )
            }

            Column(modifier = Modifier.fillMaxWidth()) {
                SectionHeader("Color")
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    PROFILE_COLORS.forEach { hex ->
                        val selected = hex == colorHex
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(CircleShape)
                                .background(composeColor(hex))
                                .then(
                                    if (selected) Modifier.border(3.dp, MaterialTheme.colorScheme.onSurface, CircleShape)
                                    else Modifier,
                                )
                                .clickable { colorHex = hex },
                        )
                    }
                }
            }

            Column(modifier = Modifier.fillMaxWidth()) {
                SectionHeader("Icon")
                LazyVerticalGrid(
                    columns = GridCells.Fixed(6),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    items(PROFILE_SYMBOLS) { choice ->
                        val selected = choice.sfName == symbol
                        Box(
                            modifier = Modifier
                                .size(44.dp)
                                .clip(CircleShape)
                                .background(
                                    if (selected) MaterialTheme.colorScheme.primary
                                    else MaterialTheme.colorScheme.surfaceVariant,
                                )
                                .clickable { symbol = choice.sfName },
                            contentAlignment = Alignment.Center,
                        ) {
                            Icon(
                                choice.icon,
                                contentDescription = choice.sfName,
                                tint = if (selected) MaterialTheme.colorScheme.onPrimary
                                else MaterialTheme.colorScheme.onSurfaceVariant,
                            )
                        }
                    }
                }
            }
        }
    }
}
