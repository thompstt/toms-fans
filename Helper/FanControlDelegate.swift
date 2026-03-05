import Foundation

/// NSXPCListener delegate that validates incoming connections and vends the fan control service.
final class FanControlDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // Validate the connecting process
        guard validateClient(connection) else {
            return false
        }

        connection.exportedInterface = NSXPCInterface(with: FanControlProtocol.self)
        connection.exportedObject = FanControlServiceImpl()
        connection.invalidationHandler = {
            // Connection was invalidated (app quit, crash, etc.)
        }
        connection.resume()
        return true
    }

    private func validateClient(_ connection: NSXPCConnection) -> Bool {
        // In development, accept all connections.
        // For production, validate the code signing identity:
        //
        // let pid = connection.processIdentifier
        // var code: SecCode?
        // let attrs = [kSecGuestAttributePid: pid] as CFDictionary
        // guard SecCodeCopyGuestWithAttributes(nil, attrs, [], &code) == errSecSuccess,
        //       let secCode = code else { return false }
        // var info: CFDictionary?
        // guard SecCodeCopySigningInformation(secCode, .init(rawValue: 0), &info) == errSecSuccess,
        //       let dict = info as? [String: Any],
        //       let bundleID = dict[kSecCodeInfoIdentifier as String] as? String,
        //       bundleID == "com.tomsfans.app" else { return false }
        return true
    }
}
