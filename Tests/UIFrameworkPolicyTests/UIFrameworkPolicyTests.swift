import XCTest
@testable import UIFrameworkPolicy

final class UIFrameworkPolicyTests: XCTestCase {
    let evaluator = Evaluator()

    func testHeavyListGoesUIKitForBothAuthors() {
        let feed = Fixture.catalogue[2]
        XCTAssertEqual(feed.name, "Home Feed")
        XCTAssertEqual(evaluator.verdict(for: feed, author: .human).framework, .uiKit)
        XCTAssertEqual(evaluator.verdict(for: feed, author: .agent).framework, .uiKit)
    }

    func testSettingsStaysSwiftUIForBothAuthors() {
        let settings = Fixture.catalogue[0]
        XCTAssertEqual(evaluator.verdict(for: settings, author: .human).framework, .swiftUI)
        XCTAssertEqual(evaluator.verdict(for: settings, author: .agent).framework, .swiftUI)
    }

    func testCheckoutFlipsWhenAuthorBecomesAgent() {
        let checkout = Fixture.catalogue[4]
        XCTAssertEqual(checkout.name, "Checkout")
        let human = evaluator.verdict(for: checkout, author: .human)
        let agent = evaluator.verdict(for: checkout, author: .agent)
        XCTAssertEqual(human.framework, .swiftUI)
        XCTAssertEqual(human.swiftUIScore, 5)
        XCTAssertEqual(human.uiKitScore, 2)
        XCTAssertEqual(agent.framework, .uiKit)
        XCTAssertEqual(agent.swiftUIScore, 1.25)
        XCTAssertEqual(agent.uiKitScore, 2)
    }

    func testPaywallSurvivesOnReach() {
        let paywall = Fixture.catalogue[11]
        XCTAssertEqual(paywall.name, "Paywall")
        let agent = evaluator.verdict(for: paywall, author: .agent)
        XCTAssertEqual(agent.framework, .swiftUI)
        XCTAssertEqual(agent.swiftUIScore, 4)   // 3 reach + (2+2)*0.25 ergonomics
        XCTAssertEqual(agent.uiKitScore, 3)     // 2 verifiability * 1.5
        XCTAssertTrue(agent.decisive)
    }

    func testFlipReportPinsTheCatalogueNumbers() {
        let report = FlipReport.compare(catalogue: Fixture.catalogue)
        XCTAssertEqual(report.screenCount, 12)
        XCTAssertEqual(report.flipCount, 5)
        XCTAssertEqual(report.count(.swiftUI, for: .human), 9)
        XCTAssertEqual(report.count(.uiKit, for: .human), 3)
        XCTAssertEqual(report.count(.swiftUI, for: .agent), 4)
        XCTAssertEqual(report.count(.uiKit, for: .agent), 8)
        XCTAssertEqual(Set(report.flips.map(\.screen.name)),
                       ["Product Detail", "Checkout", "Search Results", "Profile", "Legacy Order History"])
        XCTAssertTrue(report.flips.allSatisfy { $0.from == .swiftUI && $0.to == .uiKit })
    }

    func testSweepIsMonotoneAndPinned() {
        let points = FlipReport.sweep(catalogue: Fixture.catalogue, steps: 4)
        XCTAssertEqual(points.map(\.ergonomics), [1.0, 0.75, 0.5, 0.25, 0.0])
        XCTAssertEqual(points.map(\.flips), [0, 1, 3, 5, 5])
        for pair in zip(points, points.dropFirst()) {
            XCTAssertLessThanOrEqual(pair.0.flips, pair.1.flips)
        }
    }

    func testVerifiabilityBoostAloneFlipsNothing() {
        // ergonomics held at 1.0, verifiability at 1.5: the sweep's first point.
        let first = FlipReport.sweep(catalogue: Fixture.catalogue, steps: 1).first
        XCTAssertEqual(first?.ergonomics, 1.0)
        XCTAssertEqual(first?.flips, 0)
        // and the ergonomics discount alone (verifiability back to 1.0) does most of the work
        var profile = AuthorProfile.agent
        profile.verifiability = 1.0
        let ergonomicsOnly = FlipReport.sweep(catalogue: Fixture.catalogue, agentProfile: profile, steps: 4)
        XCTAssertEqual(ergonomicsOnly.map(\.flips), [0, 0, 2, 4, 5])
    }

    func testTieFallsBackToDefault() {
        let policy = FrameworkPolicy(signals: [
            Signal(trait: .formLike, favours: .swiftUI, axis: .ergonomics, weight: 1),
            Signal(trait: .heavyList, favours: .uiKit, axis: .performance, weight: 1),
        ], defaultFramework: .uiKit, tieMargin: 0.5)
        let screen = Screen(name: "Tie", traits: [.formLike, .heavyList])
        let verdict = Evaluator(policy: policy).verdict(for: screen, author: .human)
        XCTAssertFalse(verdict.decisive)
        XCTAssertEqual(verdict.framework, .uiKit)
    }

    func testEmptyTraitsUsesDefault() {
        let verdict = evaluator.verdict(for: Screen(name: "Blank", traits: []), author: .agent)
        XCTAssertEqual(verdict.swiftUIScore, 0)
        XCTAssertEqual(verdict.uiKitScore, 0)
        XCTAssertFalse(verdict.decisive)
        XCTAssertEqual(verdict.framework, .swiftUI)
        XCTAssertTrue(verdict.reasons.isEmpty)
    }

    func testNegativeWeightsAndMarginsAreClamped() {
        let signal = Signal(trait: .formLike, favours: .swiftUI, axis: .ergonomics, weight: -3)
        XCTAssertEqual(signal.weight, 0)
        let policy = FrameworkPolicy(signals: [signal], tieMargin: -1)
        XCTAssertEqual(policy.tieMargin, 0)
    }

    func testReasonsAreSortedByEffectiveWeight() {
        let verdict = evaluator.verdict(for: Fixture.catalogue[9], author: .agent) // Profile
        let weights = verdict.reasons.map(\.effectiveWeight)
        XCTAssertEqual(weights, weights.sorted(by: >))
        XCTAssertEqual(verdict.reasons.first?.trait, .pixelExactLayout)
    }

    func testMissingProfileFallsBackToBuiltIn() {
        let policy = FrameworkPolicy(signals: FrameworkPolicy.standard.signals, profiles: [:])
        XCTAssertEqual(policy.profile(for: .agent), .agent)
        XCTAssertEqual(policy.profile(for: .human), .human)
    }

    func testAgentInstructionsCarryVerdictsAndMultipliers() {
        let text = AgentInstructions.render()
        XCTAssertTrue(text.hasPrefix("## UI framework rule"))
        XCTAssertTrue(text.contains("ergonomics counts ×0.25"))
        XCTAssertTrue(text.contains("verifiability counts ×1.5"))
        XCTAssertTrue(text.contains("- Home Feed: **UIKit**"))
        XCTAssertTrue(text.contains("- Settings: **SwiftUI**"))
        XCTAssertTrue(text.contains("- Checkout: **UIKit** — SwiftUI 1.25 vs UIKit 2"))
        XCTAssertFalse(text.contains("(tie → default)"))
    }

    func testPolicyRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(FrameworkPolicy.standard)
        let decoded = try JSONDecoder().decode(FrameworkPolicy.self, from: data)
        XCTAssertEqual(decoded, .standard)
        let before = FlipReport.compare(catalogue: Fixture.catalogue)
        let after = FlipReport.compare(catalogue: Fixture.catalogue, evaluator: Evaluator(policy: decoded))
        XCTAssertEqual(before.flipCount, after.flipCount)
    }
}
