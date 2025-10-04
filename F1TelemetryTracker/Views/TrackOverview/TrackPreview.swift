import SwiftUI

struct TrackPreview: View {
    let geometry: TrackGeometry
    var body: some View {
        Path(geometry.path)
            .stroke(Color.green, lineWidth: 2)
            .padding()
            .frame(width: 320, height: 320)
            .background(Color.black.opacity(0.05))
    }
}

#if DEBUG
#Preview("Monza SVG (local file)") {
    let filePath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/track outlines/monza.svg"
    let url = URL(fileURLWithPath: filePath)
    let points = SVGTrackLoader.loadPoints(fromSVGFileAt: url, sampleCount: 600)
    let geometry = PolylineTrackGeometry(points: points)
    return TrackPreview(geometry: geometry)
}
#endif

