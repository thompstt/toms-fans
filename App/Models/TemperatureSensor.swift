import Foundation

struct TemperatureSensor: Identifiable, Equatable {
    static func == (lhs: TemperatureSensor, rhs: TemperatureSensor) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }

    let id: String
    let key: String
    let name: String
    var value: Double

    init(key: String, name: String, value: Double) {
        self.id = key
        self.key = key
        self.name = name
        self.value = value
    }

    var formattedValue: String {
        String(format: "%.1f°C", value)
    }

    var category: SensorCategory {
        if key.hasPrefix("TC") { return .cpu }
        if key.hasPrefix("TG") { return .gpu }
        if key.hasPrefix("TB") { return .battery }
        if key.hasPrefix("TM") { return .memory }
        if key.hasPrefix("TH") { return .storage }
        if key.hasPrefix("Th") { return .heatsink }
        if key.hasPrefix("Ts") { return .palmRest }
        return .other
    }
}

enum SensorCategory: String, CaseIterable, Identifiable {
    case cpu = "CPU"
    case gpu = "GPU"
    case memory = "Memory"
    case storage = "Storage"
    case battery = "Battery"
    case heatsink = "Heatsink"
    case palmRest = "Palm Rest"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .cpu:      return "cpu"
        case .gpu:      return "display"
        case .memory:   return "memorychip"
        case .storage:  return "internaldrive"
        case .battery:  return "battery.75percent"
        case .heatsink: return "flame"
        case .palmRest: return "hand.raised"
        case .other:    return "thermometer.medium"
        }
    }
}
