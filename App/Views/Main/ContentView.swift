import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tag(0)
                .tabItem { Label("Dashboard", systemImage: "thermometer.medium") }

            SettingsView()
                .tag(1)
                .tabItem { Label("Settings", systemImage: "gear") }
        }
        .frame(minWidth: 700, minHeight: 500)
    }
}
