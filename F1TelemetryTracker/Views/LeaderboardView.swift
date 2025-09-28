import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var telemetryViewModel: TelemetryViewModel
    
    // Design tokens matching other tiles
    struct T {
        static let canvas = Color.white
        static let topCard = Color.white
        static let stroke = Color(hex: "#EFEFEF")
        static let text = Color(hex: "#0B0F14")
        static let textSub = Color(hex: "#6D7A88")
        static let rCard: CGFloat = 24
        static let padCard: CGFloat = 16
        static let gap: CGFloat = 12
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: T.gap) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "flag.checkered")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(T.text)
                Text("Leaderboard")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(T.text)
                Spacer()
            }
            .padding(.horizontal, T.padCard)
            .padding(.top, T.padCard)
            
            // Leaderboard table
            VStack(spacing: 0) {
                // Header row
                LeaderboardHeaderRow()
                
                // Driver rows
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(telemetryViewModel.leaderboardData.indices, id: \.self) { index in
                            let driver = telemetryViewModel.leaderboardData[index]
                            LeaderboardDriverRow(
                                position: driver.position,
                                driverName: driver.name,
                                status: driver.status,
                                pitStops: driver.pitStops,
                                sector1: driver.sector1Time,
                                sector2: driver.sector2Time,
                                sector3: driver.sector3Time,
                                delta: driver.delta,
                                penalty: driver.penalty
                            )
                            .background(index % 2 == 0 ? Color.clear : Color(hex: "#F8F9FA"))
                        }
                    }
                }
            }
            .background(T.topCard)
            .clipShape(RoundedRectangle(cornerRadius: T.rCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: T.rCard, style: .continuous)
                    .stroke(T.stroke, lineWidth: 1)
            )
            
            // Bottom info bar
            HStack {
                Text("LAPS")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(T.textSub)
                    .tracking(0.5)
                
                Text("\(telemetryViewModel.currentLap)/\(telemetryViewModel.totalLaps)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(T.text)
                
                Spacer()
                
                Text("EVENT")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(T.textSub)
                    .tracking(0.5)
                
                Spacer()
                
                Text(telemetryViewModel.safetyCarStatus)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(T.text)
            }
            .padding(T.padCard)
            .background(Color(hex: "#F6F8F9"))
            .clipShape(RoundedRectangle(cornerRadius: T.rCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: T.rCard, style: .continuous)
                    .stroke(T.stroke, lineWidth: 1)
            )
        }
        .padding(T.padCard)
        .background(T.canvas)
    }
}

struct LeaderboardHeaderRow: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("POS")
                .frame(width: 40, alignment: .center)
            Text("DRIVER")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("STATUS")
                .frame(width: 80, alignment: .center)
            Text("PIT STOPS")
                .frame(width: 70, alignment: .center)
            Text("S1")
                .frame(width: 60, alignment: .center)
            Text("S2")
                .frame(width: 60, alignment: .center)
            Text("S3")
                .frame(width: 60, alignment: .center)
            Text("DELTA")
                .frame(width: 80, alignment: .center)
            Text("PENALTY")
                .frame(width: 60, alignment: .center)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(LeaderboardView.T.textSub)
        .tracking(0.5)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "#F6F8F9"))
    }
}

struct LeaderboardDriverRow: View {
    let position: Int
    let driverName: String
    let status: String
    let pitStops: Int
    let sector1: String
    let sector2: String
    let sector3: String
    let delta: String
    let penalty: String
    
    var body: some View {
        HStack(spacing: 8) {
            Text("\(position)")
                .frame(width: 40, alignment: .center)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(driverName)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(status)
                .frame(width: 80, alignment: .center)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(statusColor)
            
            Text("\(pitStops)")
                .frame(width: 70, alignment: .center)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(sector1)
                .frame(width: 60, alignment: .center)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(sector2)
                .frame(width: 60, alignment: .center)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(sector3)
                .frame(width: 60, alignment: .center)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(LeaderboardView.T.text)
            
            Text(delta)
                .frame(width: 80, alignment: .center)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(deltaColor)
            
            HStack(spacing: 2) {
                if penalty != "-" {
                    Image(systemName: "triangle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Color.orange)
                }
                Text(penalty)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LeaderboardView.T.text)
            }
            .frame(width: 60, alignment: .center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        switch status.lowercased() {
        case "on track":
            return Color.green
        case "in pit":
            return Color.orange
        case "in garage":
            return LeaderboardView.T.textSub
        default:
            return LeaderboardView.T.text
        }
    }
    
    private var deltaColor: Color {
        if delta.hasPrefix("+") {
            return Color.red
        } else if delta.hasPrefix("-") {
            return Color.green
        } else {
            return LeaderboardView.T.text
        }
    }
}


#Preview {
    LeaderboardView()
        .environmentObject(TelemetryViewModel())
}
