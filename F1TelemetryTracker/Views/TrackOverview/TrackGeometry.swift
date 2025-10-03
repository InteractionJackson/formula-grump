import CoreGraphics
import Foundation

struct TrackGeometryValidator {
    static func normalize(points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 2 else { return points }
        var normalized = points
        if let first = points.first, let last = points.last, first != last {
            normalized.append(first)
        }
        let xs = normalized.map { $0.x }
        let ys = normalized.map { $0.y }
        guard let minX = xs.min(), let minY = ys.min() else { return normalized }
        let translated = normalized.map { CGPoint(x: $0.x - minX, y: $0.y - minY) }
        let maxY = translated.map { $0.y }.max() ?? 0
        return translated.map { CGPoint(x: $0.x, y: maxY - $0.y) }
    }

    static func assertClosed(points: [CGPoint]) {
        assert(points.count >= 2, "Track geometry must contain at least two points")
        if points.count > 2 {
            assert(points.first == points.last, "Track geometry should be closed (first == last point)")
        }
    }
}

// MARK: - Track Geometry Protocol
protocol TrackGeometry {
    var path: CGPath { get }
    func point(at progress: CGFloat) -> CGPoint
    var bounds: CGRect { get }
    func closestProgress(to point: CGPoint) -> CGFloat
}

// MARK: - Track Geometry Implementation
struct TrackGeometryImpl: TrackGeometry, Equatable {
    private let polyline: PolylineGeometry
    private let cachedPath: CGPath
    
    var path: CGPath { cachedPath }
    var bounds: CGRect { polyline.bounds }
    
    init(geometry: PolylineGeometry) {
        self.polyline = geometry
        TrackGeometryValidator.assertClosed(points: geometry.points)
        self.cachedPath = geometry.createPath()
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        return polyline.point(at: progress)
    }
    
    func closestProgress(to point: CGPoint) -> CGFloat {
        return polyline.progressForClosestPoint(to: point)
    }
    
    static func == (lhs: TrackGeometryImpl, rhs: TrackGeometryImpl) -> Bool {
        return lhs.polyline == rhs.polyline
    }
}

// MARK: - Polyline Track Geometry Implementation
class PolylineTrackGeometry: TrackGeometry {
    let points: [CGPoint]  // Exposed for debugging & previews
    private let polyline: PolylineGeometry
    private let cachedPath: CGPath
    
    var path: CGPath { cachedPath }
    var bounds: CGRect { polyline.bounds }
    
    init(points: [CGPoint]) {
        self.polyline = PolylineGeometry(points: points)
        self.points = polyline.points
        TrackGeometryValidator.assertClosed(points: polyline.points)
        self.cachedPath = polyline.createPath()
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        return polyline.point(at: progress)
    }
    
    func closestProgress(to point: CGPoint) -> CGFloat {
        return polyline.progressForClosestPoint(to: point)
    }
}

// MARK: - SVG Track Geometry Implementation
class SVGTrackGeometry: TrackGeometry {
    private let polyline: PolylineGeometry
    private let cachedPath: CGPath
    
    var path: CGPath { cachedPath }
    var bounds: CGRect { polyline.bounds }
    
    init(svgPathData: String, coordinateScale: CGFloat = 1.0, coordinateOffset: CGPoint = .zero) {
        // Parse SVG data and normalize into a polyline so SwiftUI coordinates behave as expected
        let parsedPath = SVGTrackGeometry.parseSVGPath(svgPathData, scale: coordinateScale, offset: coordinateOffset)
        self.polyline = PolylineGeometry.fromPath(parsedPath.path)
        TrackGeometryValidator.assertClosed(points: polyline.points)
        self.cachedPath = polyline.createPath()
    }
    
    init(cgPath: CGPath) {
        self.polyline = PolylineGeometry.fromPath(cgPath)
        TrackGeometryValidator.assertClosed(points: polyline.points)
        self.cachedPath = polyline.createPath()
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        return polyline.point(at: progress)
    }
    
    func closestProgress(to point: CGPoint) -> CGFloat {
        return polyline.progressForClosestPoint(to: point)
    }
    
    // MARK: - SVG Path Parsing
    
    private static func parseSVGPath(_ pathData: String, scale: CGFloat, offset: CGPoint) -> (path: CGPath, bounds: CGRect) {
        let path = CGMutablePath()
        var currentPoint = CGPoint.zero
        var bounds = CGRect.zero
        var minX: CGFloat = .greatestFiniteMagnitude
        var maxX: CGFloat = -.greatestFiniteMagnitude
        var minY: CGFloat = .greatestFiniteMagnitude
        var maxY: CGFloat = -.greatestFiniteMagnitude
        
        // Simple SVG path parser - handles M, L, C, Z commands
        let commands = pathData.replacingOccurrences(of: ",", with: " ")
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        var i = 0
        while i < commands.count {
            let command = commands[i]
            
            switch command.uppercased() {
            case "M": // Move to
                if i + 2 < commands.count,
                   let x = Double(commands[i + 1]),
                   let y = Double(commands[i + 2]) {
                    currentPoint = CGPoint(x: CGFloat(x) * scale + offset.x, 
                                         y: CGFloat(y) * scale + offset.y)
                    path.move(to: currentPoint)
                    updateBounds(point: currentPoint, minX: &minX, maxX: &maxX, minY: &minY, maxY: &maxY)
                    i += 3
                } else {
                    i += 1
                }
                
            case "L": // Line to
                if i + 2 < commands.count,
                   let x = Double(commands[i + 1]),
                   let y = Double(commands[i + 2]) {
                    currentPoint = CGPoint(x: CGFloat(x) * scale + offset.x, 
                                         y: CGFloat(y) * scale + offset.y)
                    path.addLine(to: currentPoint)
                    updateBounds(point: currentPoint, minX: &minX, maxX: &maxX, minY: &minY, maxY: &maxY)
                    i += 3
                } else {
                    i += 1
                }
                
            case "C": // Cubic Bezier curve
                if i + 6 < commands.count,
                   let x1 = Double(commands[i + 1]), let y1 = Double(commands[i + 2]),
                   let x2 = Double(commands[i + 3]), let y2 = Double(commands[i + 4]),
                   let x = Double(commands[i + 5]), let y = Double(commands[i + 6]) {
                    let cp1 = CGPoint(x: CGFloat(x1) * scale + offset.x, y: CGFloat(y1) * scale + offset.y)
                    let cp2 = CGPoint(x: CGFloat(x2) * scale + offset.x, y: CGFloat(y2) * scale + offset.y)
                    currentPoint = CGPoint(x: CGFloat(x) * scale + offset.x, y: CGFloat(y) * scale + offset.y)
                    path.addCurve(to: currentPoint, control1: cp1, control2: cp2)
                    updateBounds(point: currentPoint, minX: &minX, maxX: &maxX, minY: &minY, maxY: &maxY)
                    i += 7
                } else {
                    i += 1
                }
                
            case "Z": // Close path
                path.closeSubpath()
                i += 1
                
            default:
                i += 1
            }
        }
        
        bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        return (path, bounds)
    }
    
    private static func updateBounds(point: CGPoint, minX: inout CGFloat, maxX: inout CGFloat, minY: inout CGFloat, maxY: inout CGFloat) {
        minX = min(minX, point.x)
        maxX = max(maxX, point.x)
        minY = min(minY, point.y)
        maxY = max(maxY, point.y)
    }
    
    private static func samplePath(_ path: CGPath, sampleCount: Int) -> [CGPoint] {
        var points: [CGPoint] = []
        
        // Use CGPath's built-in enumeration to sample points
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                points.append(element.points[0])
            case .addLineToPoint:
                points.append(element.points[0])
            case .addCurveToPoint:
                // Sample curve points
                let startPoint = points.last ?? .zero
                let cp1 = element.points[0]
                let cp2 = element.points[1]
                let endPoint = element.points[2]
                
                // Sample the curve
                for i in 1...10 {
                    let t = CGFloat(i) / 10.0
                    let point = bezierPoint(t: t, p0: startPoint, p1: cp1, p2: cp2, p3: endPoint)
                    points.append(point)
                }
            case .addQuadCurveToPoint:
                // Sample quadratic curve
                let startPoint = points.last ?? .zero
                let cp = element.points[0]
                let endPoint = element.points[1]
                
                for i in 1...10 {
                    let t = CGFloat(i) / 10.0
                    let point = quadBezierPoint(t: t, p0: startPoint, p1: cp, p2: endPoint)
                    points.append(point)
                }
            case .closeSubpath:
                break
            @unknown default:
                break
            }
        }
        
        return points
    }
    
    private static func bezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        
        let x = uuu * p0.x + 3 * uu * t * p1.x + 3 * u * tt * p2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * p1.y + 3 * u * tt * p2.y + ttt * p3.y
        
        return CGPoint(x: x, y: y)
    }
    
    private static func quadBezierPoint(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let u = 1 - t
        let uu = u * u
        let tt = t * t
        
        let x = uu * p0.x + 2 * u * t * p1.x + tt * p2.x
        let y = uu * p0.y + 2 * u * t * p1.y + tt * p2.y
        
        return CGPoint(x: x, y: y)
    }
}

