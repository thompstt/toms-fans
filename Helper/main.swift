import Foundation

/// Privileged helper tool entry point.
/// Runs as a LaunchDaemon under root, listening for XPC connections from the main app.
let delegate = FanControlDelegate()
let listener = NSXPCListener(machServiceName: XPCConstants.machServiceName)
listener.delegate = delegate
listener.resume()

RunLoop.current.run()
