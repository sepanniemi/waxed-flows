import XCTest
import MapKit
@testable import PolarMyFlow

final class MMLTileOverlayTests: XCTestCase {
    func testURLTemplate_containsWMTSPathOrder() {
        // WMTS order is {z}/{y}/{x}, NOT {z}/{x}/{y}
        let template = MMLTileOverlay.urlTemplate(apiKey: "test-key")
        let zIdx = template.range(of: "{z}")!.lowerBound
        let yIdx = template.range(of: "{y}")!.lowerBound
        let xIdx = template.range(of: "{x}")!.lowerBound
        XCTAssertLessThan(zIdx, yIdx, "{z} must come before {y}")
        XCTAssertLessThan(yIdx, xIdx, "{y} must come before {x}")
    }

    func testURLTemplate_containsApiKey() {
        let template = MMLTileOverlay.urlTemplate(apiKey: "my-key-123")
        XCTAssertTrue(template.contains("api-key=my-key-123"))
    }

    func testURLTemplate_containsMaastokarttaLayer() {
        let template = MMLTileOverlay.urlTemplate(apiKey: "k")
        XCTAssertTrue(template.contains("maastokartta"))
    }

    func testOverlay_maximumZIs15() {
        let overlay = MMLTileOverlay.make(apiKey: "k")
        XCTAssertEqual(overlay.maximumZ, 15)
    }

    func testOverlay_canReplaceMapContent() {
        let overlay = MMLTileOverlay.make(apiKey: "k")
        XCTAssertTrue(overlay.canReplaceMapContent)
    }
}
