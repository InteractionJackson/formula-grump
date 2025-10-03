//
//  SVGTrackLoader.swift
//  F1TelemetryTracker
//
//  Utility for loading SVG track outlines into PolylineGeometry-friendly data.
//

import Foundation
import CoreGraphics
import SwiftUI

struct SVGTrackLoader {
    static func loadPoints(fromSVGFileAt url: URL, sampleCount: Int = 300) -> [CGPoint] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            #if DEBUG
            print("⚠️ svg.loader.failure: Unable to load \(url.path)")
            #endif
            return []
        }
        guard let path = SVGPathParser.parsePaths(from: content).first else {
            #if DEBUG
            print("⚠️ svg.loader.noPath: \(url.lastPathComponent)")
            #endif
            return []
        }
        let geometryPath = PolylineGeometry.fromPath(path)
        var points: [CGPoint] = []
        points.reserveCapacity(sampleCount)
        let step = 1.0 / max(sampleCount - 1, 1)
        for index in 0..<sampleCount {
            let t = CGFloat(step * Double(index))
            points.append(geometryPath.point(at: t))
        }
        return TrackGeometryValidator.normalize(points: points)
    }

    /// Convenience loader for the repository's `track outlines` folder on disk.
    /// Useful for previews or development tooling outside the app bundle.
    static func loadPoints(trackNamed name: String, sampleCount: Int = 300) -> [CGPoint] {
        let tracksDirectory = URL(fileURLWithPath: "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/track outlines")
        let fileURL = tracksDirectory.appendingPathComponent("\(name).svg")
        return loadPoints(fromSVGFileAt: fileURL, sampleCount: sampleCount)
    }
}

struct TrackPreview: View {
    let geometry: TrackGeometry
    var body: some View {
        Path(geometry.path)
            .stroke(Color.green, lineWidth: 2)
            .frame(width: 300, height: 300)
    }
}

#if DEBUG
struct TrackPreview_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            let rawPoints = SVGTrackLoader.loadPoints(trackNamed: "Monza")
            if !rawPoints.isEmpty {
                let geometry = PolylineTrackGeometry(points: rawPoints)
                TrackPreview(geometry: geometry)
            } else {
                Text("Missing Monza.svg at repo track outlines path")
            }
        }
    }
}
#endif

