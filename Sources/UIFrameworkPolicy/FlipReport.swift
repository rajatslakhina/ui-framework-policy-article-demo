import Foundation

/// A screen whose verdict changes when the author changes.
public struct Flip: Codable, Sendable, Hashable {
    public let screen: Screen
    public let from: Framework
    public let to: Framework
    public let humanMargin: Double
    public let agentMargin: Double
}

/// Compares a catalogue under two authors and reports what moved.
public struct FlipReport: Codable, Sendable, Hashable {
    public let humanVerdicts: [Verdict]
    public let agentVerdicts: [Verdict]
    public let flips: [Flip]

    public var screenCount: Int { humanVerdicts.count }
    public var flipCount: Int { flips.count }

    public func count(_ framework: Framework, for author: Author) -> Int {
        let verdicts = author == .human ? humanVerdicts : agentVerdicts
        return verdicts.filter { $0.framework == framework }.count
    }

    public static func compare(catalogue: [Screen], evaluator: Evaluator = Evaluator()) -> FlipReport {
        let human = evaluator.verdicts(for: catalogue, author: .human)
        let agent = evaluator.verdicts(for: catalogue, author: .agent)
        var flips: [Flip] = []
        for index in human.indices where index < agent.count {
            let h = human[index], a = agent[index]
            if h.framework != a.framework {
                flips.append(Flip(screen: h.screen, from: h.framework, to: a.framework,
                                  humanMargin: h.margin, agentMargin: a.margin))
            }
        }
        return FlipReport(humanVerdicts: human, agentVerdicts: agent, flips: flips)
    }

    /// One point on the sensitivity curve: how many screens flip away from
    /// the human verdict when the agent profile's ergonomics multiplier is `ergonomics`.
    public struct SweepPoint: Codable, Sendable, Hashable {
        public let ergonomics: Double
        public let flips: Int
    }

    /// Sweeps the ergonomics multiplier from 1.0 down to 0.0 in `steps`
    /// equal steps, holding every other multiplier at the given profile's
    /// values. Answers "how much does an agent have to discount ergonomics
    /// before the catalogue starts moving?"
    public static func sweep(catalogue: [Screen],
                             policy: FrameworkPolicy = .standard,
                             agentProfile: AuthorProfile = .agent,
                             steps: Int = 10) -> [SweepPoint] {
        let stepCount = max(1, steps)
        return (0...stepCount).map { step in
            let ergonomics = 1.0 - Double(step) / Double(stepCount)
            var profile = agentProfile
            profile.ergonomics = ergonomics
            var swept = policy
            swept.profiles[.agent] = profile
            let report = compare(catalogue: catalogue, evaluator: Evaluator(policy: swept))
            return SweepPoint(ergonomics: ergonomics, flips: report.flipCount)
        }
    }
}
