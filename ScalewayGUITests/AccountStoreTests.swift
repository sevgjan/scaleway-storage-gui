import XCTest
@testable import ScalewayGUI

final class AccountStoreTests: XCTestCase {
    func testRoundTripPersistence() throws {
        let suiteName = "AccountStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AccountStore(defaults: defaults)
        let profile = AccountProfile(
            displayName: "Test",
            accessKeyId: "AKIA123",
            secretKeyRef: "kc-ref",
            endpointURL: "https://s3.nl-ams.scw.cloud",
            signingRegion: "nl-ams"
        )

        try store.upsert(profile)

        let loaded = try store.load()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first, profile)
    }

    func testSecretNotInUserDefaultsPayload() throws {
        let suiteName = "AccountStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AccountStore(defaults: defaults)
        let profile = AccountProfile(
            displayName: "Test",
            accessKeyId: "AKIA123",
            secretKeyRef: "keychain-ref-1",
            endpointURL: "https://s3.fr-par.scw.cloud",
            signingRegion: "fr-par"
        )

        try store.upsert(profile)

        let raw = defaults.data(forKey: "scaleway.accountProfiles.v1")!
        let text = String(decoding: raw, as: UTF8.self)
        XCTAssertFalse(text.contains("SECRET"))
        XCTAssertTrue(text.contains("keychain-ref-1"))
    }
}
