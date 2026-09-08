import Foundation

/// A twelve-screen catalogue shaped like a mid-size commerce app. The
/// traits are the *inputs*; the verdicts and flips are computed, never
/// hard-coded, so changing a policy weight changes the numbers everywhere.
public enum Fixture {
    public static let catalogue: [Screen] = [
        Screen(name: "Settings",              traits: [.formLike, .stateDriven]),
        Screen(name: "Onboarding",            traits: [.rapidIteration, .stateDriven, .appleSkillCoverage]),
        Screen(name: "Home Feed",             traits: [.heavyList, .profilingCritical, .stateDriven]),
        Screen(name: "Product Detail",        traits: [.pixelExactLayout, .stateDriven, .rapidIteration]),
        Screen(name: "Checkout",              traits: [.formLike, .stateDriven, .presentationStateNeeded]),
        Screen(name: "Review Composer",       traits: [.richTextEditing, .customGestures]),
        Screen(name: "Watch Companion",       traits: [.crossPlatform, .formLike]),
        Screen(name: "Photo Editor",          traits: [.customGestures, .pixelExactLayout, .profilingCritical]),
        Screen(name: "Search Results",        traits: [.heavyList, .rapidIteration, .stateDriven]),
        Screen(name: "Profile",               traits: [.pixelExactLayout, .formLike, .stateDriven, .appleSkillCoverage]),
        Screen(name: "Legacy Order History",  traits: [.legacyUIKitHost, .backDeployBelow17, .stateDriven, .rapidIteration]),
        Screen(name: "Paywall",               traits: [.rapidIteration, .stateDriven, .pixelExactLayout, .crossPlatform]),
    ]
}
