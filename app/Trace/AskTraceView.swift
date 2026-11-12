import SwiftUI

/// Memory-only Ask for dogfood. No agent escalation yet (M2).
struct AskTraceView: View {
    @EnvironmentObject private var store: TraceStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State var seed: String = ""
    @State private var answer: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask Trace")
                .font(.system(size: 20, weight: .semibold))
            Text("Memory only · no hosted model call in this dogfood build")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Ask about a project’s storage…", text: $seed, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            Button("Search memory") {
                answer = searchMemory(query: seed)
            }
            .buttonStyle(.borderedProminent)
            .tint(TraceTheme.brand(scheme))

            ScrollView {
                Text(answer.isEmpty ? "Answers cite local memory events only." : answer)
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TraceTheme.canvas(scheme))
    }

    private func searchMemory(query: String) -> String {
        let q = query.lowercased()
        guard !q.isEmpty else { return "Ask a question about a project path, artifact, or decision." }
        var hits: [String] = []
        for insight in store.insights {
            for event in insight.recentEvents {
                let blob = [event.why, event.what?.location, event.what?.id, event.event_type]
                    .compactMap { $0 }
                    .joined(separator: " ")
                    .lowercased()
                if blob.contains(q) || q.split(separator: " ").contains(where: { blob.contains($0) }) {
                    hits.append("• [\(insight.project.name) / \(event.event_id)] \(event.why ?? event.what?.location ?? "")")
                }
            }
        }
        for item in store.decideLater {
            let blob = "\(item.why_doubtful) \(item.action) \(item.artifact_id)".lowercased()
            if blob.contains(q) {
                hits.append("• [decide-later / \(item.id)] \(item.why_doubtful)")
            }
        }
        if hits.isEmpty {
            return "Unknown from local memory. Agent escalation ships in M2; nothing was sent off-machine."
        }
        return "Memory tier\n\n" + hits.prefix(12).joined(separator: "\n")
    }
}
