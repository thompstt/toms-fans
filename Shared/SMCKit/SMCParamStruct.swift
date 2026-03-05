import Foundation
import IOKit

// MARK: - SMC Selectors

/// The outer selector is always kSMCHandleYPCEvent (2) for IOConnectCallStructMethod.
/// The inner selector (set in data8) determines the actual operation.
enum SMCSelector: UInt8 {
    case kSMCHandleYPCEvent  = 2
    case kSMCReadKey         = 5
    case kSMCWriteKey        = 6
    case kSMCGetKeyFromIndex = 8
    case kSMCGetKeyInfo      = 9
}

// MARK: - SMC Sub-Structs

struct SMCVersion {
    var major: CUnsignedChar = 0
    var minor: CUnsignedChar = 0
    var build: CUnsignedChar = 0
    var reserved: CUnsignedChar = 0
    var release: CUnsignedShort = 0
}

struct SMCPLimitData {
    var version: UInt16 = 0
    var length: UInt16 = 0
    var cpuPLimit: UInt32 = 0
    var gpuPLimit: UInt32 = 0
    var memPLimit: UInt32 = 0
}

struct SMCKeyInfoData {
    var dataSize: UInt32 = 0
    var dataType: UInt32 = 0
    var dataAttributes: UInt8 = 0
}

// MARK: - SMC Bytes Tuple (32 bytes)

typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

// MARK: - SMCParamStruct (80 bytes — must match kernel layout exactly)

struct SMCParamStruct {
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0
    )
}

// MARK: - SMC Errors

enum SMCError: LocalizedError {
    case serviceNotFound
    case openFailed(kern_return_t)
    case callFailed(kern_return_t)
    case smcError(UInt8)
    case keyNotFound(String)
    case unexpectedDataType(UInt32)

    var errorDescription: String? {
        switch self {
        case .serviceNotFound:
            return "AppleSMC service not found"
        case .openFailed(let code):
            return "Failed to open SMC connection: \(code)"
        case .callFailed(let code):
            return "SMC call failed: \(code)"
        case .smcError(let result):
            return "SMC returned error code: \(result)"
        case .keyNotFound(let key):
            return "SMC key not found: \(key)"
        case .unexpectedDataType(let type):
            return "Unexpected SMC data type: \(type)"
        }
    }
}
