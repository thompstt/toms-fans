import AppKit
import Combine
import SwiftUI
import UserNotifications

@main
struct TomsFansApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitor = SMCMonitorService()
    @StateObject private var fanControl = XPCFanControlService()
    @StateObject private var helperInstall = HelperInstallService()
    @StateObject private var curveEngine = FanCurveEngine()
    @StateObject private var settings = AppSettings()
    @StateObject private var notifications = NotificationService()

    var body: some Scene {
        Window("Tom's Fans", id: "main") {
            ContentView()
                .environmentObject(monitor)
                .environmentObject(fanControl)
                .environmentObject(helperInstall)
                .environmentObject(curveEngine)
                .environmentObject(settings)
                .environmentObject(notifications)
                .onAppear {
                    bootstrapIfNeeded()
                    monitor.isCollectingHistory = true
                    monitor.setIdleMode(false)
                    NSApp.setActivationPolicy(.regular)
                }
                .onDisappear {
                    monitor.isCollectingHistory = false
                    monitor.clearHistory()
                    monitor.setIdleMode(true)
                    NSApp.setActivationPolicy(.accessory)
                    if !AppDelegate.isTerminating {
                        sendMenuBarNotification()
                    }
                }
        }
        .defaultSize(width: 900, height: 650)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(monitor)
                .environmentObject(fanControl)
                .environmentObject(curveEngine)
                .environmentObject(settings)
                .onAppear {
                    // Also wire up here in case window wasn't opened
                    bootstrapIfNeeded()
                }
        } label: {
            Text(monitor.menuBarLabel)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(helperInstall)
                .environmentObject(notifications)
        }
    }

    private static var hasBootstrapped = false
    private static var cancellables: Set<AnyCancellable> = []

    private func bootstrapIfNeeded() {
        guard !Self.hasBootstrapped else { return }
        Self.hasBootstrapped = true
        monitor.updatePollInterval(settings.pollInterval)
        setupPollCallback()
        notifications.setup()
        reapplySavedMode()
        observePollIntervalChanges()
        observeSleepWake()
    }

    private func observePollIntervalChanges() {
        settings.$pollInterval
            .dropFirst()
            .sink { [weak monitor] interval in
                monitor?.updatePollInterval(interval)
            }
            .store(in: &Self.cancellables)
    }

    private func observeSleepWake() {
        let center = NSWorkspace.shared.notificationCenter

        center.publisher(for: NSWorkspace.willSleepNotification)
            .sink { [weak fanControl, weak curveEngine, weak monitor] _ in
                fanControl?.restoreAutomatic()
                curveEngine?.reset()
                monitor?.pausePolling()
            }
            .store(in: &Self.cancellables)

        center.publisher(for: NSWorkspace.didWakeNotification)
            .sink { [weak monitor, weak fanControl, weak curveEngine, weak settings] _ in
                monitor?.resumePolling()
                // Re-apply saved control mode
                guard let settings, let fanControl else { return }
                switch settings.controlMode {
                case .automatic:
                    break
                case .preset:
                    if let presetId = settings.activePresetId,
                       let preset = settings.presets.first(where: { $0.id == presetId }) {
                        for (fanIndex, rpm) in preset.fanSpeeds {
                            if preset.isForceMode {
                                fanControl.setFanMode(fanIndex: fanIndex, mode: 1)
                            }
                            fanControl.setFanMinSpeed(fanIndex: fanIndex, rpm: rpm)
                        }
                    }
                case .manual:
                    settings.controlMode = .automatic
                case .fanCurve:
                    curveEngine?.reset()
                }
            }
            .store(in: &Self.cancellables)
    }

    private func setupPollCallback() {
        monitor.onPoll = { [weak curveEngine, weak settings, weak fanControl, weak monitor, weak notifications] temps in
            guard let settings, let fanControl else { return }

            if settings.controlMode == .fanCurve {
                let curve = settings.fanCurves.first(where: { $0.id == settings.activeCurveId })
                    ?? settings.fanCurves.first
                if let curve {
                    if settings.activeCurveId != curve.id {
                        settings.activeCurveId = curve.id
                    }
                    curveEngine?.evaluate(curve: curve, temperatures: temps,
                                          fans: monitor?.fans ?? [], fanControl: fanControl)
                }
            }

            notifications?.checkThresholds(temperatures: temps, thresholds: settings.alertThresholds)
        }
    }

    private func sendMenuBarNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Tom's Fans is still running"
        content.body = "Fan control is active in the menu bar. Click the menu bar icon to reopen the window or quit."
        let request = UNNotificationRequest(identifier: "window-closed", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Re-apply the persisted control mode on launch.
    private func reapplySavedMode() {
        switch settings.controlMode {
        case .automatic:
            break
        case .preset:
            if let presetId = settings.activePresetId,
               let preset = settings.presets.first(where: { $0.id == presetId }) {
                for (fanIndex, rpm) in preset.fanSpeeds {
                    if preset.isForceMode {
                        fanControl.setFanMode(fanIndex: fanIndex, mode: 1)
                    }
                    fanControl.setFanMinSpeed(fanIndex: fanIndex, rpm: rpm)
                }
            }
        case .manual:
            // Manual speeds aren't persisted — revert to automatic on relaunch
            settings.controlMode = .automatic
        case .fanCurve:
            // Fan curve will be picked up by the onPoll callback automatically
            break
        }
    }
}

/// Minimal AppDelegate for lifecycle control.
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var isTerminating = false

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.isTerminating = true
    }
}
