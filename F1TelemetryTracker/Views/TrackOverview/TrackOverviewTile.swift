import SwiftUI
import Charts
import UIKit

// MARK: - Track Overview Tile
struct TrackOverviewTile: View {
    @EnvironmentObject var telemetryViewModel: TelemetryViewModel
    @StateObject private var trackProfileStore = TrackProfileStore()
    
    // MARK: - Track Profile Store
    private class TrackProfileStore: ObservableObject {
        @Published var currentProfile: TrackProfile = TrackLibrary.loadTrackProfile(for: .unknown)
        private var lastTrackId: Int8 = -1
        
        func updateIfNeeded(for newTrackId: Int8) {
            guard newTrackId != lastTrackId else { return }
            
            let trackId = TrackId(rawValue: newTrackId) ?? .unknown
            
            #if DEBUG
            if newTrackId != -1 && trackId == .unknown {
                print("⚠️ TRACK MAPPING FAILED: Raw ID \(newTrackId) → .unknown")
            } else if trackId != .unknown {
                print("🏁 TRACK MAPPED: Raw ID \(newTrackId) → \(trackId.displayName)")
            }
            #endif
            
            currentProfile = TrackLibrary.loadTrackProfile(for: trackId)
            lastTrackId = newTrackId
        }
    }
    
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: TrackOverviewStyle.spacing) {
                HStack(spacing: 10) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(TrackOverviewStyle.titleText)
                    Text("Lap Comparison (Time vs Speed)")
                        .font(AppTypography.tileTitle())
                        .foregroundStyle(TrackOverviewStyle.titleText)
                    Spacer()
                }
                LapSpeedChartView(bestLapPoints: telemetryViewModel.bestLapPoints,
                                  currentLapPoints: telemetryViewModel.currentLapPoints)
            }
            .padding(TrackOverviewStyle.cardPadding)
            .primaryRowBackground(cornerRadius: TrackOverviewStyle.cardRadius, corners: [.topLeft, .topRight])

            HStack(spacing: TrackOverviewStyle.spacing) {
                WeatherPill(icon: nil, label: "TRACK", value: formatTemperature(telemetryViewModel.trackTemperature))
                WeatherPill(icon: nil, label: "RAIN", value: formatRain(telemetryViewModel.rainIntensity))
                WeatherPill(icon: TrackOverviewStyle.weatherIcon(for: telemetryViewModel.weather), label: "WEATHER", value: "")
            }
            .padding(TrackOverviewStyle.cardPadding)
            .secondaryRowBackground(cornerRadius: TrackOverviewStyle.cardRadius, corners: [.bottomLeft, .bottomRight])
        }
        .primaryTileBackground()
        .onAppear {
            trackProfileStore.updateIfNeeded(for: telemetryViewModel.trackId)
        }
        .onChange(of: telemetryViewModel.trackId) { _, newTrackId in
            trackProfileStore.updateIfNeeded(for: newTrackId)
        }
    }
    
    private func formatTemperature(_ temp: Int8) -> String {
        if temp == 0 {
            return "--°"
        }
        return "\(temp)°"
    }
    
    private func formatRain(_ intensity: UInt8) -> String {
        if intensity == 0 {
            return "0mm"
        }
        return "\(intensity)mm"
    }
}

// MARK: - Weather Pill Component (matching LapTile style)
struct WeatherPill: View {
    let icon: String?
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            // Icon and label on the left
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(AppTypography.label())
                        .foregroundStyle(AppColors.labelText)
                }
                
                Text(label)
                    .font(AppTypography.label())
                    .foregroundStyle(AppColors.labelText)
                    .tracking(0.9)
            }
            
            Spacer()
            
            // Value on the right
            if !value.isEmpty {
                Text(value)
                    .font(AppTypography.secondaryData())
                    .monospacedDigit()
                    .foregroundStyle(AppColors.primaryData)
            } else if let icon = icon {
                // Show icon on the right if no value (for weather pill)
                Image(systemName: icon)
                    .font(AppTypography.secondaryData())
                    .foregroundStyle(AppColors.primaryData)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.secondaryTileBackground)
        .neutralInfoTile(cornerRadius: 8)
    }
}

// MARK: - Preview
#Preview {
    TrackOverviewTile()
        .environmentObject({
            let vm = TelemetryViewModel()
            vm.trackId = 3 // Bahrain
            vm.trackTemperature = 32
            vm.rainIntensity = 0
            vm.weather = 0 // Clear
            vm.lapProgress = 0.3
            return vm
        }())
        .padding()
        .background(AppColors.appBackground)
}
