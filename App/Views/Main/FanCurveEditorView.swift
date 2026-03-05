import SwiftUI

struct FanCurveEditorView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var monitor: SMCMonitorService
    @State private var selectedCurveIndex: Int = 0

    /// Stable sensor options (key + name) — only rebuilt when sensor count changes.
    private var sensorOptions: [(key: String, name: String)] {
        monitor.temperatures.map { (key: $0.key, name: $0.name) }
    }

    var body: some View {
        HSplitView {
            // Left: Thin profile sidebar
            VStack(spacing: 0) {
                List(selection: Binding(
                    get: { selectedCurveIndex },
                    set: { selectedCurveIndex = $0 }
                )) {
                    ForEach(Array(settings.fanCurves.enumerated()), id: \.element.id) { index, curve in
                        CurveSidebarRow(curve: curve, isActive: settings.activeCurveId == curve.id)
                            .tag(index)
                    }
                }
                .listStyle(.sidebar)

                Divider()

                // Uniform +/- toolbar
                HStack(spacing: 0) {
                    Button(action: addCurve) {
                        Image(systemName: "plus")
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .frame(height: 20)

                    Button(action: removeCurve) {
                        Image(systemName: "minus")
                            .frame(maxWidth: .infinity, minHeight: 28)
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.fanCurves.isEmpty)
                }
                .frame(height: 32)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .frame(minWidth: 140, idealWidth: 160, maxWidth: 200)

            // Right: Curve editor (majority of space)
            if settings.fanCurves.indices.contains(selectedCurveIndex) {
                CurveDetailView(curve: $settings.fanCurves[selectedCurveIndex],
                                sensorOptions: sensorOptions,
                                currentTemp: currentSensorTemp,
                                fans: monitor.fans,
                                isActive: settings.activeCurveId == settings.fanCurves[selectedCurveIndex].id,
                                onSetActive: {
                                    settings.activeCurveId = settings.fanCurves[selectedCurveIndex].id
                                })
            } else {
                Text("Select or create a fan curve")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var currentSensorTemp: Double? {
        guard settings.fanCurves.indices.contains(selectedCurveIndex) else { return nil }
        let key = settings.fanCurves[selectedCurveIndex].sensorKey
        return monitor.temperatures.first(where: { $0.key == key })?.value
    }

    private func addCurve() {
        let curve = FanCurve(
            name: "New Curve",
            sensorKey: "TCXC",
            controlPoints: [
                CurvePoint(temperature: 40, percent: 0),
                CurvePoint(temperature: 70, percent: 40),
                CurvePoint(temperature: 90, percent: 100),
            ],
            appliesToFans: [0, 1]
        )
        settings.fanCurves.append(curve)
        selectedCurveIndex = settings.fanCurves.count - 1
    }

    private func removeCurve() {
        guard settings.fanCurves.indices.contains(selectedCurveIndex) else { return }
        settings.fanCurves.remove(at: selectedCurveIndex)
        selectedCurveIndex = max(0, selectedCurveIndex - 1)
    }
}

struct CurveSidebarRow: View {
    let curve: FanCurve
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.blue : Color.secondary.opacity(0.3))
                .frame(width: 8, height: 8)
            Text(curve.name)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

struct CurveDetailView: View {
    @Binding var curve: FanCurve
    let sensorOptions: [(key: String, name: String)]
    let currentTemp: Double?
    let fans: [Fan]
    let isActive: Bool
    let onSetActive: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header row
                HStack {
                    TextField("Curve Name", text: $curve.name)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)

                    Spacer()

                    if isActive {
                        Label("Active Profile", systemImage: "checkmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(.blue)
                    } else {
                        Button {
                            onSetActive()
                        } label: {
                            Label("Set as Active", systemImage: "circle")
                                .font(.callout)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
                }

                // Settings grid
                GroupBox {
                    VStack(spacing: 10) {
                        // Sensor picker
                        HStack {
                            Text("Sensor:")
                                .frame(width: 70, alignment: .trailing)
                            Picker("Sensor", selection: $curve.sensorKey) {
                                ForEach(sensorOptions.filter { $0.key.hasPrefix("TC") || $0.key.hasPrefix("TG") }, id: \.key) { option in
                                    Text("\(option.name) (\(option.key))").tag(option.key)
                                }
                            }
                            .labelsHidden()
                            .frame(maxWidth: 280)

                            if let temp = currentTemp {
                                Text(String(format: "%.1f°C", temp))
                                    .font(.body.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }

                        // Hysteresis
                        HStack {
                            Text("Hysteresis:")
                                .frame(width: 70, alignment: .trailing)
                            Slider(value: $curve.hysteresis, in: 0...10, step: 0.5)
                                .frame(maxWidth: 180)
                            Text(String(format: "%.1f°C", curve.hysteresis))
                                .monospacedDigit()
                                .frame(width: 50, alignment: .leading)
                            Spacer()
                        }

                        // Fan selection
                        HStack {
                            Text("Fans:")
                                .frame(width: 70, alignment: .trailing)
                            Toggle("Left", isOn: Binding(
                                get: { curve.appliesToFans.contains(0) },
                                set: { if $0 { if !curve.appliesToFans.contains(0) { curve.appliesToFans.append(0) } }
                                       else { curve.appliesToFans.removeAll { $0 == 0 } } }
                            ))
                            .toggleStyle(.checkbox)
                            Toggle("Right", isOn: Binding(
                                get: { curve.appliesToFans.contains(1) },
                                set: { if $0 { if !curve.appliesToFans.contains(1) { curve.appliesToFans.append(1) } }
                                       else { curve.appliesToFans.removeAll { $0 == 1 } } }
                            ))
                            .toggleStyle(.checkbox)
                            Spacer()
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Curve graph
                GroupBox("Curve Preview") {
                    CurveGraphView(
                        controlPoints: $curve.controlPoints,
                        currentTemp: currentTemp
                    )
                    .frame(minHeight: 250)
                }

                // Control points table
                GroupBox {
                    VStack(spacing: 0) {
                        // Header
                        HStack(spacing: 0) {
                            Text("Temperature (°C)")
                                .font(.caption.bold())
                                .frame(width: 130, alignment: .leading)
                            Text("Speed (%)")
                                .font(.caption.bold())
                                .frame(width: 80, alignment: .leading)
                            Text("≈ RPM")
                                .font(.caption.bold())
                                .frame(width: 80, alignment: .leading)
                            Spacer()
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 6)

                        Divider()

                        // Points
                        ForEach(Array(curve.controlPoints.enumerated()), id: \.element.id) { index, point in
                            HStack(spacing: 8) {
                                TextField("°C", value: Binding(
                                    get: { curve.controlPoints[index].temperature },
                                    set: { curve.controlPoints[index].temperature = $0 }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)

                                TextField("%", value: Binding(
                                    get: { curve.controlPoints[index].percent },
                                    set: { curve.controlPoints[index].percent = min(max($0, 0), 100) }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 70)

                                // Show approximate RPM based on first applicable fan
                                Text(approximateRPM(percent: point.percent))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 70, alignment: .leading)

                                Button(action: { curve.controlPoints.remove(at: index) }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .disabled(curve.controlPoints.count <= 2)
                                .opacity(curve.controlPoints.count <= 2 ? 0.3 : 1)

                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        }

                        Divider()
                            .padding(.top, 4)

                        // Add button
                        Button(action: addPoint) {
                            Label("Add Point", systemImage: "plus")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 6)
                    }
                    .padding(.vertical, 4)
                } label: {
                    Text("Control Points (\(curve.controlPoints.count))")
                }
            }
            .padding()
        }
    }

    private func approximateRPM(percent: Int) -> String {
        guard let fan = fans.first(where: { curve.appliesToFans.contains($0.index) }),
              fan.maxRPM > fan.minRPM else {
            return "—"
        }
        let rpm = FanCurve.percentToRPM(percent, minRPM: fan.minRPM, maxRPM: fan.maxRPM)
        return "~\(rpm)"
    }

    private func addPoint() {
        let lastPct = curve.controlPoints.last?.percent ?? 50
        let lastTemp = curve.controlPoints.last?.temperature ?? 50
        curve.controlPoints.append(CurvePoint(temperature: lastTemp + 10, percent: min(lastPct + 10, 100)))
        curve.controlPoints.sort { $0.temperature < $1.temperature }
    }
}
