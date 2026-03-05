import SwiftUI

struct FanControlView: View {
    @EnvironmentObject var monitor: SMCMonitorService
    @EnvironmentObject var fanControl: XPCFanControlService
    @EnvironmentObject var curveEngine: FanCurveEngine
    @EnvironmentObject var settings: AppSettings
    @State private var manualSpeeds: [Int: Double] = [:]
    @State private var manualRPMText: [Int: String] = [:]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Mode selector
                GroupBox("Control Mode") {
                    Picker("Mode", selection: $settings.controlMode) {
                        ForEach(FanControlMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.vertical, 4)
                    .onChange(of: settings.controlMode) { newMode in
                        handleModeChange(newMode)
                    }
                }

                // Fan gauges + controls
                GroupBox("Fan Status") {
                    if monitor.fans.isEmpty {
                        Text("Discovering fans...")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        HStack(spacing: 32) {
                            ForEach(monitor.fans) { fan in
                                VStack(spacing: 12) {
                                    FanGaugeView(fan: fan)
                                        .frame(width: 120, height: 120)

                                    VStack(spacing: 4) {
                                        Text(fan.name).font(.headline)
                                        Text(fan.formattedActual).font(.title3.monospacedDigit())
                                        Text("Min: \(Int(fan.minRPM)) / Max: \(Int(fan.maxRPM))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    if settings.controlMode == .manual && fan.maxRPM > fan.minRPM {
                                        manualControlView(for: fan)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }

                // Presets — only shown in preset mode
                if settings.controlMode == .preset {
                    GroupBox("Presets") {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(settings.presets) { preset in
                                PresetButton(
                                    title: preset.name,
                                    icon: presetIcon(preset),
                                    isActive: settings.activePresetId == preset.id
                                ) {
                                    applyPreset(preset)
                                }
                            }
                        }
                        .padding()
                    }
                }

                // Connection status
                if let error = fanControl.lastError {
                    GroupBox {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func manualControlView(for fan: Fan) -> some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { manualSpeeds[fan.index] ?? fan.actualRPM },
                    set: { newValue in
                        manualSpeeds[fan.index] = newValue
                        manualRPMText[fan.index] = "\(Int(newValue))"
                    }
                ),
                in: fan.minRPM...fan.maxRPM,
                step: 100
            ) {
                Text("Speed")
            }

            HStack(spacing: 8) {
                TextField("RPM", text: Binding(
                    get: { manualRPMText[fan.index] ?? "\(Int(manualSpeeds[fan.index] ?? fan.actualRPM))" },
                    set: { text in
                        manualRPMText[fan.index] = text
                        if let val = Double(text),
                           val >= fan.minRPM, val <= fan.maxRPM {
                            manualSpeeds[fan.index] = val
                        }
                    }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onSubmit {
                    applyManualSpeed(for: fan)
                }

                Text("RPM")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 200)

        Button("Apply") {
            applyManualSpeed(for: fan)
        }
        .buttonStyle(.borderedProminent)
    }

    private func applyManualSpeed(for fan: Fan) {
        let rpm = Int(manualSpeeds[fan.index] ?? fan.actualRPM)
        fanControl.setFanMode(fanIndex: fan.index, mode: 1)
        fanControl.setFanMinSpeed(fanIndex: fan.index, rpm: rpm)
    }

    private func handleModeChange(_ mode: FanControlMode) {
        switch mode {
        case .automatic:
            fanControl.restoreAutomatic()
            settings.activePresetId = nil
        case .manual:
            for fan in monitor.fans {
                manualSpeeds[fan.index] = fan.actualRPM
                manualRPMText[fan.index] = "\(Int(fan.actualRPM))"
            }
        case .preset:
            break
        case .fanCurve:
            // Always validate activeCurveId points to an actual curve
            let validCurve = settings.fanCurves.first(where: { $0.id == settings.activeCurveId && $0.isEnabled })
            if validCurve == nil {
                settings.activeCurveId = settings.fanCurves.first(where: { $0.isEnabled })?.id
            }
            curveEngine.reset()
        }
    }

    private func applyPreset(_ preset: FanPreset) {
        settings.activePresetId = preset.id
        for (fanIndex, rpm) in preset.fanSpeeds {
            if preset.isForceMode {
                fanControl.setFanMode(fanIndex: fanIndex, mode: 1)
            }
            fanControl.setFanMinSpeed(fanIndex: fanIndex, rpm: rpm)
        }
    }

    private func presetIcon(_ preset: FanPreset) -> String {
        switch preset.name.lowercased() {
        case "silent": return "speaker.slash.fill"
        case "balanced": return "equal.circle.fill"
        case "performance": return "bolt.fill"
        case "full blast": return "wind"
        default: return "fan.fill"
        }
    }
}

struct PresetButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
