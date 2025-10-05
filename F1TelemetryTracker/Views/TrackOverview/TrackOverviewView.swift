import SwiftUI

struct TrackOverviewView: View {
    let title: String
    let trackPath: TrackPath
    let carStates: [CarState]

    private let carSize: CGFloat = 12

    var body: some View {
        VStack(alignment: .leading, spacing: AppLayout.tileSpacing) {
            header
            trackCanvas
        }
        .padding(AppLayout.tilePadding)
        .primaryTileBackground()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track overview with \(carStates.count) cars")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(AppColors.tileTitle)

            Text(title)
                .font(AppTypography.tileTitle())
                .foregroundStyle(AppColors.tileTitle)

            Spacer()
        }
    }

    private var trackCanvas: some View {
        GeometryReader { proxy in
            let size = proxy.size
            Canvas { context, _ in
                let path = trackPath.scaledPath(in: size, padding: 24)
                context.stroke(path, with: .color(AppColors.primaryData.opacity(0.7)), lineWidth: 3)

                for car in carStates {
                    let position = trackPath.scaledPosition(for: car.lapProgress, in: size, padding: 24)
                    let rect = CGRect(x: position.x - carSize / 2, y: position.y - carSize / 2, width: carSize, height: carSize)
                    context.fill(Path(ellipseIn: rect), with: .color(car.teamColor))
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.tileCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.tileCornerRadius, style: .continuous)
                .stroke(AppColors.tileBorder, lineWidth: 1)
        )
        .innerShadow(cornerRadius: AppLayout.tileCornerRadius)
    }
}
