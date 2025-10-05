import Foundation
import CoreGraphics

struct SVGTrackLoader {
    static func loadTrackPath(fromSVGFileAt url: URL, sampleCount: Int = 500) -> TrackPath? {
        guard let svgData = try? Data(contentsOf: url) else {
            #if DEBUG
            print("❌ Failed to read SVG at \(url.path)")
            #endif
            return nil
        }

        guard let svgString = String(data: svgData, encoding: .utf8) ??
                String(data: svgData, encoding: .isoLatin1) else {
            #if DEBUG
            print("❌ Unsupported encoding for SVG \(url.lastPathComponent)")
            #endif
            return nil
        }

        guard let pathString = firstPathD(in: svgString) else {
            #if DEBUG
            print("❌ No <path d=...> found in \(url.lastPathComponent)")
            #endif
            return nil
        }

        guard let cgPath = SVGPathParser.parsePath(from: pathString) else {
            #if DEBUG
            print("❌ SVGPathParser failed for \(url.lastPathComponent)")
            #endif
            return nil
        }

        let polyline = PolylineGeometry.fromPath(cgPath)
        let resampled = resample(polyline, samples: sampleCount)
        let normalized = TrackGeometryValidator.normalize(points: resampled)

        guard !normalized.isEmpty else { return nil }

        return TrackPath(points: normalized)
    }

    static func repositoryTrackURL(named name: String) -> URL {
        let basePath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/track outlines"
        return URL(fileURLWithPath: basePath).appendingPathComponent("\(name).svg")
    }

    private static func firstPathD(in svg: String) -> String? {
        if let pathRange = svg.range(of: "<path"),
           let dRange = svg[pathRange.lowerBound...].range(of: " d=\"") {
            let start = dRange.upperBound
            if let end = svg[start...].firstIndex(of: "\"") {
                return String(svg[start..<end])
            }
        }
        if let pathRange = svg.range(of: "<path"),
           let dRange = svg[pathRange.lowerBound...].range(of: " d='") {
            let start = dRange.upperBound
            if let end = svg[start...].firstIndex(of: "'") {
                return String(svg[start..<end])
            }
        }
        return nil
    }

    private static func resample(_ geometry: PolylineGeometry, samples: Int) -> [CGPoint] {
        let count = max(samples, 32)
        var points: [CGPoint] = []
        points.reserveCapacity(count)

        let step = 1.0 / CGFloat(count - 1)
        for i in 0..<count {
            let t = CGFloat(i) * step
            points.append(geometry.point(at: t))
        }

        return points
    }
}

