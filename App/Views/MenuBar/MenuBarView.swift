import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var monitor: SMCMonitorService
    @EnvironmentObject var fanControl: XPCFanControlService
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Temperatures
            HStack(spacing: 0) {
                MenuBarStat(
                    icon: "cpu",
                    label: "CPU",
                    value: String(format: "%.0f°C", monitor.cpuPackageTemp),
                    color: tempColor(monitor.cpuPackageTemp)
                )
                Divider()
                    .frame(height: 32)
                    .padding(.horizontal, 10)
                MenuBarStat(
                    icon: "display",
                    label: "GPU",
                    value: String(format: "%.0f°C", monitor.gpuTemp),
                    color: tempColor(monitor.gpuTemp)
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)

            SectionDivider()

            // Fans
            VStack(spacing: 6) {
                ForEach(monitor.fans) { fan in
                    HStack(spacing: 8) {
                        Image(systemName: "fan.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .frame(width: 14)
                        Text(fan.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(Int(fan.actualRPM))")
                            .font(.system(.subheadline, design: .monospaced))
                        Text("RPM")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)

            SectionDivider()

            // Mode
            HStack(spacing: 6) {
                Circle()
                    .fill(settings.controlMode == .automatic ? Color.green : Color.accentColor)
                    .frame(width: 7, height: 7)
                Text(modeDisplayName)
                    .font(.subheadline.bold())
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)

            SectionDivider()

            // Quick presets
            HStack(spacing: 6) {
                QuickPresetButton(title: "Auto", isActive: settings.controlMode == .automatic) {
                    settings.controlMode = .automatic
                    fanControl.restoreAutomatic()
                }

                ForEach(settings.presets.prefix(3)) { preset in
                    QuickPresetButton(title: preset.name,
                                     isActive: settings.activePresetId == preset.id) {
                        settings.controlMode = .preset
                        settings.activePresetId = preset.id
                        for (fanIndex, rpm) in preset.fanSpeeds {
                            if preset.isForceMode {
                                fanControl.setFanMode(fanIndex: fanIndex, mode: 1)
                            }
                            fanControl.setFanMinSpeed(fanIndex: fanIndex, rpm: rpm)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 6)

            SectionDivider()

            // Actions
            VStack(spacing: 2) {
                MenuBarAction(title: "Show Main Window", icon: "macwindow") {
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows {
                        if window.title == "Tom's Fans" {
                            window.makeKeyAndOrderFront(nil)
                            break
                        }
                    }
                }

                MenuBarAction(title: "Quit Tom's Fans", icon: "power") {
                    fanControl.restoreAutomatic()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        NSApp.terminate(nil)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .padding(10)
        .frame(width: 300)
    }

    private var modeDisplayName: String {
        switch settings.controlMode {
        case .automatic: return "Automatic"
        case .manual:    return "Manual"
        case .preset:
            if let id = settings.activePresetId,
               let preset = settings.presets.first(where: { $0.id == id }) {
                return "Preset — \(preset.name)"
            }
            return "Preset"
        case .fanCurve:
            if let curve = settings.fanCurves.first(where: { $0.id == settings.activeCurveId }) {
                return "Fan Curve — \(curve.name)"
            }
            return "Fan Curve"
        }
    }

    func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return .red }
        if temp > 75 { return .orange }
        if temp > 60 { return .yellow }
        return .green
    }
}

// MARK: - Components

struct SectionDivider: View {
    var body: some View {
        Divider()
            .padding(.horizontal, 6)
    }
}

struct MenuBarStat: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(.body, design: .monospaced).bold())
                    .foregroundStyle(color)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

struct QuickPresetButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.footnote, weight: isActive ? .semibold : .regular))
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity)
                .background(isActive ? Color.accentColor : Color.secondary.opacity(0.12))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }
}

struct MenuBarAction: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title)
                    .font(.subheadline)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
