import XCTest
@testable import F1TelemetryTracker

class TrackOverviewTests: XCTestCase {
    
    func testTrackGeometryCaching() {
        // Given: Empty cache
        let cache = TrackGeometryCache.shared
        cache.clearCache()
        
        // When: Loading same track multiple times
        let profile1 = cache.geometry(for: .bahrain)
        let profile2 = cache.geometry(for: .bahrain)
        
        // Then: Should return same instance (cached)
        XCTAssertEqual(profile1.id, profile2.id, "Should return same track profile")
        XCTAssertEqual(profile1.displayName, profile2.displayName, "Display names should match")
    }
    
    func testTrackIdMapping() {
        // Test known track IDs
        XCTAssertEqual(TrackId(rawValue: 3), .bahrain, "Raw ID 3 should map to Bahrain")
        XCTAssertEqual(TrackId(rawValue: 5), .monaco, "Raw ID 5 should map to Monaco")
        XCTAssertEqual(TrackId(rawValue: 8), .britain, "Raw ID 8 should map to Britain")
        
        // Test unknown track ID
        XCTAssertEqual(TrackId(rawValue: 99), nil, "Unknown raw ID should return nil")
        
        // Test fallback behavior
        let unknownId = TrackId(rawValue: 99) ?? .unknown
        XCTAssertEqual(unknownId, .unknown, "Should fallback to .unknown for unmapped IDs")
    }
    
    func testTrackGeometryBounds() {
        // Given: A track geometry
        let points = [
            CGPoint(x: 50, y: 100),
            CGPoint(x: 150, y: 80),
            CGPoint(x: 200, y: 120)
        ]
        let geometry = PolylineTrackGeometry(points: points)
        
        // When: Getting bounds
        let bounds = geometry.bounds
        
        // Then: Should calculate correct bounds
        XCTAssertEqual(bounds.minX, 50, "Min X should be 50")
        XCTAssertEqual(bounds.maxX, 200, "Max X should be 200")
        XCTAssertEqual(bounds.minY, 80, "Min Y should be 80")
        XCTAssertEqual(bounds.maxY, 120, "Max Y should be 120")
        XCTAssertEqual(bounds.width, 150, "Width should be 150")
        XCTAssertEqual(bounds.height, 40, "Height should be 40")
    }
    
    func testTrackGeometryProgressCalculation() {
        // Given: A simple track geometry
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0),
            CGPoint(x: 100, y: 100)
        ]
        let geometry = PolylineTrackGeometry(points: points)
        
        // When: Getting points at different progress values
        let startPoint = geometry.point(at: 0.0)
        let midPoint = geometry.point(at: 0.5)
        let endPoint = geometry.point(at: 1.0)
        
        // Then: Should return correct interpolated points
        XCTAssertEqual(startPoint, CGPoint(x: 0, y: 0), "Start point should be first point")
        XCTAssertEqual(endPoint, CGPoint(x: 100, y: 100), "End point should be last point")
        
        // Mid point should be somewhere along the path
        XCTAssertGreaterThanOrEqual(midPoint.x, 0, "Mid point X should be >= 0")
        XCTAssertLessThanOrEqual(midPoint.x, 100, "Mid point X should be <= 100")
    }
    
    func testTrackGeometryEdgeCases() {
        // Test empty geometry
        let emptyGeometry = PolylineTrackGeometry(points: [])
        XCTAssertEqual(emptyGeometry.point(at: 0.5), .zero, "Empty geometry should return zero point")
        XCTAssertEqual(emptyGeometry.bounds, .zero, "Empty geometry should have zero bounds")
        
        // Test single point geometry
        let singlePointGeometry = PolylineTrackGeometry(points: [CGPoint(x: 50, y: 50)])
        XCTAssertEqual(singlePointGeometry.point(at: 0.5), CGPoint(x: 50, y: 50), "Single point geometry should return that point")
        
        // Test progress clamping
        let normalGeometry = PolylineTrackGeometry(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 0)
        ])
        
        // Progress values outside [0,1] should be clamped
        let beforeStart = normalGeometry.point(at: -0.5)
        let afterEnd = normalGeometry.point(at: 1.5)
        
        XCTAssertEqual(beforeStart, CGPoint(x: 0, y: 0), "Negative progress should clamp to start")
        XCTAssertEqual(afterEnd, CGPoint(x: 100, y: 0), "Progress > 1 should clamp to end")
    }
    
    func testTrackLibraryContainsKnownTracks() {
        // Test that common tracks are available
        let bahrainProfile = TrackLibrary.loadTrackProfile(for: .bahrain)
        XCTAssertEqual(bahrainProfile.id, .bahrain, "Should load Bahrain profile")
        XCTAssertEqual(bahrainProfile.displayName, "Bahrain", "Should have correct display name")
        
        let monacoProfile = TrackLibrary.loadTrackProfile(for: .monaco)
        XCTAssertEqual(monacoProfile.id, .monaco, "Should load Monaco profile")
        
        let unknownProfile = TrackLibrary.loadTrackProfile(for: .unknown)
        XCTAssertEqual(unknownProfile.id, .unknown, "Should load unknown/fallback profile")
    }
    
    func testCarMarkerCreation() {
        // Test CarMarker initialization
        let marker = CarMarker(
            driverCode: "HAM",
            progress: 0.5,
            color: .red,
            isFocus: true,
            position: CGPoint(x: 100, y: 100),
            driverStatus: 4
        )
        
        XCTAssertEqual(marker.driverCode, "HAM", "Driver code should be set correctly")
        XCTAssertEqual(marker.progress, 0.5, "Progress should be set correctly")
        XCTAssertEqual(marker.isFocus, true, "Focus flag should be set correctly")
        XCTAssertEqual(marker.driverStatus, 4, "Driver status should be set correctly")
    }
}
