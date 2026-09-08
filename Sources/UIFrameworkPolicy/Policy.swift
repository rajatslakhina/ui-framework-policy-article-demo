import Foundation

/// One trait's argument: which framework it favours, how strongly, and along which axis.
public struct Signal: Codable, Sendable, Hashable {
    public let trait: Trait
    public let favours: Framework
    public let axis: Axis
    public let weight: Double

    public init(trait: Trait, favours: Framework, axis: Axis, weight: Double) {
        self.trait = trait
        self.favours = favours
        self.axis = axis
        self.weight = max(0, weight)
    }
}

/// How much each axis counts for a given author. These are *policy
/// parameters a lead sets*, not measurements. The defaults encode the
/// article's claim: an agent author discounts ergonomics to a quarter and
/// raises verifiability by half, because the human's job moves from
/// writing to reviewing.
public struct AuthorProfile: Codable, Sendable, Hashable {
    public var ergonomics: Double
    public var verifiability: Double
    public var control: Double
    public var performance: Double
    public var reach: Double

    public init(ergonomics: Double = 1, verifiability: Double = 1, control: Double = 1,
                performance: Double = 1, reach: Double = 1) {
        self.ergonomics = ergonomics
        self.verifiability = verifiability
        self.control = control
        self.performance = performance
        self.reach = reach
    }

    public static let human = AuthorProfile()
    public static let agent = AuthorProfile(ergonomics: 0.25, verifiability: 1.5)

    public func multiplier(for axis: Axis) -> Double {
        switch axis {
        case .ergonomics: return ergonomics
        case .verifiability: return verifiability
        case .control: return control
        case .performance: return performance
        case .reach: return reach
        }
    }
}

/// The lead's rule set. Deterministic, serialisable, reviewable in a PR.
public struct FrameworkPolicy: Codable, Sendable, Hashable {
    public var signals: [Signal]
    public var profiles: [Author: AuthorProfile]
    /// Framework chosen when the scores are within `tieMargin` of each other.
    public var defaultFramework: Framework
    public var tieMargin: Double

    public init(signals: [Signal],
                profiles: [Author: AuthorProfile] = [.human: .human, .agent: .agent],
                defaultFramework: Framework = .swiftUI,
                tieMargin: Double = 0.5) {
        self.signals = signals
        self.profiles = profiles
        self.defaultFramework = defaultFramework
        self.tieMargin = max(0, tieMargin)
    }

    /// The policy the article argues for. Weights are deliberately coarse
    /// (1, 2, 3) so the model is arguable in a code review, not tuned.
    public static let standard = FrameworkPolicy(signals: [
        Signal(trait: .heavyList,                favours: .uiKit,   axis: .performance,   weight: 3),
        Signal(trait: .pixelExactLayout,         favours: .uiKit,   axis: .verifiability, weight: 2),
        Signal(trait: .customGestures,           favours: .uiKit,   axis: .control,       weight: 2),
        Signal(trait: .richTextEditing,          favours: .uiKit,   axis: .control,       weight: 3),
        Signal(trait: .presentationStateNeeded,  favours: .uiKit,   axis: .control,       weight: 2),
        Signal(trait: .profilingCritical,        favours: .uiKit,   axis: .verifiability, weight: 2),
        Signal(trait: .legacyUIKitHost,          favours: .uiKit,   axis: .control,       weight: 1),
        Signal(trait: .backDeployBelow17,        favours: .uiKit,   axis: .verifiability, weight: 2),
        Signal(trait: .formLike,                 favours: .swiftUI, axis: .ergonomics,    weight: 3),
        Signal(trait: .stateDriven,              favours: .swiftUI, axis: .ergonomics,    weight: 2),
        Signal(trait: .crossPlatform,            favours: .swiftUI, axis: .reach,         weight: 3),
        Signal(trait: .rapidIteration,           favours: .swiftUI, axis: .ergonomics,    weight: 2),
        Signal(trait: .appleSkillCoverage,       favours: .swiftUI, axis: .reach,         weight: 1),
    ])

    public func profile(for author: Author) -> AuthorProfile {
        profiles[author] ?? (author == .agent ? .agent : .human)
    }
}

/// One line of the verdict's reasoning: a trait, the framework it pushed
/// toward, and its *effective* weight after the author multiplier.
public struct Reason: Codable, Sendable, Hashable {
    public let trait: Trait
    public let favours: Framework
    public let axis: Axis
    public let effectiveWeight: Double
}

public struct Verdict: Codable, Sendable, Hashable {
    public let screen: Screen
    public let author: Author
    public let framework: Framework
    public let swiftUIScore: Double
    public let uiKitScore: Double
    public let reasons: [Reason]
    /// False when the policy default broke a tie.
    public let decisive: Bool

    public var margin: Double { abs(swiftUIScore - uiKitScore) }
}

public struct Evaluator: Sendable {
    public let policy: FrameworkPolicy

    public init(policy: FrameworkPolicy = .standard) {
        self.policy = policy
    }

    public func verdict(for screen: Screen, author: Author) -> Verdict {
        let profile = policy.profile(for: author)
        var swiftUI = 0.0
        var uiKit = 0.0
        var reasons: [Reason] = []

        for signal in policy.signals where screen.traits.contains(signal.trait) {
            let effective = signal.weight * profile.multiplier(for: signal.axis)
            switch signal.favours {
            case .swiftUI: swiftUI += effective
            case .uiKit: uiKit += effective
            }
            reasons.append(Reason(trait: signal.trait, favours: signal.favours,
                                  axis: signal.axis, effectiveWeight: effective))
        }
        reasons.sort { ($0.effectiveWeight, $0.trait.rawValue) > ($1.effectiveWeight, $1.trait.rawValue) }

        let margin = abs(swiftUI - uiKit)
        let decisive = margin > policy.tieMargin
        let framework: Framework
        if !decisive {
            framework = policy.defaultFramework
        } else {
            framework = swiftUI > uiKit ? .swiftUI : .uiKit
        }
        return Verdict(screen: screen, author: author, framework: framework,
                       swiftUIScore: swiftUI, uiKitScore: uiKit,
                       reasons: reasons, decisive: decisive)
    }

    public func verdicts(for catalogue: [Screen], author: Author) -> [Verdict] {
        catalogue.map { verdict(for: $0, author: author) }
    }
}
