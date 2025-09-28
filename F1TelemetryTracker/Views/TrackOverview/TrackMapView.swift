import SwiftUI

// MARK: - Track Map View
struct TrackMapView: View {
    let trackGeometry: any TrackGeometry
    let carMarkers: [CarMarker]
    let canvasSize: CGSize
    
    private var scaledPath: Path {
        let bounds = trackGeometry.bounds
        let path = trackGeometry.path
        
        // Calculate scale to fit the canvas with padding
        let padding: CGFloat = 20
        let availableSize = CGSize(
            width: canvasSize.width - padding * 2,
            height: canvasSize.height - padding * 2
        )
        
        let scaleX = availableSize.width / bounds.width
        let scaleY = availableSize.height / bounds.height
        let scale = min(scaleX, scaleY)
        
        // Calculate offset to center the track
        let scaledBounds = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        let offsetX = (canvasSize.width - scaledBounds.width) / 2 - bounds.minX * scale
        let offsetY = (canvasSize.height - scaledBounds.height) / 2 - bounds.minY * scale
        
        // Transform the path
        var transform = CGAffineTransform.identity
        transform = transform.scaledBy(x: scale, y: scale)
        transform = transform.translatedBy(x: offsetX / scale, y: offsetY / scale)
        
        return Path(path.copy(using: &transform) ?? path)
    }
    
    private func scaledCarPositions() -> [(marker: CarMarker, position: CGPoint)] {
        let bounds = trackGeometry.bounds
        
        // Calculate the same scale and offset as the path
        let padding: CGFloat = 20
        let availableSize = CGSize(
            width: canvasSize.width - padding * 2,
            height: canvasSize.height - padding * 2
        )
        
        let scaleX = availableSize.width / bounds.width
        let scaleY = availableSize.height / bounds.height
        let scale = min(scaleX, scaleY)
        
        let scaledBounds = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        let offsetX = (canvasSize.width - scaledBounds.width) / 2 - bounds.minX * scale
        let offsetY = (canvasSize.height - scaledBounds.height) / 2 - bounds.minY * scale
        
        return carMarkers.map { marker in
            let trackPoint = trackGeometry.point(at: marker.progress)
            let scaledPoint = CGPoint(
                x: trackPoint.x * scale + offsetX,
                y: trackPoint.y * scale + offsetY
            )
            return (marker: marker, position: scaledPoint)
        }
    }
    
    var body: some View {
        Canvas { context, size in
            // Draw track outline
            context.stroke(
                scaledPath,
                with: .color(TrackOverviewStyle.trackPath),
                lineWidth: TrackOverviewStyle.trackStrokeWidth
            )
            
            // Draw car markers
            let scaledPositions = scaledCarPositions()
            
            for (marker, position) in scaledPositions {
                // Draw car dot
                let dotRect = CGRect(
                    x: position.x - TrackOverviewStyle.carDotSize / 2,
                    y: position.y - TrackOverviewStyle.carDotSize / 2,
                    width: TrackOverviewStyle.carDotSize,
                    height: TrackOverviewStyle.carDotSize
                )
                
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(marker.color)
                )
                
                // Draw focus driver label
                if marker.isFocus {
                    drawFocusLabel(
                        context: context,
                        driverCode: marker.driverCode,
                        position: position
                    )
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Track overview with \(carMarkers.count) cars")
    }
    
    private func drawFocusLabel(context: GraphicsContext, driverCode: String, position: CGPoint) {
        // Measure text
        let font = Font.system(size: 12, weight: .semibold)
        let textSize = CGSize(width: 30, height: 16) // Approximate size for 3-letter code
        
        // Position label to the right of the dot
        let labelOffset: CGFloat = 12
        let labelRect = CGRect(
            x: position.x + labelOffset,
            y: position.y - textSize.height / 2,
            width: textSize.width + TrackOverviewStyle.focusLabelPadding * 2,
            height: textSize.height + TrackOverviewStyle.focusLabelPadding
        )
        
        // Draw background
        context.fill(
            Path(roundedRect: labelRect, cornerRadius: TrackOverviewStyle.focusLabelRadius),
            with: .color(TrackOverviewStyle.focusDriverBackground)
        )
        
        // Draw text
        let textPosition = CGPoint(
            x: labelRect.midX,
            y: labelRect.midY
        )
        
        context.draw(
            Text(driverCode)
                .font(font)
                .foregroundColor(TrackOverviewStyle.focusDriverText),
            at: textPosition,
            anchor: .center
        )
    }
}

// MARK: - Preview
#Preview {
    let mockGeometry = PolylineTrackGeometry(points: [
        CGPoint(x: 50, y: 100),
        CGPoint(x: 150, y: 80),
        CGPoint(x: 200, y: 120),
        CGPoint(x: 180, y: 180),
        CGPoint(x: 100, y: 200),
        CGPoint(x: 50, y: 150),
        CGPoint(x: 50, y: 100)
    ])
    
    let mockMarkers = [
        CarMarker(driverCode: "HAM", progress: 0.2, color: .cyan, isFocus: true, position: .zero),
        CarMarker(driverCode: "VER", progress: 0.5, color: .blue, isFocus: false, position: .zero),
        CarMarker(driverCode: "LEC", progress: 0.8, color: .red, isFocus: false, position: .zero)
    ]
    
    TrackMapView(
        trackGeometry: mockGeometry,
        carMarkers: mockMarkers,
        canvasSize: CGSize(width: 280, height: 160)
    )
    .background(Color.white)
    .cornerRadius(12)
}
