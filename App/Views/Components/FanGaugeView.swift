import SwiftUI

struct FanGaugeView: View {
    let fan: Fan

    private var speedFraction: Double {
        guard fan.maxRPM > fan.minRPM else { return 0 }
        return min(max((fan.actualRPM - fan.minRPM) / (fan.maxRPM - fan.minRPM), 0), 1.0)
    }

    private var speedColor: Color {
        if speedFraction > 0.8 { return .red }
        if speedFraction > 0.5 { return .orange }
        if speedFraction > 0.25 { return .yellow }
        return .green
    }

    private let arcStart: Double = 0.2
    private let arcEnd: Double = 0.9
    private var arcSpan: Double { arcEnd - arcStart }
    private let startAngle: Double = 144

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background arc
                Circle()
                    .trim(from: arcStart, to: arcEnd)
                    .stroke(Color.secondary.opacity(0.12), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(startAngle))

                // Speed arc
                Circle()
                    .trim(from: arcStart, to: arcStart + speedFraction * arcSpan)
                    .stroke(speedColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(startAngle))

                // Fan icon — shifted up to avoid RPM text
                VStack {
                    Image(systemName: "fan.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(speedColor.opacity(0.6))
                    Spacer()
                }
                .padding(.top, 22)

                // RPM readout — anchored at bottom
                VStack(spacing: 1) {
                    Spacer()
                    Text("\(Int(fan.actualRPM))")
                        .font(.system(.body, design: .monospaced).bold())
                    Text("RPM")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                }
                .padding(.bottom, 8)
            }
            .padding(6)
            .drawingGroup()

            Text(fan.name)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
