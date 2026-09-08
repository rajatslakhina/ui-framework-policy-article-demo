#if canImport(SwiftUI)
import SwiftUI

/// The demo is itself a SwiftUI screen on purpose: it is form-like and
/// state-driven, which is exactly where the policy says SwiftUI still wins.
public struct UIFrameworkPolicyDemoView: View {
    @State private var author: Author = .human
    @State private var selected: Screen?
    private let evaluator = Evaluator()
    private let report = FlipReport.compare(catalogue: Fixture.catalogue)

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Author", selection: $author) {
                        ForEach(Author.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    summaryRow
                }
                Section("Catalogue") {
                    ForEach(evaluator.verdicts(for: Fixture.catalogue, author: author), id: \.screen) { verdict in
                        Button { selected = verdict.screen } label: { row(for: verdict) }
                            .buttonStyle(.plain)
                    }
                }
                Section("Agent instructions") {
                    NavigationLink("Render CLAUDE.md block") {
                        ScrollView {
                            Text(AgentInstructions.render())
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .navigationTitle("CLAUDE.md")
                    }
                }
            }
            .navigationTitle("UI Framework Policy")
            .sheet(item: $selected) { screen in
                VerdictDetail(verdict: evaluator.verdict(for: screen, author: author))
            }
        }
    }

    private var summaryRow: some View {
        let flips = report.flipCount
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(report.count(.swiftUI, for: author)) SwiftUI · \(report.count(.uiKit, for: author)) UIKit")
                .font(.headline)
            Text("\(flips) of \(report.screenCount) screens flip when the author becomes an agent")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func row(for verdict: Verdict) -> some View {
        let flipped = report.flips.contains { $0.screen == verdict.screen }
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.screen.name)
                Text("SwiftUI \(AgentInstructions.format(verdict.swiftUIScore)) · UIKit \(AgentInstructions.format(verdict.uiKitScore))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if flipped && author == .agent {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.orange)
            }
            Text(verdict.framework.rawValue)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(verdict.framework == .swiftUI ? Color.blue.opacity(0.15) : Color.green.opacity(0.15))
                .clipShape(Capsule())
        }
    }
}

struct VerdictDetail: View {
    let verdict: Verdict

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Verdict", value: verdict.framework.rawValue)
                    LabeledContent("SwiftUI", value: AgentInstructions.format(verdict.swiftUIScore))
                    LabeledContent("UIKit", value: AgentInstructions.format(verdict.uiKitScore))
                    LabeledContent("Decisive", value: verdict.decisive ? "Yes" : "No — default applied")
                }
                Section("Reasons (\(verdict.author.rawValue) author)") {
                    ForEach(verdict.reasons, id: \.self) { reason in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(reason.trait.rawValue) → \(reason.favours.rawValue)")
                            Text("\(reason.axis.rawValue), effective \(AgentInstructions.format(reason.effectiveWeight))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle(verdict.screen.name)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }
}
#endif
