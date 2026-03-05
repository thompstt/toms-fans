import Foundation
import ServiceManagement

final class AppSettings: ObservableObject {
    @Published var presets: [FanPreset] {
        didSet { debouncedSave("presets", presets) }
    }
    @Published var fanCurves: [FanCurve] {
        didSet { debouncedSave("fanCurves", fanCurves) }
    }
    @Published var alertThresholds: [String: Double] {
        didSet { debouncedSave("alertThresholds", alertThresholds) }
    }
    @Published var controlMode: FanControlMode {
        didSet { UserDefaults.standard.set(controlMode.rawValue, forKey: "controlMode") }
    }
    @Published var activePresetId: UUID? {
        didSet {
            if let id = activePresetId {
                UserDefaults.standard.set(id.uuidString, forKey: "activePresetId")
            } else {
                UserDefaults.standard.removeObject(forKey: "activePresetId")
            }
        }
    }
    @Published var activeCurveId: UUID? {
        didSet {
            if let id = activeCurveId {
                UserDefaults.standard.set(id.uuidString, forKey: "activeCurveId")
            } else {
                UserDefaults.standard.removeObject(forKey: "activeCurveId")
            }
        }
    }
    @Published var pollInterval: TimeInterval {
        didSet { UserDefaults.standard.set(pollInterval, forKey: "pollInterval") }
    }
    @Published var showTemperatureInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showTemperatureInMenuBar, forKey: "showTempMenuBar") }
    }
    @Published var temperatureUnit: TemperatureUnit {
        didSet { UserDefaults.standard.set(temperatureUnit.rawValue, forKey: "tempUnit") }
    }
    @Published var launchAtLogin: Bool {
        didSet { toggleLaunchAtLogin() }
    }

    enum TemperatureUnit: String, CaseIterable, Identifiable {
        case celsius, fahrenheit
        var id: String { rawValue }
    }

    // Debounce timers for expensive JSON saves
    private var saveTimers: [String: Timer] = [:]

    init() {
        // Migrate old fan curve format (v1 used "rpm", v2 uses "percent")
        if UserDefaults.standard.integer(forKey: "fanCurveVersion") < 2 {
            UserDefaults.standard.removeObject(forKey: "fanCurves")
            UserDefaults.standard.removeObject(forKey: "activeCurveId")
            UserDefaults.standard.set(2, forKey: "fanCurveVersion")
        }

        self.presets = Self.load("presets") ?? FanPreset.defaultPresets
        self.fanCurves = Self.load("fanCurves") ?? [FanCurve.defaultCurve]
        self.alertThresholds = Self.load("alertThresholds") ?? ["TCXC": 95, "TG0P": 90]
        self.controlMode = FanControlMode(rawValue:
            UserDefaults.standard.string(forKey: "controlMode") ?? "automatic") ?? .automatic
        self.activePresetId = UserDefaults.standard.string(forKey: "activePresetId")
            .flatMap { UUID(uuidString: $0) }
        self.activeCurveId = UserDefaults.standard.string(forKey: "activeCurveId")
            .flatMap { UUID(uuidString: $0) }
        let stored = UserDefaults.standard.double(forKey: "pollInterval")
        self.pollInterval = stored > 0 ? stored : 2.0
        self.showTemperatureInMenuBar = UserDefaults.standard.object(forKey: "showTempMenuBar") as? Bool ?? true
        self.temperatureUnit = TemperatureUnit(rawValue:
            UserDefaults.standard.string(forKey: "tempUnit") ?? "celsius") ?? .celsius
        self.launchAtLogin = false
        refreshLaunchAtLoginState()

        // Persist default fan curves if they were just created (init doesn't trigger didSet)
        if UserDefaults.standard.data(forKey: "fanCurves") == nil {
            UserDefaults.standard.set(try? JSONEncoder().encode(fanCurves), forKey: "fanCurves")
        }
    }

    private func toggleLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    func refreshLaunchAtLoginState() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    /// Debounced save — waits 0.5s after last change before writing JSON to disk.
    private func debouncedSave<T: Encodable>(_ key: String, _ value: T) {
        saveTimers[key]?.invalidate()
        saveTimers[key] = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
        }
    }

    private static func load<T: Decodable>(_ key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
