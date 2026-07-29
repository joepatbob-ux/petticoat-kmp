import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Colors

private enum LAColor {
    static let heating = Color(red: 0.969, green: 0.404, blue: 0.027) // #F76707
    static let cooling = Color(red: 0.0,   green: 0.576, blue: 0.784) // #0093C8
}

// MARK: - Content state helpers

private extension PetticoatActivityAttributes.ContentState {
    var accentColor: Color { isHeating ? LAColor.heating : LAColor.cooling }
    var icon: String  { isHeating ? "flame.fill" : "snowflake" }
    var verb: String  { isHeating ? "Heating" : "Cooling" }

    /// True once the room has reached (or passed) the target in the active
    /// direction — heating counts up to the target, cooling counts down to it.
    var isAtTarget: Bool {
        isHeating ? currentTemp >= targetTemp : currentTemp <= targetTemp
    }

    func progress(startTemp: Int) -> Double {
        if isAtTarget { return 1 }
        let total = Double(abs(targetTemp - startTemp))
        guard total > 0 else { return 1 }
        return min(1, max(0, Double(abs(currentTemp - startTemp)) / total))
    }
}

// MARK: - Shared subviews

/// Rounded, accent-tinted linear progress track. Used by the banner and the
/// Dynamic Island expanded region.
private struct LAProgressBar: View {
    var progress: Double
    var color: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track: tinted so the empty portion stays visible against the
                // dark lock-screen / Dynamic Island backgrounds.
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(color)
                    // Once any progress exists, keep at least a round nub visible.
                    .frame(width: progress > 0 ? max(height, geo.size.width * progress) : 0)
            }
        }
        .frame(height: height)
    }
}

/// Circular progress ring wrapping the HVAC icon. Powers the small compact and
/// minimal Dynamic Island presentations — the ring shows progress toward the
/// setpoint, the glyph shows heating / cooling (or a checkmark once reached).
private struct LARingIcon: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.5

    var body: some View {
        let s = context.state
        let p = s.progress(startTemp: context.attributes.startTemp)
        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: p)
                .stroke(s.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: s.isAtTarget ? "checkmark" : s.icon)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(s.accentColor)
        }
        .frame(width: size, height: size)
    }
}

/// Labelled status: "Time to setpoint … MM:SS" while heating/cooling, an
/// "Almost there" state once the estimate has elapsed (activity is stale), and
/// a "Reached N°" state once the target is hit. Used by the banner and expanded.
private struct LATimeToSetpoint: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    var font: Font = .footnote.weight(.medium)

    var body: some View {
        let s = context.state
        Group {
            if s.isAtTarget {
                Label("Reached \(s.targetTemp)°", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(s.accentColor)
            } else if context.isStale {
                Label("Almost there", systemImage: "hourglass")
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    Text("Time to setpoint")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 8)
                    Text(s.estimatedEndDate, style: .timer)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                }
            }
        }
        .font(font)
    }
}

// MARK: - Lock screen / notification banner

private struct LABannerView: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    private var s: PetticoatActivityAttributes.ContentState { context.state }
    private var a: PetticoatActivityAttributes { context.attributes }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: verb + device name
            HStack {
                Label(s.isAtTarget ? "Comfortable" : s.verb, systemImage: s.isAtTarget ? "checkmark.circle.fill" : s.icon)
                    .font(.headline)
                    .foregroundStyle(s.accentColor)
                Spacer()
                Text(a.deviceName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Temps: current on the left, target on the right — the progress
            // bar below connects them, so no arrow is needed here.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text("\(s.currentTemp)°")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(s.accentColor)
                Spacer()
                Text("\(s.targetTemp)°")
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LAProgressBar(progress: s.progress(startTemp: a.startTemp), color: s.accentColor)

            LATimeToSetpoint(context: context)
        }
        .padding(16)
    }
}

// MARK: - Dynamic Island expanded bottom region
// Leading/trailing regions show verb + device name — this view shows temps,
// the progress bar, and the labelled time-to-setpoint status.

private struct LAExpandedBottomView: View {
    let context: ActivityViewContext<PetticoatActivityAttributes>
    private var s: PetticoatActivityAttributes.ContentState { context.state }
    private var a: PetticoatActivityAttributes { context.attributes }

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(s.currentTemp)°")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(s.accentColor)
                Spacer()
                Text("\(s.targetTemp)°")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LAProgressBar(progress: s.progress(startTemp: a.startTemp), color: s.accentColor, height: 5)

            LATimeToSetpoint(context: context, font: .system(size: 14, weight: .medium, design: .rounded))
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
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.isAtTarget ? "Comfortable" : context.state.verb,
                          systemImage: context.state.isAtTarget ? "checkmark.circle.fill" : context.state.icon)
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
                // A small progress ring around the HVAC icon keeps the compact
                // presentation tight.
                LARingIcon(context: context)
            } compactTrailing: {
                Text("\(context.state.currentTemp)°")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(context.state.accentColor)
            } minimal: {
                LARingIcon(context: context, size: 18, lineWidth: 2.2)
            }
        }
    }
}
