import Foundation

// MARK: - FourCharCode

typealias FourCharCode = UInt32

extension FourCharCode {
    /// Create a FourCharCode from a 4-character string like "TC0P"
    init(_ string: String) {
        precondition(string.utf8.count == 4, "SMC key must be exactly 4 characters")
        self = string.utf8.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }

    /// Convert back to a 4-character string
    var fourCharString: String {
        let chars: [Character] = [
            Character(UnicodeScalar((self >> 24) & 0xFF)!),
            Character(UnicodeScalar((self >> 16) & 0xFF)!),
            Character(UnicodeScalar((self >> 8) & 0xFF)!),
            Character(UnicodeScalar(self & 0xFF)!)
        ]
        return String(chars)
    }
}

// MARK: - Well-Known SMC Data Type Codes

enum SMCDataType {
    static let sp78 = FourCharCode("sp78")  // Signed 7.8 fixed-point (temperatures)
    static let fpe2 = FourCharCode("fpe2")  // Unsigned 14.2 fixed-point (fan RPM)
    static let flt  = FourCharCode("flt ")  // 32-bit float (some T2 fan readings)
    static let ui8  = FourCharCode("ui8 ")  // Unsigned 8-bit integer
    static let ui16 = FourCharCode("ui16")  // Unsigned 16-bit integer
    static let ui32 = FourCharCode("ui32")  // Unsigned 32-bit integer
    static let flag = FourCharCode("flag")  // Boolean flag
}

// MARK: - Well-Known SMC Keys

enum SMCKey {
    static let keyCount = FourCharCode("#KEY")  // Total number of SMC keys
    static let fanCount = FourCharCode("FNum")  // Number of fans

    /// Fan actual speed: F0Ac, F1Ac, ...
    static func fanActual(_ index: Int) -> FourCharCode {
        FourCharCode("F\(index)Ac")
    }

    /// Fan minimum speed: F0Mn, F1Mn, ...
    static func fanMin(_ index: Int) -> FourCharCode {
        FourCharCode("F\(index)Mn")
    }

    /// Fan maximum speed: F0Mx, F1Mx, ...
    static func fanMax(_ index: Int) -> FourCharCode {
        FourCharCode("F\(index)Mx")
    }

    /// Fan target speed: F0Tg, F1Tg, ...
    static func fanTarget(_ index: Int) -> FourCharCode {
        FourCharCode("F\(index)Tg")
    }

    /// Fan mode: F0Md, F1Md, ... (0 = auto, 1 = forced)
    static func fanMode(_ index: Int) -> FourCharCode {
        FourCharCode("F\(index)Md")
    }

    /// Force fan control bitmask (not present on all models)
    static let forceFan = FourCharCode("FS! ")
}

// MARK: - Known Sensor Names

/// Human-friendly names for common SMC temperature sensor keys.
/// The app discovers all sensors dynamically; this just provides nice labels.
enum KnownSensors {
    static let names: [String: String] = [
        // CPU
        "TC0P": "CPU Proximity",
        "TC0C": "CPU Core 0 (PECI)",
        "TC1C": "CPU Core 1",
        "TC2C": "CPU Core 2",
        "TC3C": "CPU Core 3",
        "TC4C": "CPU Core 4",
        "TC5C": "CPU Core 5",
        "TC6C": "CPU Core 6",
        "TC7C": "CPU Core 7",
        "TCXC": "CPU Package (PECI)",
        "TCSA": "CPU System Agent",
        "TCGC": "Intel GPU (PECI)",
        "TC0E": "CPU 0 Efficiency",
        "TC0F": "CPU 0 ??",

        // GPU
        "TG0P": "GPU Proximity",
        "TG0D": "GPU Die",
        "TG1D": "GPU Die 1",

        // Memory
        "TM0P": "Memory Proximity",
        "TM0S": "Memory Slot 0",
        "TM1S": "Memory Slot 1",

        // Storage
        "TH0A": "SSD A",
        "TH0B": "SSD B",
        "TH0a": "SSD Proximity A",
        "TH0b": "SSD Proximity B",

        // Battery
        "TB0T": "Battery TS_MAX",
        "TB1T": "Battery 1",
        "TB2T": "Battery 2",

        // GPU (extended)
        "TGDD": "GPU Die (Digital)",
        "TGDE": "GPU Die (Efficiency)",
        "TGDF": "GPU Die (Frequency)",
        "TGVF": "GPU VRAM Frequency",
        "TGVP": "GPU VRAM Proximity",
        "TG1P": "GPU Proximity 2",

        // Misc
        "Tm0P": "Mainboard",
        "TW0P": "Wi-Fi Proximity",
        "THSP": "Thunderbolt Proximity",
        "TPCD": "Platform Controller Hub",
        "Ta0P": "Airflow 1",
        "Ts0P": "Palm Rest Left",
        "Ts0S": "Palm Rest Sensor Left",
        "Ts1P": "Palm Rest Right",
        "Ts1S": "Palm Rest Sensor Right",
        "Ts2S": "Palm Rest Sensor Center",
        "TCHP": "Charger Proximity",
        "Th1H": "Fin Stack 1 (Left Heatsink)",
        "Th2H": "Fin Stack 2 (Right Heatsink)",
        "TI0P": "Thunderbolt 0 Proximity",
        "TI1P": "Thunderbolt 1 Proximity",
        "TCMX": "CPU Max Core",
        "TC8C": "CPU Core 8",
        "TA0V": "Ambient",
        "TaLC": "Airflow Left",
        "TaRC": "Airflow Right",
        "TTLD": "Thunderbolt Left Die",
        "TTRD": "Thunderbolt Right Die",
        "TH0F": "HDD/SSD Fan Proximity",
        "TH0X": "HDD/SSD Proximity X",
        "TH1a": "SSD Proximity A2",
        "TH1b": "SSD Proximity B2",
    ]

    static func name(for key: String) -> String? {
        names[key]
    }
}
