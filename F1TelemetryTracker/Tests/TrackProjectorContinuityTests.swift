import XCTest
import CoreGraphics
@testable import F1TelemetryTracker

final class TrackProjectorContinuityTests: XCTestCase {

    private func ellipsePoints(samples: Int) -> [CGPoint] {
        let center = CGPoint(x: 200, y: 100)
        let rx: CGFloat = 200
        let ry: CGFloat = 100
        var points: [CGPoint] = []
        points.reserveCapacity(samples + 1)
        for i in 0...samples {
            let theta = CGFloat(i) * 2 * .pi / CGFloat(samples)
            points.append(CGPoint(x: center.x + rx * cos(theta), y: center.y + ry * sin(theta)))
        }
        if let first = points.first { points.append(first) }
        return points
    }

    func testProjectionNearTrackIsCloseInProgress() {
        let points = TrackGeometryValidator.normalize(points: ellipsePoints(samples: 360))
        let geometry = PolylineTrackGeometry(points: points)
        let projector = TrackProjector(trackGeometry: geometry)

        for i in stride(from: 0.0, through: 1.0, by: 0.1) {
            let progress = CGFloat(i)
            let onTrack = geometry.point(at: progress)
            let perturbed = CGPoint(x: onTrack.x + 3, y: onTrack.y - 3)
            let projected = projector.projectToProgress(worldX: Float(perturbed.x), worldZ: Float(perturbed.y))
            let delta = min(abs(projected - progress), 1 - abs(projected - progress))
            XCTAssertLessThan(delta, 0.05)
        }
    }

    func testProgressChangesSmoothlyAsCarMoves() {
        let points = TrackGeometryValidator.normalize(points: ellipsePoints(samples: 720))
        let geometry = PolylineTrackGeometry(points: points)
        let projector = TrackProjector(trackGeometry: geometry)

        var previous = projector.projectToProgress(worldX: Float(points[0].x), worldZ: Float(points[0].y))
        for i in 1...200 {
            let t = CGFloat(i) / 200.0
            var point = geometry.point(at: t)
            point.x += .random(in: -0.5...0.5)
            point.y += .random(in: -0.5...0.5)
            let projected = projector.projectToProgress(worldX: Float(point.x), worldZ: Float(point.y))
            let delta = min(abs(projected - previous), 1 - abs(projected - previous))
            XCTAssertLessThan(delta, 0.1)
            previous = projected
        }
    }
}

