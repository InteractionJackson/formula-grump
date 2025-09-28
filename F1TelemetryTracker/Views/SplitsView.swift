import SwiftUI

struct SplitsView: View {
    let currentLapTime: String
    let sector1Time: String
    let sector2Time: String
    let sector3Time: String
    let lastLapTime: String
    let bestLapTime: String
    
    // Design tokens
    struct T {
        static let canvas      = Color(hex: "#F6F8FA")
        static let topCard     = Color(hex: "#FFFFFF")
        static let bottomCard  = Color(hex: "#F6F8F9")
        static let sectorBg    = Color(hex: "#F6F8F9")
        static let lapTileBg   = Color(hex: "#DBE5E6")
        static let stroke      = Color(hex: "#E6EDF2")
        static let text        = Color(hex: "#0B0F14")
        static let textSub     = Color(hex: "#6D7A88")
        
        static let rCard: CGFloat = 24
        static let rSector: CGFloat = 8
        static let rLapTile: CGFloat = 8
        
        static let padCard: CGFloat = 16
        static let gap: CGFloat = 12
    }
    
    var body: some View {
        // SINGLE TILE with white top and darker bottom section
        VStack(spacing: 0) {
            // TOP SECTION: White background with title, current lap, and sectors
            VStack(alignment: .leading, spacing: T.gap) {
                // Title row
                HStack(spacing: 10) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(T.text)
                    Text("Splits")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(T.text)
                    Spacer()
                }
                
                // Current lap row
                HStack(alignment: .firstTextBaseline) {
                    Text("CURRENT LAP")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(T.textSub)
                        .tracking(0.5)
                    Spacer()
                    Text(currentLapTime)
                        .font(.custom("SFProDisplay-Semibold", size: 32))
                        .monospacedDigit()
                        .foregroundStyle(T.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                // Sectors row (3 columns)
                HStack(spacing: T.gap) {
                    SectorChip(title: "S1", value: sector1Time)
                    SectorChip(title: "S2", value: sector2Time)
                    SectorChip(title: "S3", value: sector3Time)
                }
            }
            .padding(T.padCard)
            .background(T.topCard)
            
            // BOTTOM SECTION: Darker background with Last/Best
            HStack(spacing: T.gap) {
                LapTile(title: "LAST", value: lastLapTime)
                LapTile(title: "BEST", value: bestLapTime)
            }
            .padding(T.padCard)
            .background(T.bottomCard)
        }
        .clipShape(RoundedRectangle(cornerRadius: T.rCard, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: T.rCard, style: .continuous)
                .stroke(Color(hex: "#EFEFEF"), lineWidth: 1)
        )
    }
}

// MARK: - Subviews

private struct SectorChip: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(SplitsView.T.text)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 16, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(SplitsView.T.text)
                .opacity(0.9)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: SplitsView.T.rSector, style: .continuous)
                .fill(SplitsView.T.sectorBg)
        )
    }
}

private struct LapTile: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(SplitsView.T.textSub)
                .tracking(0.5)
            Spacer()
            Text(value)
                .font(.system(size: 18, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(SplitsView.T.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .overlay(
            RoundedRectangle(cornerRadius: SplitsView.T.rLapTile, style: .continuous)
                .stroke(SplitsView.T.lapTileBg, lineWidth: 1)
        )
    }
}


// MARK: - Helpers

struct SplitsView_Previews: PreviewProvider {
    static var previews: some View {
        SplitsView(
            currentLapTime: "--:--.---",
            sector1Time: "--:--.---",
            sector2Time: "--:--.---",
            sector3Time: "--:--.---",
            lastLapTime: "--:--.---",
            bestLapTime: "--:--.---"
        )
        .padding()
        .background(Color(hex: "#F6F8FA"))
    }
}