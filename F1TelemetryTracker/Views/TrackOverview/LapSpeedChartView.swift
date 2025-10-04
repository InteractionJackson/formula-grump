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
                .foregroundStyle(AppColors.purple)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }

            ForEach(currentLapPoints) { point in
                LineMark(
                    x: .value("Time", point.time),
                    y: .value("Speed", point.speed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppColors.green)
                .lineStyle(StrokeStyle(lineWidth: 3))
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .chartYAxisLabel("Speed (km/h)")
        .chartXAxisLabel("Time (s)")
        .padding(AppLayout.tilePadding)
        .frame(minHeight: 220)
        .background(AppColors.secondaryTileBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.tileCornerRadius, style: .continuous))
    }
}


