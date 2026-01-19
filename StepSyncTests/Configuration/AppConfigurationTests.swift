import XCTest
@testable import StepSync

final class AppConfigurationTests: XCTestCase {

    // MARK: - Orientation Tests

    func testAppSupportsOnlyPortraitOrientation() throws {
        // Load the iOS Info.plist from the project
        let plistPath = Bundle.main.path(forResource: "Info", ofType: "plist")

        // When running tests, we may need to check the compiled app's Info.plist
        // The orientation settings should only include portrait
        guard let infoPlistPath = plistPath,
              let plistData = FileManager.default.contents(atPath: infoPlistPath),
              let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            // If we can't load the plist directly, check via UIApplication
            let supportedOrientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations"] as? [String] ?? []

            // Verify only portrait orientation is supported
            XCTAssertTrue(supportedOrientations.contains("UIInterfaceOrientationPortrait"),
                          "App should support portrait orientation")
            XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeLeft"),
                           "App should not support landscape left orientation")
            XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeRight"),
                           "App should not support landscape right orientation")
            XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationPortraitUpsideDown"),
                           "App should not support portrait upside down orientation")
            return
        }

        let supportedOrientations = plist["UISupportedInterfaceOrientations"] as? [String] ?? []

        XCTAssertTrue(supportedOrientations.contains("UIInterfaceOrientationPortrait"),
                      "App should support portrait orientation")
        XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeLeft"),
                       "App should not support landscape left orientation")
        XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeRight"),
                       "App should not support landscape right orientation")
    }

    func testAppSupportsOnlyPortraitOrientationForIPad() throws {
        let supportedOrientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations~ipad"] as? [String] ?? []

        // If iPad-specific orientations exist, verify only portrait is supported
        if !supportedOrientations.isEmpty {
            XCTAssertTrue(supportedOrientations.contains("UIInterfaceOrientationPortrait"),
                          "App should support portrait orientation on iPad")
            XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeLeft"),
                           "App should not support landscape left orientation on iPad")
            XCTAssertFalse(supportedOrientations.contains("UIInterfaceOrientationLandscapeRight"),
                           "App should not support landscape right orientation on iPad")
        }
    }

    func testOrientationCountIsOne() throws {
        let supportedOrientations = Bundle.main.infoDictionary?["UISupportedInterfaceOrientations"] as? [String] ?? []

        // Should only have one orientation (portrait)
        XCTAssertEqual(supportedOrientations.count, 1,
                       "App should support exactly one orientation (portrait only)")
    }
}
