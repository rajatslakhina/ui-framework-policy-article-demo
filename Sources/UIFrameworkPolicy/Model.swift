import Foundation

/// The two UI frameworks a lead is choosing between, per screen.
public enum Framework: String, Codable, Sendable, CaseIterable, Hashable {
    case swiftUI = "SwiftUI"
    case uiKit = "UIKit"
}

/// Who writes the first draft of a screen's code. This is the variable
/// the whole policy pivots on: an agent author collapses the value of
/// ergonomics and raises the value of being able to verify from source.
public enum Author: String, Codable, Sendable, CaseIterable, Hashable {
    case human
    case agent
}

/// The axis a signal argues along. Weights are multiplied per author.
public enum Axis: String, Codable, Sendable, CaseIterable, Hashable {
    /// How pleasant/fast the framework is to *write* by hand.
    case ergonomics
    /// Whether a reviewer can predict the result from the source without running it.
    case verifiability
    /// Runtime control: cell reuse, gestures, presentation state, layout precision.
    case control
    /// Raw runtime performance for the screen's workload.
    case performance
    /// Multi-platform reach and Apple's own tooling gravity.
    case reach
}

/// A property of a screen that pushes the verdict one way or the other.
public enum Trait: String, Codable, Sendable, CaseIterable, Hashable {
    // Push toward UIKit
    case heavyList
    case pixelExactLayout
    case customGestures
    case richTextEditing
    case presentationStateNeeded
    case profilingCritical
    case legacyUIKitHost
    case backDeployBelow17
    // Push toward SwiftUI
    case formLike
    case stateDriven
    case crossPlatform
    case rapidIteration
    case appleSkillCoverage

    public var summary: String {
        switch self {
        case .heavyList: return "thousands of heterogeneous cells with reuse/prefetch control"
        case .pixelExactLayout: return "designer-signed layout that must be pixel-exact"
        case .customGestures: return "simultaneous or custom gesture recognisers"
        case .richTextEditing: return "rich text editing with selection/attributes"
        case .presentationStateNeeded: return "code must observe/manage sheet or popover state"
        case .profilingCritical: return "scroll/render perf must be measurable in Instruments"
        case .legacyUIKitHost: return "lives inside an existing UIKit navigation stack"
        case .backDeployBelow17: return "must run below iOS 17 (shim territory)"
        case .formLike: return "settings/form-style screen"
        case .stateDriven: return "many derived states; declarative wins"
        case .crossPlatform: return "shared with watchOS/macOS/visionOS"
        case .rapidIteration: return "prototype or A/B variant, expected to change weekly"
        case .appleSkillCoverage: return "Apple ships an agent skill and training-data gravity for this"
        }
    }
}

/// A screen in the catalogue.
public struct Screen: Codable, Sendable, Hashable, Identifiable {
    public var id: String { name }
    public let name: String
    public let traits: Set<Trait>

    public init(name: String, traits: Set<Trait>) {
        self.name = name
        self.traits = traits
    }
}
