import XCTest
@testable import F1TelemetryTracker

class TrackGeometryTests: XCTestCase {
    
    func testPolylineTrackGeometry() {
        // Create a simple square track
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100),
            CGPoint(x: 0, y: 100),
            CGPoint(x: 0, y: 0)  // Close the loop
        ]
        
        let geometry = PolylineTrackGeometry(points: points)
        
        // Test start point (progress = 0)
        let startPoint = geometry.point(at: 0.0)
        XCTAssertEqual(startPoint.x, 0, accuracy: 0.1)
        XCTAssertEqual(startPoint.y, 0, accuracy: 0.1)
        
        // Test quarter way (progress = 0.25)
        let quarterPoint = geometry.point(at: 0.25)
        XCTAssertEqual(quarterPoint.x, 100, accuracy: 0.1)
        XCTAssertEqual(quarterPoint.y, 0, accuracy: 0.1)
        
        // Test halfway (progress = 0.5)
        let halfwayPoint = geometry.point(at: 0.5)
        XCTAssertEqual(halfwayPoint.x, 100, accuracy: 0.1)
        XCTAssertEqual(halfwayPoint.y, 100, accuracy: 0.1)
        
        // Test three quarters (progress = 0.75)
        let threeQuarterPoint = geometry.point(at: 0.75)
        XCTAssertEqual(threeQuarterPoint.x, 0, accuracy: 0.1)
        XCTAssertEqual(threeQuarterPoint.y, 100, accuracy: 0.1)
        
        // Test end point (progress = 1.0)
        let endPoint = geometry.point(at: 1.0)
        XCTAssertEqual(endPoint.x, 0, accuracy: 0.1)
        XCTAssertEqual(endPoint.y, 0, accuracy: 0.1)
    }
    
    func testTrackGeometryBounds() {
        let points = [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 50, y: 30),
            CGPoint(x: 40, y: 80),
            CGPoint(x: 10, y: 20)
        ]
        
        let geometry = PolylineTrackGeometry(points: points)
        let bounds = geometry.bounds
        
        XCTAssertEqual(bounds.minX, 10)
        XCTAssertEqual(bounds.minY, 20)
        XCTAssertEqual(bounds.width, 40)  // 50 - 10
        XCTAssertEqual(bounds.height, 60)  // 80 - 20
    }
    
    func testEdgeCases() {
        // Empty points
        let emptyGeometry = PolylineTrackGeometry(points: [])
        let emptyPoint = emptyGeometry.point(at: 0.5)
        XCTAssertEqual(emptyPoint, CGPoint.zero)
        
        // Single point
        let singlePoint = CGPoint(x: 42, y: 24)
        let singleGeometry = PolylineTrackGeometry(points: [singlePoint])
        let resultPoint = singleGeometry.point(at: 0.5)
        XCTAssertEqual(resultPoint, singlePoint)
        
        // Progress out of bounds
        let points = [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]
        let geometry = PolylineTrackGeometry(points: points)
        
        let beforeStart = geometry.point(at: -0.5)
        XCTAssertEqual(beforeStart.x, 0, accuracy: 0.1)
        
        let afterEnd = geometry.point(at: 1.5)
        XCTAssertEqual(afterEnd.x, 10, accuracy: 0.1)
    }
    
    func testCGPointDistance() {
        let point1 = CGPoint(x: 0, y: 0)
        let point2 = CGPoint(x: 3, y: 4)
        
        let distance = point1.distance(to: point2)
        XCTAssertEqual(distance, 5.0, accuracy: 0.1) // 3-4-5 triangle
    }
}
