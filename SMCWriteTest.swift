/// SMC Write Test — run with sudo to test fan control directly.
/// Build: cd "Tom's Fans" && swiftc -framework IOKit -framework Foundation Shared/SMCKit/*.swift SMCWriteTest.swift -o smc_write_test
/// Run:   sudo ./smc_write_test
import Foundation
import IOKit

@main
struct SMCWriteTest {
    static func main() {
        print("=== SMC Write Test (must run as root) ===\n")
        print("UID: \(getuid()) (0 = root)")

        let connection = SMCConnection()
        do {
            try connection.open()
            print("[OK] SMC connection opened\n")
        } catch {
            print("[FAIL] \(error)")
            return
        }

        let reader = SMCReader(connection: connection)

        // Show current fan state
        print("--- Current Fan State ---")
        for i in 0..<2 {
            let actual = (try? reader.fanActualSpeed(fanIndex: i)) ?? 0
            let min = (try? reader.fanMinSpeed(fanIndex: i)) ?? 0
            let max = (try? reader.fanMaxSpeed(fanIndex: i)) ?? 0
            print("  Fan \(i): actual=\(Int(actual)) min=\(Int(min)) max=\(Int(max))")

            // Show mode
            if let (_, modeBytes) = try? reader.readKey(SMCKey.fanMode(i)) {
                print("  Fan \(i) mode (F\(i)Md): \(modeBytes.0)")
            }
        }

        // Show key info for all writable fan keys
        print("\n--- Key Info ---")
        let testKeys = ["F0Mn", "F0Md", "F0Tg", "F1Mn", "F1Md", "F1Tg"]
        for keyStr in testKeys {
            let key = FourCharCode(keyStr)
            if let info = try? reader.getKeyInfo(key) {
                print("  \(keyStr): type=\(info.dataType.fourCharString) size=\(info.dataSize) attrs=\(info.dataAttributes)")
            } else {
                print("  \(keyStr): could not get info")
            }
        }

        // Test 1: Try writing F0Md (mode) to 1 (forced)
        print("\n--- Test 1: Write F0Md = 1 (force mode) ---")
        do {
            let info = try reader.getKeyInfo(SMCKey.fanMode(0))
            var input = SMCParamStruct()
            input.key = SMCKey.fanMode(0)
            input.data8 = SMCSelector.kSMCWriteKey.rawValue
            input.keyInfo.dataSize = info.dataSize
            input.keyInfo.dataType = info.dataType
            input.keyInfo.dataAttributes = info.dataAttributes
            withUnsafeMutableBytes(of: &input.bytes) { $0[0] = 1 }
            let output = try connection.callDriver(input: &input)
            print("  [OK] result=\(output.result)")

            // Verify
            if let (_, b) = try? reader.readKey(SMCKey.fanMode(0)) {
                print("  Verify F0Md = \(b.0)")
            }
        } catch {
            print("  [FAIL] \(error)")
        }

        // Test 2: Try writing F0Mn (min speed) as flt
        print("\n--- Test 2: Write F0Mn = 2000.0 (flt format) ---")
        do {
            let info = try reader.getKeyInfo(SMCKey.fanMin(0))
            var input = SMCParamStruct()
            input.key = SMCKey.fanMin(0)
            input.data8 = SMCSelector.kSMCWriteKey.rawValue
            input.keyInfo.dataSize = info.dataSize
            input.keyInfo.dataType = info.dataType
            input.keyInfo.dataAttributes = info.dataAttributes
            let value: Float = 2000.0
            withUnsafeBytes(of: value) { src in
                withUnsafeMutableBytes(of: &input.bytes) { dst in
                    for j in 0..<4 { dst[j] = src[j] }
                }
            }
            let output = try connection.callDriver(input: &input)
            print("  [OK] result=\(output.result)")

            // Verify
            let newMin = try reader.fanMinSpeed(fanIndex: 0)
            print("  Verify F0Mn = \(Int(newMin)) RPM")
        } catch {
            print("  [FAIL] \(error)")
        }

        // Test 3: Try writing F0Tg (target speed)
        print("\n--- Test 3: Write F0Tg = 2000.0 (target) ---")
        do {
            let info = try reader.getKeyInfo(SMCKey.fanTarget(0))
            var input = SMCParamStruct()
            input.key = SMCKey.fanTarget(0)
            input.data8 = SMCSelector.kSMCWriteKey.rawValue
            input.keyInfo.dataSize = info.dataSize
            input.keyInfo.dataType = info.dataType
            input.keyInfo.dataAttributes = info.dataAttributes
            let value: Float = 2000.0
            withUnsafeBytes(of: value) { src in
                withUnsafeMutableBytes(of: &input.bytes) { dst in
                    for j in 0..<4 { dst[j] = src[j] }
                }
            }
            let output = try connection.callDriver(input: &input)
            print("  [OK] result=\(output.result)")

            // Verify
            if let (_, bytes) = try? reader.readKey(SMCKey.fanTarget(0)) {
                let val = Double(flt: bytes)
                print("  Verify F0Tg = \(Int(val)) RPM")
            }
        } catch {
            print("  [FAIL] \(error)")
        }

        // Wait and check actual speed
        print("\n--- Waiting 5 seconds to check fan speed change ---")
        sleep(5)
        for i in 0..<2 {
            let actual = (try? reader.fanActualSpeed(fanIndex: i)) ?? 0
            let min = (try? reader.fanMinSpeed(fanIndex: i)) ?? 0
            print("  Fan \(i): actual=\(Int(actual)) min=\(Int(min))")
        }

        // Restore: set mode back to 0 and reset min
        print("\n--- Restoring defaults ---")
        for i in 0..<2 {
            // Reset mode to auto
            if let info = try? reader.getKeyInfo(SMCKey.fanMode(i)) {
                var input = SMCParamStruct()
                input.key = SMCKey.fanMode(i)
                input.data8 = SMCSelector.kSMCWriteKey.rawValue
                input.keyInfo = info
                withUnsafeMutableBytes(of: &input.bytes) { $0[0] = 0 }
                _ = try? connection.callDriver(input: &input)
            }
        }
        print("  Modes reset to auto.")

        connection.close()
        print("\n=== Done ===")
    }
}
