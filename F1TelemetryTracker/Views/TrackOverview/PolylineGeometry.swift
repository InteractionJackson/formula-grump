//
//  PolylineGeometry.swift
//  F1TelemetryTracker
//
//  Robust polyline geometry with arc-length parameterization
//

import Foundation
import CoreGraphics

// MARK: - Polyline Geometry
final class PolylineGeometry: Equatable {
    let points: [CGPoint]
    private let lengthTable: [CGFloat]
    private let totalLength: CGFloat
    private let _bounds: CGRect
    
    var bounds: CGRect { _bounds }
    
    init(points: [CGPoint]) {
        let normalized = TrackGeometryValidator.normalize(points: points)
        self.points = normalized
        
        // Build cumulative arc-length table for monotonic parameterization
        var lengths: [CGFloat] = [0]
        var totalLen: CGFloat = 0
        
        for i in 1..<normalized.count {
            let distance = normalized[i-1].distance(to: normalized[i])
            totalLen += distance
            lengths.append(totalLen)
        }
        
        self.lengthTable = lengths
        self.totalLength = totalLen
        
        // Calculate bounds
        if normalized.isEmpty {
            self._bounds = .zero
        } else {
            let xs = normalized.map { $0.x }
            let ys = normalized.map { $0.y }
            let minX = xs.min() ?? 0
            let maxX = xs.max() ?? 0
            let minY = ys.min() ?? 0
            let maxY = ys.max() ?? 0
            self._bounds = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
        
        #if DEBUG
        print("🏁 track.geometry.loaded: \(points.count) points, length=\(totalLength)")
        #endif
    }
    
    /// Get point at normalized progress (0.0 to 1.0) with monotonic arc-length parameterization
    func point(at progress: CGFloat) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        guard points.count > 1 else { return points[0] }
        
        let clampedProgress = max(0, min(1, progress))
        let targetLength = clampedProgress * totalLength
        
        // Binary search for efficiency with large point counts
        var left = 0
        var right = lengthTable.count - 1
        
        while left < right {
            let mid = (left + right) / 2
            if lengthTable[mid] < targetLength {
                left = mid + 1
            } else {
                right = mid
            }
        }
        
        let segmentIndex = max(0, left - 1)
        
        // Handle edge cases
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
    
    /// Create CGPath representation
    func createPath() -> CGPath {
        let path = CGMutablePath()
        guard !points.isEmpty else { return path }
        
        path.move(to: points[0])
        for i in 1..<points.count {
            path.addLine(to: points[i])
        }
        
        // Close the path for racing circuits
        if points.count > 2 {
            path.addLine(to: points[0])
        }
        
        return path
    }
    
    // MARK: - Equatable
    
    static func == (lhs: PolylineGeometry, rhs: PolylineGeometry) -> Bool {
        return lhs.points == rhs.points
    }
}

// MARK: - Path Flattening
extension PolylineGeometry {
    
    /// Create PolylineGeometry from CGPath with adaptive flattening
    static func fromPath(_ path: CGPath, tolerance: CGFloat = 1.0) -> PolylineGeometry {
        var points: [CGPoint] = []
        
        path.applyWithBlock { elementPtr in
            let element = elementPtr.pointee
            
            switch element.type {
            case .moveToPoint:
                points.append(element.points[0])
                
            case .addLineToPoint:
                points.append(element.points[0])
                
            case .addCurveToPoint:
                // Flatten cubic Bezier curve with adaptive subdivision
                let startPoint = points.last ?? .zero
                let cp1 = element.points[0]
                let cp2 = element.points[1]
                let endPoint = element.points[2]
                
                let flattenedPoints = flattenCubicBezier(
                    start: startPoint, cp1: cp1, cp2: cp2, end: endPoint,
                    tolerance: tolerance
                )
                points.append(contentsOf: flattenedPoints)
                
            case .addQuadCurveToPoint:
                // Flatten quadratic Bezier curve
                let startPoint = points.last ?? .zero
                let cp = element.points[0]
                let endPoint = element.points[1]
                
                let flattenedPoints = flattenQuadraticBezier(
                    start: startPoint, cp: cp, end: endPoint,
                    tolerance: tolerance
                )
                points.append(contentsOf: flattenedPoints)
                
            case .closeSubpath:
                if let firstPoint = points.first, let lastPoint = points.last, firstPoint != lastPoint {
                    points.append(firstPoint)
                }
                
            @unknown default:
                break
            }
        }
        
        return PolylineGeometry(points: points)
    }
    
    // MARK: - Curve Flattening Algorithms
    
    private static func flattenCubicBezier(start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint, 
                                          tolerance: CGFloat, depth: Int = 0) -> [CGPoint] {
        // Adaptive subdivision based on flatness test
        let maxDepth = 8
        
        if depth > maxDepth {
            return [end]
        }
        
        // Flatness test: check if control points are close to the line
        let lineLength = start.distance(to: end)
        if lineLength < tolerance {
            return [end]
        }
        
        let d1 = distanceFromPointToLine(cp1, lineStart: start, lineEnd: end)
        let d2 = distanceFromPointToLine(cp2, lineStart: start, lineEnd: end)
        
        if max(d1, d2) <= tolerance {
            return [end]
        }
        
        // Subdivide the curve at t = 0.5
        let mid = subdivideCubicBezier(start: start, cp1: cp1, cp2: cp2, end: end, t: 0.5)
        
        var result: [CGPoint] = []
        result.append(contentsOf: flattenCubicBezier(
            start: start, cp1: mid.left.cp1, cp2: mid.left.cp2, end: mid.left.end,
            tolerance: tolerance, depth: depth + 1
        ))
        result.append(contentsOf: flattenCubicBezier(
            start: mid.right.start, cp1: mid.right.cp1, cp2: mid.right.cp2, end: end,
            tolerance: tolerance, depth: depth + 1
        ))
        
        return result
    }
    
    private static func flattenQuadraticBezier(start: CGPoint, cp: CGPoint, end: CGPoint, 
                                              tolerance: CGFloat, depth: Int = 0) -> [CGPoint] {
        let maxDepth = 8
        
        if depth > maxDepth {
            return [end]
        }
        
        let lineLength = start.distance(to: end)
        if lineLength < tolerance {
            return [end]
        }
        
        let distance = distanceFromPointToLine(cp, lineStart: start, lineEnd: end)
        if distance <= tolerance {
            return [end]
        }
        
        // Subdivide at t = 0.5
        let mid = subdivideQuadraticBezier(start: start, cp: cp, end: end, t: 0.5)
        
        var result: [CGPoint] = []
        result.append(contentsOf: flattenQuadraticBezier(
            start: start, cp: mid.left.cp, end: mid.left.end,
            tolerance: tolerance, depth: depth + 1
        ))
        result.append(contentsOf: flattenQuadraticBezier(
            start: mid.right.start, cp: mid.right.cp, end: end,
            tolerance: tolerance, depth: depth + 1
        ))
        
        return result
    }
    
    // MARK: - Geometric Utilities
    
    private static func distanceFromPointToLine(_ point: CGPoint, lineStart: CGPoint, lineEnd: CGPoint) -> CGFloat {
        let A = point.x - lineStart.x
        let B = point.y - lineStart.y
        let C = lineEnd.x - lineStart.x
        let D = lineEnd.y - lineStart.y
        
        let dot = A * C + B * D
        let lenSq = C * C + D * D
        
        if lenSq == 0 {
            return point.distance(to: lineStart)
        }
        
        let param = dot / lenSq
        let closestPoint: CGPoint
        
        if param < 0 {
            closestPoint = lineStart
        } else if param > 1 {
            closestPoint = lineEnd
        } else {
            closestPoint = CGPoint(x: lineStart.x + param * C, y: lineStart.y + param * D)
        }
        
        return point.distance(to: closestPoint)
    }
    
    private static func subdivideCubicBezier(start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint, t: CGFloat) -> (left: (start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint), right: (start: CGPoint, cp1: CGPoint, cp2: CGPoint, end: CGPoint)) {
        
        let u = 1 - t
        
        // De Casteljau's algorithm
        let q1 = CGPoint(x: u * start.x + t * cp1.x, y: u * start.y + t * cp1.y)
        let q2 = CGPoint(x: u * cp1.x + t * cp2.x, y: u * cp1.y + t * cp2.y)
        let q3 = CGPoint(x: u * cp2.x + t * end.x, y: u * cp2.y + t * end.y)
        
        let r1 = CGPoint(x: u * q1.x + t * q2.x, y: u * q1.y + t * q2.y)
        let r2 = CGPoint(x: u * q2.x + t * q3.x, y: u * q2.y + t * q3.y)
        
        let s = CGPoint(x: u * r1.x + t * r2.x, y: u * r1.y + t * r2.y)
        
        return (
            left: (start: start, cp1: q1, cp2: r1, end: s),
            right: (start: s, cp1: r2, cp2: q3, end: end)
        )
    }
    
    private static func subdivideQuadraticBezier(start: CGPoint, cp: CGPoint, end: CGPoint, t: CGFloat) -> (left: (start: CGPoint, cp: CGPoint, end: CGPoint), right: (start: CGPoint, cp: CGPoint, end: CGPoint)) {
        
        let u = 1 - t
        
        let q1 = CGPoint(x: u * start.x + t * cp.x, y: u * start.y + t * cp.y)
        let q2 = CGPoint(x: u * cp.x + t * end.x, y: u * cp.y + t * end.y)
        let q3 = CGPoint(x: u * q1.x + t * q2.x, y: u * q1.y + t * q2.y)
        
        return (
            left: (start: start, cp: q1, end: q3),
            right: (start: q3, cp: q2, end: end)
        )
    }
}

// MARK: - CGPoint Extensions
extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}

// MARK: - PolylineGeometry Arc-Length Progress Extension
extension PolylineGeometry {
    /// Find the arc-length-correct progress (0.0-1.0) for the closest point on the polyline
    func progressForClosestPoint(to targetPoint: CGPoint) -> CGFloat {
        guard points.count > 1 else { return 0.0 }
        
        var closestDistance: CGFloat = .greatestFiniteMagnitude
        var closestSegmentIndex = 0
        var closestProgressOnSegment: CGFloat = 0.0
        
        // Find the closest segment and position on that segment
        for i in 0..<(points.count - 1) {
            let lineStart = points[i]
            let lineEnd = points[i + 1]
            
            let (distance, progressOnSegment) = Self.distanceAndProgressToLineSegment(
                point: targetPoint,
                lineStart: lineStart,
                lineEnd: lineEnd
            )
            
            if distance < closestDistance {
                closestDistance = distance
                closestSegmentIndex = i
                closestProgressOnSegment = progressOnSegment
            }
        }
        
        // Convert to arc-length-based progress
        let segmentStartLength = lengthTable[closestSegmentIndex]
        let segmentEndLength = lengthTable[closestSegmentIndex + 1]
        let segmentLength = segmentEndLength - segmentStartLength
        
        let lengthAtPoint = segmentStartLength + (segmentLength * closestProgressOnSegment)
        let progress = totalLength > 0 ? lengthAtPoint / totalLength : 0.0
        
        return max(0.0, min(1.0, progress))
    }
    
    private static func distanceAndProgressToLineSegment(
        point: CGPoint,
        lineStart: CGPoint,
        lineEnd: CGPoint
    ) -> (distance: CGFloat, progressOnSegment: CGFloat) {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let segmentLengthSquared = dx * dx + dy * dy
        
        guard segmentLengthSquared > 1e-10 else {
            // Degenerate segment (start == end)
            let distance = point.distance(to: lineStart)
            return (distance, 0.0)
        }
        
        // Project point onto the line segment
        let t = max(0.0, min(1.0, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / segmentLengthSquared))
        
        // Find the closest point on the segment
        let closestPoint = CGPoint(
            x: lineStart.x + t * dx,
            y: lineStart.y + t * dy
        )
        
        let distance = point.distance(to: closestPoint)
        return (distance, t)
    }
}
