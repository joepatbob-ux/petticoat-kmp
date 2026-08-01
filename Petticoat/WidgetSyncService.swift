import ActivityKit
import Foundation
import WidgetKit

/// Native iOS adapter between shared thermostat state and WidgetKit/ActivityKit.
/// KMP owns domain state; this service owns Apple platform side effects.
@MainActor
final class WidgetSyncService {
    private var liveActivity: Activity<PetticoatActivityAttributes>?

    func sync(devices: [Device], selectedDevice: Device, homes: [Home]) {
        let list = devices.map {
            WidgetDeviceInfo(id: $0.id.uuidString, name: $0.name)
        }
        WidgetSnapshot.saveDeviceList(list)

        for device in devices {
            let widgetActivity: WidgetActivity = switch device.activity {
            case .idle: device.fanMode == .on ? .fan : .idle
            case .heating: .heating
            case .cooling: .cooling
            }

            let deviceID = device.id.uuidString
            var snapshot = WidgetSnapshot.load(deviceID: deviceID)
            if snapshot.activity != widgetActivity {
                snapshot.feedbackGiven = false
                snapshot.comfortFeedback = nil
            }
            snapshot.deviceName = device.name
            snapshot.currentTemp = device.currentTemp
            snapshot.humidity = device.humidity
            snapshot.activity = widgetActivity
            snapshot.isOffline = device.isOffline
            snapshot.systemMode = switch device.systemMode {
            case .heat, .auxHeat: .heat
            case .cool: .cool
            case .auto: .auto
            case .off: .off
            }
            snapshot.optimisticActivity = nil
            snapshot.save()
        }

        WidgetCenter.shared.reloadTimelines(ofKind: WidgetSnapshot.widgetKind)
        manageLiveActivity(for: selectedDevice, homes: homes)
    }

    func applyPendingCommand(to model: AppModel) {
        let deviceID = model.device.id.uuidString
        var snapshot = WidgetSnapshot.load(deviceID: deviceID)
        guard snapshot.pendingSetpointDelta != nil || snapshot.pendingFanRun == true else {
            return
        }

        let delta = snapshot.pendingSetpointDelta
        let runFan = snapshot.pendingFanRun == true
        snapshot.pendingSetpointDelta = nil
        snapshot.pendingFanRun = nil
        snapshot.save()

        if let delta {
            model.adjustKeep(delta > 0 ? .low : .high, by: delta)
        }
        if runFan {
            model.setFanMode(.on, for: model.device.id)
            model.setFanHoldDuration(.twoHours, for: model.device.id)
        }
    }

    private func estimateMinutesToTemp(
        current: Int,
        target: Int,
        for device: Device,
        homes: [Home],
        isHeating: Bool
    ) -> Int {
        let delta = max(1, abs(target - current))
        let base: Double = isHeating ? 10.0 / 60.0 : 12.0 / 60.0
        let outdoorPenalty: Double = if isHeating {
            min(0.4, max(0, Double(target - device.outdoorTemp)) / 100.0)
        } else {
            min(0.3, max(0, Double(device.outdoorTemp - target)) / 100.0)
        }
        let home = homes.first { $0.id == device.homeID }
        let hvacFactor = isHeating ? (home?.hvacSystemType.heatingFactor ?? 1.0) : 1.0
        let rate = base
            * (1.0 - outdoorPenalty)
            * hvacFactor
            * (home?.homeSize.rateMultiplier ?? 1.0)
        return max(1, Int((Double(delta) / rate).rounded()))
    }

    private func manageLiveActivity(for device: Device, homes: [Home]) {
        let isActive = device.activity == .heating || device.activity == .cooling
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        if isActive {
            let isHeating = device.activity == .heating
            let target = isHeating ? device.keepMin : device.keepMax
            let minutes = estimateMinutesToTemp(
                current: device.currentTemp,
                target: target,
                for: device,
                homes: homes,
                isHeating: isHeating
            )
            let endDate = Date().addingTimeInterval(Double(minutes) * 60)
            let state = PetticoatActivityAttributes.ContentState(
                currentTemp: device.currentTemp,
                targetTemp: target,
                estimatedEndDate: endDate,
                isHeating: isHeating
            )

            if let activity = liveActivity, activity.activityState == .active {
                Task { await activity.update(.init(state: state, staleDate: endDate)) }
            } else {
                let attributes = PetticoatActivityAttributes(
                    deviceName: device.name,
                    startTemp: device.currentTemp
                )
                liveActivity = try? Activity.request(
                    attributes: attributes,
                    content: .init(state: state, staleDate: endDate)
                )
            }
        } else if let activity = liveActivity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            liveActivity = nil
        }
    }
}
