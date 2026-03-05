import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var helperInstall: HelperInstallService

    var body: some View {
        Form {
            Section("General") {
                Picker("Temperature Unit", selection: $settings.temperatureUnit) {
                    Text("Celsius").tag(AppSettings.TemperatureUnit.celsius)
                    Text("Fahrenheit").tag(AppSettings.TemperatureUnit.fahrenheit)
                }

                HStack {
                    Text("Poll Interval:")
                    Slider(value: $settings.pollInterval, in: 1...10, step: 0.5)
                    Text("\(String(format: "%.1f", settings.pollInterval))s")
                        .monospacedDigit()
                        .frame(width: 40)
                }

                Toggle("Show Temperature in Menu Bar", isOn: $settings.showTemperatureInMenuBar)
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
            }

            Section("Helper Tool") {
                HStack {
                    Text("Status:")
                    Text(helperInstall.statusDescription)
                        .foregroundStyle(helperInstall.isHelperRunning ? .green : .orange)
                }

                if !helperInstall.isHelperRunning {
                    Button("Install Helper") {
                        helperInstall.register()
                    }
                    Text("The helper tool runs with elevated privileges to control fan speeds. You'll be asked to approve it in System Settings > Login Items & Extensions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Button("Uninstall Helper") {
                        helperInstall.unregister()
                    }
                }

                if let error = helperInstall.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Temperature Alerts") {
                Text("Get notified when temperatures exceed these thresholds:")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(Array(settings.alertThresholds.sorted(by: { $0.key < $1.key })), id: \.key) { key, threshold in
                    HStack {
                        Text(KnownSensors.name(for: key) ?? key)
                        Spacer()
                        TextField("°C", value: Binding(
                            get: { threshold },
                            set: { settings.alertThresholds[key] = $0 }
                        ), format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        Text("°C")

                        Button(action: { settings.alertThresholds.removeValue(forKey: key) }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section("About") {
                Text("Tom's Fans v1.0")
                Text("Temperature monitoring and fan control for MacBook Pro")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 400)
    }
}
