import Foundation

// MARK: - sp78: Signed 7.8 Fixed-Point (Temperature)

/// sp78 format: 1 sign bit + 7 integer bits + 8 fractional bits
/// Used by most temperature sensor keys.
extension Double {
    init(sp78 byte0: UInt8, byte1: UInt8) {
        let raw = Int16(byte0) << 8 | Int16(byte1)
        self = Double(raw) / 256.0
    }
}

// MARK: - fpe2: Unsigned 14.2 Fixed-Point (Fan RPM)

/// fpe2 format: 14 integer bits + 2 fractional bits
/// Used by fan speed keys (F0Ac, F0Mn, F0Mx, etc.)
extension Double {
    init(fpe2 byte0: UInt8, byte1: UInt8) {
        let raw = UInt16(byte0) << 8 | UInt16(byte1)
        self = Double(raw) / 4.0
    }
}

extension Int {
    /// Convert an RPM integer to fpe2 byte pair for SMC writes.
    var fpe2Bytes: (UInt8, UInt8) {
        let raw = UInt16(clamping: self * 4)
        return (UInt8(raw >> 8), UInt8(raw & 0xFF))
    }
}

// MARK: - flt: 32-bit Float

/// Float format used by some SMC keys (fan speeds on MacBook Pro 16,1).
/// On Intel Macs the SMC stores floats in little-endian (native) byte order.
extension Double {
    init(flt bytes: SMCBytes) {
        var value: Float = 0
        withUnsafeMutableBytes(of: &value) { ptr in
            ptr[0] = bytes.0
            ptr[1] = bytes.1
            ptr[2] = bytes.2
            ptr[3] = bytes.3
        }
        self = Double(value)
    }
}

// MARK: - ui32: Unsigned 32-bit Integer, Big-Endian

extension Int {
    init(ui32 bytes: SMCBytes) {
        self = Int(bytes.0) << 24 | Int(bytes.1) << 16 | Int(bytes.2) << 8 | Int(bytes.3)
    }
}

// MARK: - SMCBytes Helpers

func smcBytesGetByte(_ bytes: SMCBytes, at index: Int) -> UInt8 {
    withUnsafeBytes(of: bytes) { buffer in
        buffer[index]
    }
}

func smcBytesSetByte(_ bytes: inout SMCBytes, _ value: UInt8, at index: Int) {
    withUnsafeMutableBytes(of: &bytes) { buffer in
        buffer[index] = value
    }
}
