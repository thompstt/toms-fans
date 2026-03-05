import Foundation

struct Fan: Identifiable, Equatable {
    let id: Int
    let index: Int
    var name: String
    var actualRPM: Double = 0
    var minRPM: Double = 0
    var maxRPM: Double = 0
    var targetRPM: Double = 0

    init(index: Int) {
        self.id = index
        self.index = index
        self.name = index == 0 ? "Left Fan" : "Right Fan"
    }

    var formattedActual: String {
        String(format: "%.0f RPM", actualRPM)
    }

    var speedPercentage: Double {
        guard maxRPM > minRPM else { return 0 }
        return ((actualRPM - minRPM) / (maxRPM - minRPM)) * 100
    }
}
