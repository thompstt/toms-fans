import SwiftUI
import Charts

struct TemperatureChartView: View {
    let sensorKeys: [String]
    let history: [String: [TemperatureReading]]
    let sensorNames: [String: String]

    var body: some View {
        Chart {
            ForEach(sensorKeys, id: \.self) { key in
                if let readings = history[key] {
                    ForEach(readings) { reading in
                        LineMark(
                            x: .value("Time", reading.date),
                            y: .value("Temp", reading.value)
                        )
                        .foregroundStyle(by: .value("Sensor", sensorNames[key] ?? key))
                        .interpolationMethod(.linear)
                    }
                }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartXAxis {
            AxisMarks(values: .stride(by: .minute, count: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour().minute())
                AxisGridLine()
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))°")
                    }
                }
                AxisGridLine()
            }
        }
        .chartLegend(position: .bottom, alignment: .leading)
        .drawingGroup()
    }
}
