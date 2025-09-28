import SwiftUI

struct CircularGaugeView: View {
    let rpmValue: Double // 0.0 to 1.0 (0 to max RPM)
    let ersValue: Double // 0.0 to 1.0 (0 to max ERS)
    
    private let maxRPM: Double = 15000
    private let maxERS: Double = 4000 // 4MJ in kJ
    
    // Arc configuration: 75% sweep (270°) starting at 135°
    private let startAngle: Double = 135 // Start at 135 degrees
    private let sweepAngle: Double = 270 // 75% of 360° = 270°
    private var endAngle: Double { startAngle + sweepAngle }
    
    var body: some View {
        ZStack {
            // Background arcs (75% sweep)
            Circle()
                .trim(from: 0, to: 0.75) // 75% of circle
                .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(startAngle))
            
            Circle()
                .trim(from: 0, to: 0.75) // 75% of circle
                .stroke(Color.gray.opacity(0.2), lineWidth: 16)
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(startAngle))
            
            // RPM Arc (outer) - 75% sweep starting at 135°
            Circle()
                .trim(from: 0, to: rpmValue * 0.75) // Scale value to 75% arc
                .stroke(
                    AngularGradient(
                        colors: [.cyan, .yellow, .red],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .rotationEffect(.degrees(startAngle))
                .animation(.easeInOut(duration: 0.1), value: rpmValue)
            
            // ERS Arc (inner) - 75% sweep starting at 135°
            Circle()
                .trim(from: 0, to: ersValue * 0.75) // Scale value to 75% arc
                .stroke(
                    AngularGradient(
                        colors: [.yellow, .orange],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .frame(width: 160, height: 160)
                .rotationEffect(.degrees(startAngle))
                .animation(.easeInOut(duration: 0.1), value: ersValue)
            
            // Center labels with safe conversion
            VStack(spacing: 4) {
                // RPM value (safe conversion)
                Text(formatRPM(rpmValue))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("RPM")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Divider()
                    .frame(width: 40)
                
                    // ERS value (safe conversion)
                    Text(formatERS(ersValue))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.yellow)
                
                Text("ERS kJ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Functions
    private func formatRPM(_ value: Double) -> String {
        guard value.isFinite && value >= 0 else { return "--" }
        let rpm = Int(value * maxRPM)
        return "\(max(0, min(99999, rpm)))"
    }
    
    private func formatERS(_ value: Double) -> String {
        guard value.isFinite && value >= 0 else { return "--" }
        let ers = Int(value * maxERS)
        return "\(max(0, min(9999, ers)))"
    }
}

#Preview {
    CircularGaugeView(rpmValue: 0.65, ersValue: 0.8)
}
