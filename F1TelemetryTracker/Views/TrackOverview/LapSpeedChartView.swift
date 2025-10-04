import SwiftUI
import Charts

struct LapSpeedChartView: View {
    let bestLapPoints: [LapSpeedPoint]
    let currentLapPoints: [LapSpeedPoint]

    var body: some View {
        Chart {
            ForEach(bestLapPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Speed", point.speed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(hex: "#ff00ff"))
                .lineStyle(StrokeStyle(lineWidth: 3))
            }

            ForEach(currentLapPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Speed", point.speed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color(hex: "#00ff7f"))
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxisLabel("Speed (km/h)")
        .chartXAxisLabel("Time (s)")
        .padding()
        .frame(minHeight: 220)
        .background(Color(hex: "#18191c"))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}


