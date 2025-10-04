import XCTest
@testable import F1TelemetryTracker

final class SVGTrackLoaderTests: XCTestCase {

    private let ovalSVG = """
    <svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 400 200'>
      <path d='M 0,100
               C 0,44.77 89.54,0 200,0
               C 310.45,0 400,44.77 400,100
               C 400,155.22 310.45,200 200,200
               C 89.54,200 0,155.22 0,100 Z' />
    </svg>
    """

    func test_inlineSVGSamplingProducesClosedLoop() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("svg")
        try ovalSVG.write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let points = SVGTrackLoader.loadPoints(fromSVGFileAt: tempURL, sampleCount: 600)
        XCTAssertGreaterThan(points.count, 200)

        let first = try XCTUnwrap(points.first)
        let last = try XCTUnwrap(points.last)
        XCTAssertLessThan(hypot(first.x - last.x, first.y - last.y), 1.0)

        let geometry = PolylineTrackGeometry(points: points)
        let bounds = geometry.bounds
        XCTAssertGreaterThan(bounds.width, 0)
        XCTAssertGreaterThan(bounds.height, 0)

        var previous = geometry.point(at: 0)
        for i in 1...200 {
            let t = CGFloat(i) / 200
            let next = geometry.point(at: t)
            XCTAssertLessThan(hypot(previous.x - next.x, previous.y - next.y), 50)
            previous = next
        }
    }
}

