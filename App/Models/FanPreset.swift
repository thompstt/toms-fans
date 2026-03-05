import Foundation

struct FanPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fanSpeeds: [Int: Int]  // fanIndex -> target RPM
    var isForceMode: Bool      // Whether to set fan mode to forced

    static let defaultPresets: [FanPreset] = [
        FanPreset(id: UUID(), name: "Silent", fanSpeeds: [0: 1836, 1: 1700], isForceMode: false),
        FanPreset(id: UUID(), name: "Balanced", fanSpeeds: [0: 3000, 1: 2800], isForceMode: true),
        FanPreset(id: UUID(), name: "Performance", fanSpeeds: [0: 4500, 1: 4200], isForceMode: true),
        FanPreset(id: UUID(), name: "Full Blast", fanSpeeds: [0: 5616, 1: 5200], isForceMode: true),
    ]
}

enum FanControlMode: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case manual = "Manual"
    case preset = "Preset"
    case fanCurve = "Fan Curve"

    var id: String { rawValue }
}
