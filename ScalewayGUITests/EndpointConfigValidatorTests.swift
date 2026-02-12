import XCTest
@testable import ScalewayGUI

final class EndpointConfigValidatorTests: XCTestCase {
    func testValidEndpointURL() {
        XCTAssertTrue(EndpointConfigValidator.isValidEndpointURL("https://s3.nl-ams.scw.cloud"))
    }

    func testInvalidEndpointURL() {
        XCTAssertFalse(EndpointConfigValidator.isValidEndpointURL("not-a-url"))
    }

    func testValidRegion() {
        XCTAssertTrue(EndpointConfigValidator.isValidRegion("nl-ams"))
        XCTAssertTrue(EndpointConfigValidator.isValidRegion("fr-par"))
    }

    func testInvalidRegion() {
        XCTAssertFalse(EndpointConfigValidator.isValidRegion(""))
        XCTAssertFalse(EndpointConfigValidator.isValidRegion("NL_AMS"))
    }
}
