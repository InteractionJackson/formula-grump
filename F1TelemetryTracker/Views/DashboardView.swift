import SwiftUI

struct DashboardView: View {
    @StateObject private var telemetryViewModel = TelemetryViewModel()
    @State private var showingConnectionStatus = false
    
    var body: some View {
        TabView {
            dashboardPage
                .tag(0)

            LeaderboardView()
                .environmentObject(telemetryViewModel)
                .tag(1)
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .background(AppColors.appBackground)
    }
    
    private var dashboardPage: some View {
        ZStack {
            AppColors.appBackground
                .ignoresSafeArea()

            VStack(spacing: 24) {
                ConnectionHeader(isConnected: telemetryViewModel.isConnected)

                HStack(spacing: 24) {
                    VStack(spacing: 24) {
                        SpeedTile(viewModel: telemetryViewModel)
                        CarConditionView(
                            engineTemperature: UInt16(telemetryViewModel.engineTemperature),
                            brakesTemperature: telemetryViewModel.brakesTemperature,
                            tyresSurfaceTemperature: telemetryViewModel.tyresSurfaceTemperature
                        )
                        .environmentObject(telemetryViewModel)
                    }

                    VStack(spacing: 24) {
                SplitsView(
                    currentLapTime: formatTime(telemetryViewModel.currentLapTime),
                    sector1Time: formatSectorTime(telemetryViewModel.sector1Time),
                    sector2Time: formatSectorTime(telemetryViewModel.sector2Time),
                    sector3Time: formatSectorTime(telemetryViewModel.sector3Time),
                    lastLapTime: formatTime(telemetryViewModel.lastLapTime),
                    bestLapTime: formatTime(telemetryViewModel.bestLapTime)
                )

                        TrackOverviewTile()
                            .environmentObject(telemetryViewModel)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
            }
            .padding(.top, 20)
        }
        .sheet(isPresented: $showingConnectionStatus) {
            ConnectionStatusView(viewModel: telemetryViewModel)
        }
        .onAppear {
            telemetryViewModel.connect()
        }
        .onDisappear {
            telemetryViewModel.disconnect()
        }
        }
    }
    
    // Computed property for gear display
    private func gearDisplayText(for gear: Int) -> String {
        switch gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(gear)"
        }
    }
    
    private func formatTime(_ seconds: Float) -> String {
        if seconds <= 0 {
            return "00:00:00"
        }
        
        let totalMs = Int(seconds * 1000)
        let minutes = totalMs / 60000
        let secs = (totalMs % 60000) / 1000
        let ms = totalMs % 1000
        
        return String(format: "%02d:%02d:%02d", minutes, secs, ms / 10)
    }
    
    private func formatSectorTime(_ seconds: Float) -> String {
        if seconds <= 0 {
            return "--:--.---"
        }
        
        let totalMs = Int(seconds * 1000)
        let minutes = totalMs / 60000
        let secs = (totalMs % 60000) / 1000
        let ms = totalMs % 1000
        
        return String(format: "%d:%02d.%03d", minutes, secs, ms)
    }


// MARK: - Helpers

extension Color {
    init(hex: String) {
        let hexSanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hexSanitized.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    DashboardView()
}