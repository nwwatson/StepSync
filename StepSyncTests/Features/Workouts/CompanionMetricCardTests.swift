import XCTest
import SwiftUI
@testable import StepSync

final class CompanionMetricCardTests: XCTestCase {

    // MARK: - Metric Value Formatting Tests

    func testDistanceMetricDisplaysCorrectFormat() {
        let card = CompanionMetricCard(
            title: "Distance",
            value: "1.24",
            unit: "mi",
            systemImage: "map"
        )

        XCTAssertEqual(card.title, "Distance")
        XCTAssertEqual(card.value, "1.24")
        XCTAssertEqual(card.unit, "mi")
        XCTAssertEqual(card.systemImage, "map")
    }

    func testHeartRateMetricDisplaysCorrectFormat() {
        let card = CompanionMetricCard(
            title: "Heart Rate",
            value: "142",
            unit: "bpm",
            systemImage: "heart.fill",
            color: .red
        )

        XCTAssertEqual(card.title, "Heart Rate")
        XCTAssertEqual(card.value, "142")
        XCTAssertEqual(card.unit, "bpm")
        XCTAssertEqual(card.color, .red)
    }

    func testCaloriesMetricDisplaysCorrectFormat() {
        let card = CompanionMetricCard(
            title: "Calories",
            value: "156",
            unit: "cal",
            systemImage: "flame.fill",
            color: .orange
        )

        XCTAssertEqual(card.title, "Calories")
        XCTAssertEqual(card.value, "156")
        XCTAssertEqual(card.unit, "cal")
        XCTAssertEqual(card.color, .orange)
    }

    // MARK: - Default Color Tests

    func testDefaultColorIsPrimary() {
        let card = CompanionMetricCard(
            title: "Distance",
            value: "1.00",
            unit: "mi",
            systemImage: "map"
        )

        XCTAssertEqual(card.color, .primary)
    }

    // MARK: - Placeholder Value Tests

    func testPlaceholderValueDisplaysCorrectly() {
        let card = CompanionMetricCard(
            title: "Heart Rate",
            value: "--",
            unit: "bpm",
            systemImage: "heart.fill",
            color: .red
        )

        XCTAssertEqual(card.value, "--")
    }

    func testZeroValueDisplaysCorrectly() {
        let card = CompanionMetricCard(
            title: "Calories",
            value: "0",
            unit: "cal",
            systemImage: "flame.fill",
            color: .orange
        )

        XCTAssertEqual(card.value, "0")
    }
}
