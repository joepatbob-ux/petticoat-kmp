import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Helpers

private extension PetticoatActivityAttributes.ContentState {
    var accentColor: Color {
        isHeating ? Color(red: 0.969, green: 0.404, blue: 0.027)
                  : Color(red: 0.0,   green: 0.576, blue: 0.784)
    }
    var icon: String  { isHeating ? "flame.fill" : "snowflake" }
    var verb: String  { isHeating ? "Heating" : "Cooling" }

    func progress(startTemp: Int) -> Double {
        let total = Double(abs(targetTemp - startTemp))
        guard total > 0 else { return 1 }
        return min(1, max(0, Double(abs(currentTemp - startTemp)) / total))
    }
}

// MARK: - Lock screen / notification banner

private struct LABannerView: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    private var s: PetticoatActivityAttributes.ContentState { context.state }
    private var a: PetticoatActivityAttributes { context.attributes }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: verb + device name
            HStack {
                Label(s.verb, systemImage: s.icon)
                    .font(.headline)
                    .foregroundStyle(s.accentColor)
                Spacer()
                Text(a.deviceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Temps
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(s.currentTemp)°")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(s.targetTemp)°")
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.quaternary).frame(height: 5)
                    Capsule()
                        .fill(s.accentColor)
                        .frame(width: geo.size.width * s.progress(startTemp: a.startTemp), height: 5)
                }
            }
            .frame(height: 5)

            // Countdown with context label
            HStack(spacing: 4) {
                Text(s.estimatedEndDate, style: .timer)
                    .monospacedDigit()
                Text("to reach \(s.targetTemp)°")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }
}

// MARK: - Dynamic Island expanded bottom region
// Leading/trailing regions show verb + device name — this view only shows temps + timer.

private struct LAExpandedBottomView: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    private var s: PetticoatActivityAttributes.ContentState { context.state }

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(s.currentTemp)°")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                Spacer()
                HStack(spacing: 4) {
                    Text(s.estimatedEndDate, style: .timer)
                        .monospacedDigit()
                    Text("to \(s.targetTemp)°")
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                Spacer()
                Text("\(s.targetTemp)°")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

// MARK: - Widget

struct PetticoatLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PetticoatActivityAttributes.self) { context in
            LABannerView(context: context)
                .activityBackgroundTint(.clear)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.verb, systemImage: context.state.icon)
                        .font(.headline)
                        .foregroundStyle(context.state.accentColor)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.attributes.deviceName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    LAExpandedBottomView(context: context)
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: context.state.icon)
                        .foregroundStyle(context.state.accentColor)
                    Text("\(context.state.currentTemp)°")
                        .font(.caption.weight(.semibold))
                }
            } compactTrailing: {
                Text(context.state.estimatedEndDate, style: .timer)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .frame(minWidth: 36)
            } minimal: {
                Image(systemName: context.state.icon)
                    .foregroundStyle(context.state.accentColor)
            }
        }
    }
}
