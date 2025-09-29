import CoreGraphics
import Foundation

// MARK: - Track Geometry Protocol
protocol TrackGeometry {
    var path: CGPath { get }
    func point(at progress: CGFloat) -> CGPoint
    var bounds: CGRect { get }
}

// MARK: - Track Geometry Implementation
struct TrackGeometryImpl: TrackGeometry, Equatable {
    private let geometry: PolylineGeometry
    
    var path: CGPath { geometry.createPath() }
    var bounds: CGRect { geometry.bounds }
    
    init(geometry: PolylineGeometry) {
        self.geometry = geometry
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        return geometry.point(at: progress)
    }
    
    static func == (lhs: TrackGeometryImpl, rhs: TrackGeometryImpl) -> Bool {
        return lhs.geometry == rhs.geometry
    }
}

// MARK: - Polyline Track Geometry Implementation
class PolylineTrackGeometry: TrackGeometry {
    let points: [CGPoint]  // Made accessible for track projection
    private let lengthTable: [CGFloat]
    private let totalLength: CGFloat
    private let _path: CGPath
    private let _bounds: CGRect
    
    var path: CGPath { _path }
    var bounds: CGRect { _bounds }
    
    init(points: [CGPoint]) {
        self.points = points
        
        // Build cumulative length table for parameterization
        var lengths: [CGFloat] = [0]
        var totalLen: CGFloat = 0
        
        for i in 1..<points.count {
            let distance = points[i-1].distance(to: points[i])
            totalLen += distance
            lengths.append(totalLen)
        }
        
        self.lengthTable = lengths
        self.totalLength = totalLen
        
        // Create CGPath
        let path = CGMutablePath()
        if !points.isEmpty {
            path.move(to: points[0])
            for i in 1..<points.count {
                path.addLine(to: points[i])
            }
            // Close the path for racing circuits
            if points.count > 2 {
                path.addLine(to: points[0])
            }
        }
        self._path = path
        
        // Calculate bounds
        if points.isEmpty {
            self._bounds = .zero
        } else {
            let xs = points.map { $0.x }
            let ys = points.map { $0.y }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 0
            self._bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }
        
        let clampedProgress = max(0, min(1, progress))
        let targetLength = clampedProgress * totalLength
        
        // Find the segment containing this length
        var segmentIndex = 0
        for i in 1..<lengthTable.count {
            if lengthTable[i] >= targetLength {
                segmentIndex = i - 1
                break
            }
        }
        
        // Handle edge case where we're at the very end
        if segmentIndex >= points.count - 1 {
            return points.last ?? .zero
        }
        
        // Interpolate within the segment
        let segmentStart = lengthTable[segmentIndex]
        let segmentEnd = lengthTable[segmentIndex + 1]
        let segmentLength = segmentEnd - segmentStart
        
        if segmentLength == 0 {
            return points[segmentIndex]
        }
        
        let segmentProgress = (targetLength - segmentStart) / segmentLength
        let startPoint = points[segmentIndex]
        let endPoint = points[segmentIndex + 1]
        
        return CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) * segmentProgress,
            y: startPoint.y + (endPoint.y - startPoint.y) * segmentProgress
        )
    }
}

// MARK: - SVG Track Geometry Implementation
class SVGTrackGeometry: TrackGeometry {
    private let _path: CGPath
    private let _bounds: CGRect
    private let pathPoints: [CGPoint]  // Sampled points for progress calculation
    
    var path: CGPath { _path }
    var bounds: CGRect { _bounds }
    
    init(svgPathData: String, coordinateScale: CGFloat = 1.0, coordinateOffset: CGPoint = .zero) {
        // Parse SVG path data and create CGPath
        let parsedPath = SVGTrackGeometry.parseSVGPath(svgPathData, scale: coordinateScale, offset: coordinateOffset)
        self._path = parsedPath.path
        self._bounds = parsedPath.bounds
        
        // Sample the path to create points for progress calculation
        self.pathPoints = SVGTrackGeometry.samplePath(parsedPath.path, sampleCount: 500)
    }
    
    init(cgPath: CGPath) {
        self._path = cgPath
        self._bounds = cgPath.boundingBox
        self.pathPoints = SVGTrackGeometry.samplePath(cgPath, sampleCount: 500)
    }
    
    func point(at progress: CGFloat) -> CGPoint {
        guard !pathPoints.isEmpty else { return .zero }
        
        let clampedProgress = max(0, min(1, progress))
        let index = Int(clampedProgress * CGFloat(pathPoints.count - 1))
        
        if index >= pathPoints.count - 1 {
            return pathPoints.last ?? .zero
        }
        
        // Interpolate between points for smoother positioning
        let startPoint = pathPoints[index]
        let endPoint = pathPoints[index + 1]
        let segmentProgress = (clampedProgress * CGFloat(pathPoints.count - 1)) - CGFloat(index)
        
        return CGPoint(
            x: startPoint.x + (endPoint.x - startPoint.x) * segmentProgress,
            y: startPoint.y + (endPoint.y - startPoint.y) * segmentProgress
        )
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

