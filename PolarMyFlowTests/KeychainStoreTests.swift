import XCTest
@testable import PolarMyFlow

final class KeychainStoreTests: XCTestCase {
    var store: KeychainStore!

    override func setUp() {
        store = KeychainStore()
        try? store.delete() // clean slate
    }

    override func tearDown() {
        try? store.delete()
    }

    func test_saveAndLoad_roundtrip() throws {
        let token = AuthToken(accessToken: "access", refreshToken: "refresh", expiresIn: 3600)
        try store.save(token)
        let loaded = try store.load()
        XCTAssertEqual(loaded?.accessToken, "access")
        XCTAssertEqual(loaded?.refreshToken, "refresh")
    }

    func test_load_returnsNilWhenEmpty() throws {
        let result = try store.load()
        XCTAssertNil(result)
    }

    func test_delete_removesToken() throws {
        let token = AuthToken(accessToken: "x", refreshToken: "y", expiresIn: 100)
        try store.save(token)
        try store.delete()
        let result = try store.load()
        XCTAssertNil(result)
    }

    func test_isExpired_falseForFutureToken() {
        let token = AuthToken(accessToken: "a", refreshToken: "b", expiresIn: 3600)
        XCTAssertFalse(token.isExpired)
    }

    func test_isExpired_trueForPastToken() {
        let token = AuthToken(accessToken: "a", refreshToken: "b", expiresIn: -1)
        XCTAssertTrue(token.isExpired)
    }
}
