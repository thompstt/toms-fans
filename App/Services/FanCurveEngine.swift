import Foundation

/// Evaluates fan curves and applies interpolated RPM values via XPC.
final class FanCurveEngine: ObservableObject {
    private(set) var lastAppliedRPM: [Int: Int] = [:]  // fanIndex -> RPM
    private var lastAppliedTemp: [UUID: Double] = [:]  // curveId -> temp when last applied

    /// Evaluate the active fan curve against current temperatures.
    /// Call this every poll cycle when in fan curve mode.
    func evaluate(curve: FanCurve, temperatures: [TemperatureSensor],
                  fans: [Fan], fanControl: XPCFanControlService) {
        guard let sensor = temperatures.first(where: { $0.key == curve.sensorKey }) else {
            return
        }

        let currentTemp = sensor.value

        // Hysteresis check: only update if temp has moved enough
        if let lastTemp = lastAppliedTemp[curve.id],
           abs(currentTemp - lastTemp) < curve.hysteresis {
            return
        }

        let percent = curve.interpolatePercent(forTemperature: currentTemp)

        // Apply to each fan this curve controls
        for fanIndex in curve.appliesToFans {
            guard let fan = fans.first(where: { $0.index == fanIndex }),
                  fan.maxRPM > fan.minRPM else { continue }

            let targetRPM = FanCurve.percentToRPM(percent, minRPM: fan.minRPM, maxRPM: fan.maxRPM)
            fanControl.setFanMode(fanIndex: fanIndex, mode: 1)
            fanControl.setFanMinSpeed(fanIndex: fanIndex, rpm: targetRPM)
            lastAppliedRPM[fanIndex] = targetRPM
        }

        lastAppliedTemp[curve.id] = currentTemp
    }

    func reset() {
        lastAppliedRPM.removeAll()
        lastAppliedTemp.removeAll()
    }
}
