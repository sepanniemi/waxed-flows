import XCTest
import SwiftUI
@testable import PolarMyFlow

final class TypographyTests: XCTestCase {
    func test_antonFontIsRegistered() {
        let font = UIFont(name: "Anton-Regular", size: 42)
        XCTAssertNotNil(font, "Anton-Regular should be bundled and registered via UIAppFonts")
    }

    func test_typographyFactoryProducesAllRoles() {
        // Compile-time check — if these identifiers exist, the API is in place.
        _ = Font.displayJumbo
        _ = Font.displayLarge
        _ = Font.displayMedium
        _ = Font.displaySmall
        _ = Font.displayTab
        _ = Font.metaDefault
        _ = Font.metaSmall
        _ = Font.bodyDefault
        _ = Font.bodyCaption
    }
}
