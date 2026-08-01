package com.sensi.petticoat.ui.components.schedule

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import com.sensi.petticoat.math.DialMath
import com.sensi.petticoat.model.ScheduleEvent
import kotlin.math.PI
import kotlin.math.atan2

@Composable
fun RadialScheduleDial(
    events: List<ScheduleEvent>,
    modifier: Modifier = Modifier,
    onMoveEvent: (String, Int) -> Unit,
) {
    val sorted = events.sortedBy { it.startMinutes }
    Canvas(
        modifier = modifier
            .size(280.dp)
            .pointerInput(sorted) {
                var draggedId: String? = null
                detectDragGestures(
                    onDragStart = { offset ->
                        val minute = offset.toMinute(size.width.toFloat(), size.height.toFloat())
                        draggedId = sorted.minByOrNull {
                            minOf(
                                DialMath.cwDistance(it.startMinutes, minute),
                                DialMath.cwDistance(minute, it.startMinutes),
                            )
                        }?.id
                    },
                    onDrag = { change, _ ->
                        val id = draggedId ?: return@detectDragGestures
                        val minute = change.position.toMinute(size.width.toFloat(), size.height.toFloat())
                        onMoveEvent(id, DialMath.snapToGrid(minute, 15))
                    },
                    onDragEnd = { draggedId = null },
                )
            },
    ) {
        val stroke = size.minDimension * 0.16f
        val inset = stroke / 2
        val arcSize = Size(size.width - stroke, size.height - stroke)
        drawArc(
            color = Color(0xFFE5E5EA),
            startAngle = -90f,
            sweepAngle = 360f,
            useCenter = false,
            topLeft = Offset(inset, inset),
            size = arcSize,
            style = Stroke(stroke, cap = StrokeCap.Butt),
        )
        sorted.forEachIndexed { index, event ->
            val next = sorted.getOrNull(index + 1)?.startMinutes
                ?: sorted.firstOrNull()?.startMinutes?.plus(1440)
                ?: event.startMinutes + 1440
            val duration = next - event.startMinutes
            drawArc(
                color = Color((0xFF000000L or event.colorHex).toULong()),
                startAngle = event.startMinutes / 1440f * 360f - 90f,
                sweepAngle = duration / 1440f * 360f,
                useCenter = false,
                topLeft = Offset(inset, inset),
                size = arcSize,
                style = Stroke(stroke, cap = StrokeCap.Butt),
            )
        }
    }
}

private fun Offset.toMinute(width: Float, height: Float): Int {
    val angle = atan2(y - height / 2f, x - width / 2f)
    val normalized = ((angle + PI / 2 + 2 * PI) % (2 * PI)) / (2 * PI)
    return (normalized * 1440).toInt()
}
