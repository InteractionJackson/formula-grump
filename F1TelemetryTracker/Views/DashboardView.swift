import SwiftUI

struct DashboardView: View {
    @StateObject private var telemetryViewModel = TelemetryViewModel()
    @State private var showingConnectionStatus = false
    
        // Design tokens - matching SplitsView design system
        struct T {
            static let canvas      = Color.white
            static let topCard     = Color(hex: "#FFFFFF")
            static let text        = Color(hex: "#0B0F14")
            static let textSub     = Color(hex: "#6D7A88")
            
            static let rCard: CGFloat = 24
            static let padCard: CGFloat = 16
            static let gap: CGFloat = 12
        }
    
    var body: some View {
        ZStack {
            // App background
            T.canvas
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Connection status indicator
                HStack {
                    Circle()
                        .fill(telemetryViewModel.isConnected ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                    
                    Text(telemetryViewModel.isConnected ? "Live" : "Offline")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Formula Grump")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 30)
                .padding(.top, 10)
                
                    // Two-column layout
                    HStack(spacing: 20) {
                        // LEFT COLUMN
                        VStack(spacing: 20) {
                            // Speed, RPM, DRS & Gear tile
                    VStack(spacing: T.gap) {
                        // TOP SECTION: White background with title and main content
                        VStack(alignment: .leading, spacing: T.gap) {
                            // Title row
                            HStack(spacing: 10) {
                                Image(systemName: "speedometer")
                                    .font(.system(size: 18, weight: .regular))
                                    .foregroundStyle(T.text)
                                Text("Speed, RPM DRS & Gear")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(T.text)
                                Spacer()
                            }
                            
                            // Main content: Speed, RPM/ERS gauge, Gear in three equal columns
                            HStack(spacing: 0) {
                                // Speed column (left)
                                VStack(spacing: 6) {
                                    Text("\(telemetryViewModel.speedMPH)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(T.text)
                                    
                                    Text("MPH")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(T.textSub)
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                                
                                // RPM/ERS gauge column (center)
                                CircularGaugeView(rpmValue: telemetryViewModel.rpmValue, ersValue: telemetryViewModel.ersValue)
                                    .scaleEffect(0.75)
                                    .frame(maxWidth: .infinity)
                                
                                // Gear column (right)
                                VStack(spacing: 6) {
                                    Text(gearDisplayText)
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundStyle(T.text)
                                    
                                    Text("GEAR")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(T.textSub)
                                        .tracking(0.5)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding(T.padCard)
                        .background(T.topCard)
                        
                        // BOTTOM SECTION: Darker background with input controls
                        HStack(spacing: 16) {
                            // Brake bar - takes remaining space
                            VStack(spacing: 8) {
                                HStack(spacing: 2) {
                                    ForEach(0..<10, id: \.self) { index in
                                        Rectangle()
                                            .fill(index < max(0, min(10, Int((telemetryViewModel.brakePercent * 10).isFinite ? telemetryViewModel.brakePercent * 10 : 0))) ? Color.red : Color.red.opacity(0.2))
                                            .frame(height: 16)
                                            .cornerRadius(1)
                                    }
                                }
                                
                                Text("Brake")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(T.textSub)
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            
                            // DRS indicator - min 48pt wide, min 40pt high with 8pt padding
                            Text("DRS")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(telemetryViewModel.isDRSActive ? Color.white : T.text)
                                .padding(8)
                                .frame(minWidth: 48, minHeight: 40)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(telemetryViewModel.isDRSActive ? Color(hex: "#9FB1B4") : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(telemetryViewModel.isDRSActive ? Color(hex: "#649499") : Color(hex: "#DBE5E6"), lineWidth: 1)
                                )
                                .shadow(
                                    color: telemetryViewModel.isDRSActive ? .black.opacity(0.15) : .clear,
                                    radius: telemetryViewModel.isDRSActive ? 4 : 0,
                                    x: 0,
                                    y: telemetryViewModel.isDRSActive ? 2 : 0
                                )
                            
                            // Throttle bar - takes remaining space
                            VStack(spacing: 8) {
                                HStack(spacing: 2) {
                                    ForEach(0..<10, id: \.self) { index in
                                        Rectangle()
                                            .fill(index < max(0, min(10, Int((telemetryViewModel.throttlePercent * 10).isFinite ? telemetryViewModel.throttlePercent * 10 : 0))) ? Color.green : Color.green.opacity(0.2))
                                            .frame(height: 16)
                                            .cornerRadius(1)
                                    }
                                }
                                
                                Text("Throttle")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(T.textSub)
                                    .tracking(0.5)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(16)
                        .background(Color(hex: "#F6F8F9"))
                    }
                        .clipShape(RoundedRectangle(cornerRadius: T.rCard, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: T.rCard, style: .continuous)
                                .stroke(Color(hex: "#EFEFEF"), lineWidth: 1)
                        )
                        
                            // Car Condition tile
                            CarConditionView(
                                engineTemperature: UInt16(telemetryViewModel.engineTemperature),
                                brakesTemperature: telemetryViewModel.brakesTemperature,
                                tyresSurfaceTemperature: telemetryViewModel.tyresSurfaceTemperature
                            )
                            .environmentObject(telemetryViewModel)
                    }
                    
                    // RIGHT COLUMN
                    VStack(spacing: 20) {
                        // Splits tile
                        SplitsView(
                        currentLapTime: formatTime(telemetryViewModel.currentLapTime),
                        sector1Time: formatSectorTime(telemetryViewModel.sector1Time),
                        sector2Time: formatSectorTime(telemetryViewModel.sector2Time),
                        sector3Time: formatSectorTime(telemetryViewModel.sector3Time),
                        lastLapTime: formatTime(telemetryViewModel.lastLapTime),
                        bestLapTime: formatTime(telemetryViewModel.bestLapTime)
                    )
                }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
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
    
    // Computed property for gear display
    private var gearDisplayText: String {
        switch telemetryViewModel.gear {
        case -1: return "R"
        case 0: return "N"
        default: return "\(telemetryViewModel.gear)"
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
            return "-:-:-"
        }
        
        let totalMs = Int(seconds * 1000)
        let secs = totalMs / 1000
        let ms = totalMs % 1000
        
        return String(format: "%d:%d:%d", secs / 10, (secs % 10), ms / 100)
    }
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