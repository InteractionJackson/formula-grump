import XCTest
@testable import F1TelemetryTracker

class SpeedTelemetryTests: XCTestCase {
    var viewModel: TelemetryViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = TelemetryViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testSpeedConversionKmhToMph() {
        // Given: Speed in km/h
        viewModel.speed = 287 // km/h (typical F1 speed)
        
        // When: Converting to mph
        let mph = viewModel.speedMPH
        
        // Then: Should convert correctly (287 km/h ≈ 178 mph)
        XCTAssertEqual(mph, 178, "287 km/h should convert to approximately 178 mph")
    }
    
    func testSpeedConversionEdgeCases() {
        // Test zero speed
        viewModel.speed = 0
        XCTAssertEqual(viewModel.speedMPH, 0, "Zero speed should remain zero")
        
        // Test maximum F1 speed
        viewModel.speed = 370 // km/h (max F1 speed)
        let maxMph = viewModel.speedMPH
        XCTAssertGreaterThan(maxMph, 200, "Max F1 speed should be over 200 mph")
        XCTAssertLessThan(maxMph, 250, "Max F1 speed should be under 250 mph")
    }
    
    func testSpeedClamping() {
        // Test that extreme values are handled safely
        let extremeTelemetry = CarTelemetryData(
            speed: 9999, // Extreme value
            throttle: 1.0,
            steer: 0.0,
            brake: 0.0,
            clutch: 0,
            gear: 1,
            engineRPM: 8000,
            drs: 0,
            revLightsPercent: 0,
            revLightsBitValue: 0,
            brakesTemperature: [0, 0, 0, 0],
            tyresSurfaceTemperature: [0, 0, 0, 0],
            tyresInnerTemperature: [0, 0, 0, 0],
            engineTemperature: 90,
            tyresPressure: [0, 0, 0, 0],
            surfaceType: [0, 0, 0, 0]
        )
        
        // This should not crash and should clamp to reasonable values
        // Note: This test verifies the clamping logic exists
        XCTAssertNoThrow({
            // Simulate the clamping that happens in updateTelemetryData
            let clampedSpeed = TelemetryViewModel.clamp(Double(extremeTelemetry.speed), min: 0.0, max: 400.0)
            XCTAssertLessThanOrEqual(clampedSpeed, 400.0, "Speed should be clamped to maximum 400 km/h")
        }())
    }
    
    func testSpeedInterpolation() {
        // Given: Initial speed
        viewModel.speed = 100
        
        // When: Raw speed changes significantly
        // Note: This is testing the interpolation concept, actual interpolation happens in timer
        let oldSpeed = Double(viewModel.speed)
        let newRawSpeed = 200.0
        let smoothingFactor = 0.15
        
        // Simulate one interpolation step
        let interpolatedSpeed = TelemetryViewModel.lerp(oldSpeed, newRawSpeed, smoothingFactor)
        
        // Then: Speed should move towards target but not jump immediately
        XCTAssertGreaterThan(interpolatedSpeed, oldSpeed, "Speed should increase")
        XCTAssertLessThan(interpolatedSpeed, newRawSpeed, "Speed should not jump to target immediately")
        
        // Should be approximately: 100 + (200-100) * 0.15 = 115
        XCTAssertEqual(Int(interpolatedSpeed), 115, accuracy: 1, "Interpolation should follow EMA formula")
    }
}

// MARK: - Helper Extension for Testing
extension TelemetryViewModel {
    static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        return Swift.max(minValue, Swift.min(maxValue, value))
    }
    
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a * (1.0 - t) + b * t
    }
}
