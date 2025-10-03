import SwiftUI

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
    
    
    private var carMarkers: [CarMarker] {
        var markers: [CarMarker] = []
        
        // Use real motion data if available
        if !telemetryViewModel.carProgresses.isEmpty {
            // Create markers from motion data and leaderboard data
            for (index, driver) in telemetryViewModel.leaderboardData.enumerated() {
                guard index < telemetryViewModel.carProgresses.count else { break }
                
                let progress = telemetryViewModel.carProgresses[index]
            
            // Extract driver code from name (first 3 characters)
            let driverCode = String(driver.name.prefix(3)).uppercased()
            
            // Determine if this is the focus driver (player or leader)
            let isFocus = index == 0 || driverCode == "PLR"
            
            // Use team colors based on position
            let teamColor = TrackOverviewStyle.teamColor(for: index)
            
            let marker = CarMarker(
                driverCode: driverCode,
                progress: CGFloat(progress),
                color: teamColor,
                isFocus: isFocus,
                position: .zero, // Will be calculated by TrackMapView
                driverStatus: driver.status == "On Track" ? 4 : 0
            )
            
            markers.append(marker)
            }
        } else {
            // Fallback to simplified leaderboard-based positioning
            for (index, driver) in telemetryViewModel.leaderboardData.enumerated() {
                let baseProgress = Float(index) / Float(max(1, telemetryViewModel.leaderboardData.count - 1))
                let progressVariation = Float.random(in: -0.05...0.05) // Add some variation
                let progress = max(0.0, min(1.0, baseProgress + progressVariation))
                
                // Extract driver code from name (first 3 characters)
                let driverCode = String(driver.name.prefix(3)).uppercased()
                
                // Determine if this is the focus driver (player or leader)
                let isFocus = index == 0 || driverCode == "PLR"
                
                // Use team colors based on position
                let teamColor = TrackOverviewStyle.teamColor(for: index)
                
                let marker = CarMarker(
                    driverCode: driverCode,
                    progress: CGFloat(progress),
                    color: teamColor,
                    isFocus: isFocus,
                    position: .zero, // Will be calculated by TrackMapView
                    driverStatus: driver.status == "On Track" ? 4 : 0
                )
                
                markers.append(marker)
            }
        }
        
        // If no markers created, create a player marker using lap progress
        if markers.isEmpty {
            let playerMarker = CarMarker(
                driverCode: "PLR",
                progress: CGFloat(telemetryViewModel.lapProgress),
                color: TrackOverviewStyle.teamColor(for: 0),
                isFocus: true,
                position: .zero,
                driverStatus: 4 // On track
            )
            markers.append(playerMarker)
        }
        
        return markers
    }
    
    var body: some View {
        // SINGLE TILE with white top and darker bottom section (matching Splits tile pattern)
        VStack(spacing: 0) {
            // TOP SECTION: White background with title and track map
            VStack(alignment: .leading, spacing: TrackOverviewStyle.spacing) {
                // Title row
                HStack(spacing: 10) {
                    Image(systemName: "road.lanes")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(TrackOverviewStyle.titleText)
                    
                    Text("Track overview")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(TrackOverviewStyle.titleText)
                    
                    Spacer()
                }
                
                // Track map - expands to fill available space
                GeometryReader { geometry in
                    TrackMapView(
                        trackGeometry: trackProfileStore.currentProfile.geometry,
                        carMarkers: carMarkers,
                        canvasSize: CGSize(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                    )
                    .background(Color.clear)
                }
                .frame(maxHeight: .infinity)
            }
            .padding(TrackOverviewStyle.cardPadding)
            .background(TrackOverviewStyle.cardBackground)
            
            // BOTTOM SECTION: Darker background with weather pills (matching Splits tile style)
            HStack(spacing: TrackOverviewStyle.spacing) {
                // Track temperature pill
                WeatherPill(
                    icon: nil,
                    label: "TRACK",
                    value: formatTemperature(telemetryViewModel.trackTemperature)
                )
                
                // Rain pill
                WeatherPill(
                    icon: nil,
                    label: "RAIN",
                    value: formatRain(telemetryViewModel.rainIntensity)
                )
                
                // Weather pill
                WeatherPill(
                    icon: TrackOverviewStyle.weatherIcon(for: telemetryViewModel.weather),
                    label: "WEATHER",
                    value: ""
                )
            }
            .padding(TrackOverviewStyle.cardPadding)
            .background(Color(hex: "#F6F8F9")) // Same as Splits tile bottom section
        }
        .clipShape(RoundedRectangle(cornerRadius: TrackOverviewStyle.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: TrackOverviewStyle.cardRadius, style: .continuous)
                .stroke(Color(hex: "#EFEFEF"), lineWidth: 1)
        )
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(hex: "#6D7A88")) // textSub color
                }
                
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(hex: "#6D7A88")) // textSub color
                    .tracking(0.5)
            }
            
            Spacer()
            
            // Value on the right
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 18, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(hex: "#0B0F14")) // text color
            } else if let icon = icon {
                // Show icon on the right if no value (for weather pill)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color(hex: "#0B0F14")) // text color
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(hex: "#DBE5E6"), lineWidth: 1) // Same as LapTile stroke
        )
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
        .background(Color(hex: "#F6F8FA"))
}
