import XCTest
import CoreGraphics
@testable import F1TelemetryTracker

final class TrackGeometryContinuityTests: XCTestCase {

    func testPointAtIsContinuousOnRectangle() {
        let rectangle: [CGPoint] = [
            .init(x: 0, y: 0),
            .init(x: 400, y: 0),
            .init(x: 400, y: 200),
            .init(x: 0, y: 200),
            .init(x: 0, y: 0)
        ]
        let normalized = TrackGeometryValidator.normalize(points: rectangle)
        let geometry = PolylineTrackGeometry(points: normalized)

        var prev = geometry.point(at: 0)
        for i in 1...256 {
            let t = CGFloat(i) / 256
            let next = geometry.point(at: t)
            XCTAssertLessThan(hypot(prev.x - next.x, prev.y - next.y), 40)
            prev = next
        }
    }

    func testBoundsReflectNormalizedRectangle() {
        let rectangle: [CGPoint] = [
            .init(x: 0, y: 0),
            .init(x: 400, y: 0),
            .init(x: 400, y: 200),
            .init(x: 0, y: 200),
            .init(x: 0, y: 0)
        ]
        let normalized = TrackGeometryValidator.normalize(points: rectangle)
        let geometry = PolylineTrackGeometry(points: normalized)
        let bounds = geometry.bounds
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)
    }
}

