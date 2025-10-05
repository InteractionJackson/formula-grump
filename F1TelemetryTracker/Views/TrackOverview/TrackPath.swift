import CoreGraphics
import SwiftUI

struct TrackPath {
    let points: [CGPoint]
    private let spline: CatmullRomSpline

    init(points: [CGPoint]) {
        self.points = points
        self.spline = CatmullRomSpline(points: points)
    }

    func position(at progress: Double) -> CGPoint {
        spline.position(at: progress)
    }

    func scaledPath(in size: CGSize, padding: CGFloat) -> Path {
        let transform = TrackPathTransform(size: size, padding: padding, points: points)
        return Path { path in
            guard let first = points.first else { return }
            let start = transform.convert(first)
            path.move(to: start)

            for point in points.dropFirst() {
                path.addLine(to: transform.convert(point))
            }
            path.closeSubpath()
        }
    }

    func scaledPosition(for progress: Double, in size: CGSize, padding: CGFloat) -> CGPoint {
        let transform = TrackPathTransform(size: size, padding: padding, points: points)
        return transform.convert(position(at: progress))
    }
}

private struct TrackPathTransform {
    let size: CGSize
    let padding: CGFloat
    let scale: CGFloat
    let offset: CGPoint

    init(size: CGSize, padding: CGFloat, points: [CGPoint]) {
        let bounds = TrackPath.bounds(for: points)
        let availableWidth = size.width - padding * 2
        let availableHeight = size.height - padding * 2
        let sx = bounds.width > 0 ? availableWidth / bounds.width : 1
        let sy = bounds.height > 0 ? availableHeight / bounds.height : 1
        self.scale = min(sx, sy)

        let scaledWidth = bounds.width * scale
        let scaledHeight = bounds.height * scale
        let offsetX = (size.width - scaledWidth) / 2 - bounds.minX * scale
        let offsetY = (size.height - scaledHeight) / 2 - bounds.minY * scale
        self.offset = CGPoint(x: offsetX, y: offsetY)
        self.size = size
        self.padding = padding
    }

    func convert(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: point.x * scale + offset.x,
            y: point.y * scale + offset.y
        )
    }
}

private extension TrackPath {
    static func bounds(for points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .zero }
        var minX = first.x
        var maxX = first.x
        var minY = first.y
        var maxY = first.y

        for point in points {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }

        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}

private struct CatmullRomSpline {
    private let samples: [CGPoint]
    private let cumulativeLengths: [CGFloat]
    private let totalLength: CGFloat

    init(points: [CGPoint], subdivisions: Int = 20) {
        var samplePoints: [CGPoint] = []
        samplePoints.reserveCapacity(points.count * subdivisions)

        let wrapped = CatmullRomSpline.wrap(points)
        for i in 0..<(wrapped.count - 3) {
            let p0 = wrapped[i]
            let p1 = wrapped[i + 1]
            let p2 = wrapped[i + 2]
            let p3 = wrapped[i + 3]

            for step in 0..<subdivisions {
                let t = CGFloat(step) / CGFloat(subdivisions)
                samplePoints.append(CatmullRomSpline.interpolate(p0: p0, p1: p1, p2: p2, p3: p3, t: t))
            }
        }

        samplePoints.append(points.last ?? .zero)

        var lengths: [CGFloat] = [0]
        var running: CGFloat = 0
        for index in 1..<samplePoints.count {
            running += samplePoints[index - 1].distance(to: samplePoints[index])
            lengths.append(running)
        }

        self.samples = samplePoints
        self.cumulativeLengths = lengths
        self.totalLength = running
    }

    func position(at progress: Double) -> CGPoint {
        guard !samples.isEmpty else { return .zero }
        guard totalLength > 0 else { return samples.first ?? .zero }

        let clamped = CGFloat(max(0, min(1, progress)))
        let target = clamped * totalLength

        var low = 0
        var high = cumulativeLengths.count - 1
        while low < high {
            let mid = (low + high) / 2
            if cumulativeLengths[mid] < target {
                low = mid + 1
            } else {
                high = mid
            }
        }

        let index = max(0, low - 1)
        let startLength = cumulativeLengths[index]
        let endLength = cumulativeLengths[index + 1]
        let segment = endLength - startLength

        if segment == 0 {
            return samples[index]
        }

        let localT = (target - startLength) / segment
        return samples[index].lerp(to: samples[index + 1], fraction: localT)
    }

    private static func wrap(_ points: [CGPoint]) -> [CGPoint] {
        guard let first = points.first, let second = points.dropFirst().first, let last = points.last else {
            return points
        }
        return [last] + [first] + points + [last, first, second]
    }

    private static func interpolate(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: CGFloat) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t

        let x = 0.5 * ((2 * p1.x) + (-p0.x + p2.x) * t + (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 + (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3)
        let y = 0.5 * ((2 * p1.y) + (-p0.y + p2.y) * t + (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 + (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3)
        return CGPoint(x: x, y: y)
    }
}

private extension CGPoint {
    func lerp(to other: CGPoint, fraction: CGFloat) -> CGPoint {
        CGPoint(
            x: x + (other.x - x) * fraction,
            y: y + (other.y - y) * fraction
        )
    }
}
