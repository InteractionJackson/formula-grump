import CoreGraphics
import Foundation

// MARK: - Track Projector
class TrackProjector {
    private let trackGeometry: any TrackGeometry
    private let trackBounds: CGRect
    
    init(trackGeometry: any TrackGeometry) {
        self.trackGeometry = trackGeometry
        self.trackBounds = trackGeometry.bounds
    }
    
    /// Converts world coordinates (x, z) to normalized progress (0-1) along the track
    /// If normalized progress is already available, it takes precedence
    func projectToProgress(worldX: Float, worldZ: Float, normalizedProgress: Float? = nil) -> CGFloat {
        // If we already have normalized progress, use it directly
        if let progress = normalizedProgress, progress >= 0 && progress <= 1 {
            return CGFloat(progress)
        }
        
        // Convert world coordinates to track-relative coordinates
        let worldPoint = CGPoint(x: CGFloat(worldX), y: CGFloat(worldZ))
        
        // Find the closest point on the track path
        return findClosestProgressOnTrack(for: worldPoint)
    }
    
    /// Finds the closest point on the track path and returns the progress (0-1)
    private func findClosestProgressOnTrack(for worldPoint: CGPoint) -> CGFloat {
        var closestProgress: CGFloat = 0
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        // Sample the track at regular intervals to find the closest point
        let sampleCount = 200
        for i in 0...sampleCount {
            let progress = CGFloat(i) / CGFloat(sampleCount)
            let trackPoint = trackGeometry.point(at: progress)
            let distance = worldPoint.distance(to: trackPoint)
            
            if distance < minDistance {
                minDistance = distance
                closestProgress = progress
            }
        }
        
        // Refine the result with a finer search around the closest point
        return refineProgress(around: closestProgress, for: worldPoint)
    }
    
    /// Projects a point in geometry space directly to track progress (0-1)
    /// This method assumes the point is already in the same coordinate system as the track geometry
    func projectGeometryPointToProgress(_ geometryPoint: CGPoint) -> CGFloat {
        return findClosestProgressOnTrack(for: geometryPoint)
    }
    
    /// Refines the progress calculation with a finer search
    private func refineProgress(around initialProgress: CGFloat, for worldPoint: CGPoint) -> CGFloat {
        let searchRange: CGFloat = 0.01 // 1% of track length
        let refinementSamples = 20
        
        var bestProgress = initialProgress
        var minDistance: CGFloat = .greatestFiniteMagnitude
        
        let startProgress = max(0, initialProgress - searchRange)
        let endProgress = min(1, initialProgress + searchRange)
        
        for i in 0...refinementSamples {
            let progress = startProgress + (endProgress - startProgress) * CGFloat(i) / CGFloat(refinementSamples)
            let trackPoint = trackGeometry.point(at: progress)
            let distance = worldPoint.distance(to: trackPoint)
            
            if distance < minDistance {
                minDistance = distance
                bestProgress = progress
            }
        }
        
        return bestProgress
    }
}

// MARK: - Car Position Data
struct CarPositionData {
    let driverCode: String
    let worldX: Float
    let worldZ: Float
    let normalizedProgress: Float?
    let teamId: Int
    let isFocus: Bool
    let driverStatus: UInt8
    
    init(driverCode: String, worldX: Float, worldZ: Float, normalizedProgress: Float? = nil, teamId: Int, isFocus: Bool, driverStatus: UInt8 = 4) {
        self.driverCode = driverCode
        self.worldX = worldX
        self.worldZ = worldZ
        self.normalizedProgress = normalizedProgress
        self.teamId = teamId
        self.isFocus = isFocus
        self.driverStatus = driverStatus
    }
}

// MARK: - Car Marker for UI
struct CarMarker {
    let driverCode: String
    let progress: CGFloat
    let color: Color
    let isFocus: Bool
    let position: CGPoint
    let driverStatus: UInt8
    
    init(driverCode: String, progress: CGFloat, color: Color, isFocus: Bool, position: CGPoint, driverStatus: UInt8 = 4) {
        self.driverCode = driverCode
        self.progress = progress
        self.color = color
        self.isFocus = isFocus
        self.position = position
        self.driverStatus = driverStatus
    }
}

import SwiftUI
