import Foundation

/// App-side XPC client that communicates with the privileged helper to control fans.
final class XPCFanControlService: ObservableObject {
    @Published private(set) var isConnected = false
    @Published private(set) var lastError: String?

    private var xpcConnection: NSXPCConnection?

    /// Get a proxy to the helper's FanControlProtocol.
    /// Lazily creates the XPC connection on first access.
    var proxy: FanControlProtocol? {
        if xpcConnection == nil { connect() }
        return xpcConnection?.remoteObjectProxyWithErrorHandler { [weak self] error in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.lastError = error.localizedDescription
                self?.xpcConnection = nil
            }
        } as? FanControlProtocol
    }

    func connect() {
        let conn = NSXPCConnection(machServiceName: XPCConstants.machServiceName,
                                   options: .privileged)
        conn.remoteObjectInterface = NSXPCInterface(with: FanControlProtocol.self)
        conn.invalidationHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.isConnected = false
                self?.xpcConnection = nil
            }
        }
        conn.resume()
        xpcConnection = conn
        isConnected = true
        lastError = nil
    }

    func disconnect() {
        xpcConnection?.invalidate()
        xpcConnection = nil
        isConnected = false
    }

    /// Convenience: set fan speed and update state on completion.
    func setFanMinSpeed(fanIndex: Int, rpm: Int) {
        proxy?.setFanMinSpeed(fanIndex: fanIndex, rpm: rpm) { [weak self] success, error in
            if !success {
                DispatchQueue.main.async {
                    self?.lastError = error
                }
            }
        }
    }

    /// Convenience: set fan mode (0 = auto, 1 = forced).
    func setFanMode(fanIndex: Int, mode: UInt8) {
        proxy?.setFanMode(fanIndex: fanIndex, mode: mode) { [weak self] success, error in
            if !success {
                DispatchQueue.main.async {
                    self?.lastError = error
                }
            }
        }
    }

    /// Convenience: restore all fans to automatic control.
    func restoreAutomatic() {
        proxy?.restoreAutomaticControl { [weak self] success, error in
            if !success {
                DispatchQueue.main.async {
                    self?.lastError = error
                }
            }
        }
    }
}
