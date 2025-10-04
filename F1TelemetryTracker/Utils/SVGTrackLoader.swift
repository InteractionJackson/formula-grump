import Foundation
import CoreGraphics

struct SVGTrackLoader {

    static func loadPoints(fromSVGFileAt url: URL, sampleCount: Int = 400) -> [CGPoint] {
        let svgData: Data
        do {
            svgData = try Data(contentsOf: url)
        } catch {
            #if DEBUG
            print("❌ Failed to read SVG at \(url.path): \(error)")
            #endif
            return []
        }

        guard let svgString = String(data: svgData, encoding: .utf8) ??
                String(data: svgData, encoding: .isoLatin1) else {
            #if DEBUG
            print("❌ Unsupported encoding for SVG \(url.lastPathComponent)")
            #endif
            return []
        }

        guard let pathString = firstPathD(in: svgString) else {
            #if DEBUG
            print("❌ No <path d="..."> found in \(url.lastPathComponent)")
            #endif
            return []
        }

        guard let cgPath = SVGPathParser.parsePath(from: pathString) else {
            #if DEBUG
            print("❌ SVGPathParser failed for \(url.lastPathComponent)")
            #endif
            return []
        }

        let polyline = PolylineGeometry.fromPath(cgPath)
        let samples = max(sampleCount, 32)
        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        let step = 1.0 / CGFloat(samples)
        for i in 0...samples {
            let t = CGFloat(i) * step
            points.append(polyline.point(at: t))
        }

        var normalized = TrackGeometryValidator.normalize(points: points)
        if let first = normalized.first, let last = normalized.last {
            if hypot(first.x - last.x, first.y - last.y) > 0.5 {
                normalized.append(first)
            }
        }
        return normalized
    }

    static func repositoryTrackURL(named name: String) -> URL {
        let basePath = "/Users/mattjackson/Documents/GitHub/formula-grump/F1TelemetryTracker/track outlines"
        return URL(fileURLWithPath: basePath).appendingPathComponent("\(name).svg")
    }

    private static func firstPathD(in svg: String) -> String? {
        if let range = svg.range(of: "<path"),
           let dRange = svg[range.lowerBound...].range(of: " d=\"") {
            let start = dRange.upperBound
            if let end = svg[start...].firstIndex(of: "\"") {
                return String(svg[start..<end])
            }
        }
        if let range = svg.range(of: "<path"),
           let dRange = svg[range.lowerBound...].range(of: " d='") {
            let start = dRange.upperBound
            if let end = svg[start...].firstIndex(of: "'") {
                return String(svg[start..<end])
            }
        }
        return nil
    }
}

