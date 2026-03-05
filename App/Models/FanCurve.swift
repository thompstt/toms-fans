import Foundation

struct CurvePoint: Identifiable, Codable, Hashable {
    let id: UUID
    var temperature: Double  // °C
    var percent: Int         // 0-100% of fan speed range

    init(temperature: Double, percent: Int) {
        self.id = UUID()
        self.temperature = temperature
        self.percent = min(max(percent, 0), 100)
    }

    /// Preserves identity during drag operations.
    init(id: UUID, temperature: Double, percent: Int) {
        self.id = id
        self.temperature = temperature
        self.percent = min(max(percent, 0), 100)
    }
}

struct FanCurve: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var sensorKey: String            // Which sensor drives this curve
    var controlPoints: [CurvePoint]  // Sorted by temperature ascending
    var hysteresis: Double = 2.0     // °C deadband to prevent oscillation
    var appliesToFans: [Int]         // Which fan indices this curve controls

    init(name: String, sensorKey: String, controlPoints: [CurvePoint],
         appliesToFans: [Int]) {
        self.id = UUID()
        self.name = name
        self.sensorKey = sensorKey
        self.controlPoints = controlPoints.sorted { $0.temperature < $1.temperature }
        self.appliesToFans = appliesToFans
    }

    /// Interpolate the target percentage (0-100) for a given temperature.
    func interpolatePercent(forTemperature temp: Double) -> Int {
        guard !controlPoints.isEmpty else { return 0 }

        if temp <= controlPoints.first!.temperature {
            return controlPoints.first!.percent
        }

        if temp >= controlPoints.last!.temperature {
            return controlPoints.last!.percent
        }

        for i in 0..<(controlPoints.count - 1) {
            let low = controlPoints[i]
            let high = controlPoints[i + 1]

            if temp >= low.temperature && temp <= high.temperature {
                let fraction = (temp - low.temperature) / (high.temperature - low.temperature)
                let pct = Double(low.percent) + fraction * Double(high.percent - low.percent)
                return Int(pct)
            }
        }

        return controlPoints.last!.percent
    }

    /// Convert a percentage to RPM for a specific fan.
    static func percentToRPM(_ percent: Int, minRPM: Double, maxRPM: Double) -> Int {
        guard maxRPM > minRPM else { return Int(minRPM) }
        let pct = Double(min(max(percent, 0), 100)) / 100.0
        return Int(minRPM + pct * (maxRPM - minRPM))
    }

    static let defaultCurve = FanCurve(
        name: "Default Cooling",
        sensorKey: "TCXC",
        controlPoints: [
            CurvePoint(temperature: 40, percent: 0),
            CurvePoint(temperature: 60, percent: 25),
            CurvePoint(temperature: 75, percent: 50),
            CurvePoint(temperature: 85, percent: 75),
            CurvePoint(temperature: 95, percent: 100),
        ],
        appliesToFans: [0, 1]
    )
}
