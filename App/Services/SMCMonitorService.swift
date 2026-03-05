import Foundation
import IOKit

struct TemperatureReading: Identifiable {
    let id: Int  // Sequential counter, not UUID (avoids allocation)
    let date: Date
    let value: Double
}

/// Polls SMC sensors on a timer, publishes state for the UI.
/// Optimized to only trigger @Published when values meaningfully change.
final class SMCMonitorService: ObservableObject {
    @Published var temperatures: [TemperatureSensor] = []
    @Published var fans: [Fan] = []
    @Published var chartHistory: [String: [TemperatureReading]] = [:]
    private var _fullHistory: [String: [TemperatureReading]] = [:]
    @Published var menuBarLabel: String = "--°C"
    @Published var isConnected = false

    private var reader: SMCReader?
    private let connection = SMCConnection()
    private var timer: Timer?
    private var pollInterval: TimeInterval = 2.0
    private let maxHistoryPoints = 1800
    private var readingCounter = 0
    private var pollCount = 0

    var onPoll: (([TemperatureSensor]) -> Void)?

    init() {
        do {
            try connection.open()
            reader = SMCReader(connection: connection)
            isConnected = true
            discoverSensors()
            startPolling()
        } catch {
            isConnected = false
        }
    }

    deinit {
        timer?.invalidate()
        connection.close()
    }

    func updatePollInterval(_ interval: TimeInterval) {
        guard interval != pollInterval, interval > 0 else { return }
        pollInterval = interval
        timer?.invalidate()
        startPolling()
    }

    // MARK: - Cached Computed Properties

    var cpuPackageTemp: Double {
        temperatures.first(where: { $0.key == "TCXC" })?.value
            ?? temperatures.filter({ $0.key.hasPrefix("TC") }).map(\.value).max()
            ?? 0
    }

    var gpuTemp: Double {
        temperatures.first(where: { $0.key == "TG0P" })?.value ?? 0
    }

    // MARK: - Private

    private func discoverSensors() {
        guard let reader else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let sensors = (try? reader.discoverTemperatureSensors()) ?? []
            let fanCount = (try? reader.fanCount()) ?? 0

            let tempModels = sensors.map {
                TemperatureSensor(key: $0.key, name: $0.name, value: $0.value)
            }
            let fanModels = (0..<fanCount).map { Fan(index: $0) }

            DispatchQueue.main.async {
                self.temperatures = tempModels
                self.fans = fanModels
                self.poll()
            }
        }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        timer?.tolerance = 0.5
    }

    private func poll() {
        guard let reader else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            // Read temperatures
            var updatedTemps = self.temperatures
            for i in updatedTemps.indices {
                if let temp = try? reader.readTemperature(key: FourCharCode(updatedTemps[i].key)) {
                    updatedTemps[i].value = temp
                }
            }

            // Read fan data
            var updatedFans = self.fans
            for i in updatedFans.indices {
                let idx = updatedFans[i].index
                updatedFans[i].actualRPM = (try? reader.fanActualSpeed(fanIndex: idx)) ?? 0
                updatedFans[i].minRPM = (try? reader.fanMinSpeed(fanIndex: idx)) ?? 0
                updatedFans[i].maxRPM = (try? reader.fanMaxSpeed(fanIndex: idx)) ?? 0
                if let (_, bytes) = try? reader.readKey(SMCKey.fanTarget(idx)) {
                    updatedFans[i].targetRPM = Double(flt: bytes)
                }
            }

            DispatchQueue.main.async {
                self.pollCount += 1

                // Only publish temperatures if any sensor changed by >= 1°C
                let tempsChanged = self.temperatures.count != updatedTemps.count
                    || zip(self.temperatures, updatedTemps).contains { abs($0.value - $1.value) >= 1.0 }
                if tempsChanged {
                    self.temperatures = updatedTemps
                }

                // Only publish fans when values actually changed
                if self.fans != updatedFans {
                    self.fans = updatedFans
                }

                // Append history every 5th poll (~10s) to reduce chart rebuilds
                if self.pollCount % 5 == 0 {
                    self.appendHistory(updatedTemps)
                }

                // Only update menu bar label if string actually changed
                let newLabel = self.formatMenuBarLabel(updatedTemps)
                if newLabel != self.menuBarLabel {
                    self.menuBarLabel = newLabel
                }

                self.onPoll?(updatedTemps)
            }
        }
    }

    private let chartTargetPoints = 150

    private func appendHistory(_ sensors: [TemperatureSensor]) {
        let now = Date()
        readingCounter += 1
        for sensor in sensors {
            var readings = _fullHistory[sensor.key] ?? []
            readings.append(TemperatureReading(id: readingCounter, date: now, value: sensor.value))
            if readings.count > maxHistoryPoints {
                readings.removeFirst(readings.count - maxHistoryPoints)
            }
            _fullHistory[sensor.key] = readings
        }
        // Pre-downsample for chart consumption
        var downsampled: [String: [TemperatureReading]] = [:]
        for (key, readings) in _fullHistory {
            if readings.count <= chartTargetPoints {
                downsampled[key] = readings
            } else {
                let step = readings.count / chartTargetPoints
                var sampled: [TemperatureReading] = []
                sampled.reserveCapacity(chartTargetPoints + 1)
                for i in Swift.stride(from: 0, to: readings.count, by: max(step, 1)) {
                    sampled.append(readings[i])
                }
                if let last = readings.last, sampled.last?.id != last.id {
                    sampled.append(last)
                }
                downsampled[key] = sampled
            }
        }
        chartHistory = downsampled
    }

    private func formatMenuBarLabel(_ sensors: [TemperatureSensor]) -> String {
        let cpuTemp = sensors.first(where: { $0.key == "TCXC" })?.value
            ?? sensors.filter({ $0.key.hasPrefix("TC") }).map(\.value).max()
            ?? 0
        return String(format: "%.0f°C", cpuTemp)
    }
}
