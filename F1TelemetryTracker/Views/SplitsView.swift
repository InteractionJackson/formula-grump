import SwiftUI

struct SplitsView: View {
    let currentLapTime: String
    let sector1Time: String
    let sector2Time: String
    let sector3Time: String
    let lastLapTime: String
    let bestLapTime: String
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: AppLayout.tileSpacing) {
                HStack(spacing: 12) {
                    Image(systemName: "stopwatch")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AppColors.tileTitle)
                    Text("Splits")
                        .font(AppTypography.tileTitle())
                        .foregroundStyle(AppColors.tileTitle)
                    Spacer()
                }
                
                HStack(alignment: .firstTextBaseline) {
                    Text("Current Lap")
                        .font(AppTypography.label())
                        .foregroundStyle(AppColors.labelText)
                        .tracking(0.5)
                    Spacer()
                    Text(currentLapTime)
                        .font(AppTypography.primaryData())
                        .monospacedDigit()
                        .foregroundStyle(AppColors.primaryData)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                
                HStack(spacing: AppLayout.tileSpacing) {
                    SectorChip(title: "S1", value: sector1Time)
                    SectorChip(title: "S2", value: sector2Time)
                    SectorChip(title: "S3", value: sector3Time)
                }
            }
            .padding(AppLayout.tilePadding)
            .primaryRowBackground(cornerRadius: AppLayout.tileCornerRadius, corners: [.topLeft, .topRight])
            
            HStack(spacing: AppLayout.tileSpacing) {
                LapTile(title: "Last", value: lastLapTime)
                LapTile(title: "Best", value: bestLapTime)
            }
            .padding(AppLayout.tilePadding)
            .secondaryRowBackground(cornerRadius: AppLayout.tileCornerRadius, corners: [.bottomLeft, .bottomRight])
        }
        .primaryTileBackground()
    }
}

// MARK: - Subviews

private struct SectorChip: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title)
                .font(AppTypography.secondaryData())
                .foregroundStyle(AppColors.primaryData)
            Spacer(minLength: 8)
            Text(value)
                .font(AppTypography.secondaryData())
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryData.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.chipCornerRadius, style: .continuous)
                .fill(AppColors.secondaryTileBackground)
        )
    }
}

private struct LapTile: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(AppTypography.label())
                .foregroundStyle(AppColors.labelText)
                .tracking(0.5)
            Spacer()
            Text(value)
                .font(AppTypography.secondaryData())
                .monospacedDigit()
                .foregroundStyle(AppColors.primaryData)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(AppColors.secondaryTileBackground)
        .neutralInfoTile(cornerRadius: AppLayout.chipCornerRadius)
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
        .background(AppColors.appBackground)
    }
}