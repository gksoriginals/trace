import SwiftUI

struct AskTraceView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var projectId: String?
    @State private var question = ""
    @State private var answer: AskAnswer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask Trace")
                .font(.system(size: 20, weight: .semibold))
            HStack {
                Text(answer?.tier ?? "Memory only · local · no hosted tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if let projectId {
                    Text(projectId)
                        .font(.system(size: 11, design: .monospaced))
                        .padding(4)
                        .background(TraceTheme.elevated(scheme))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    Text("all visible projects")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Why was this kept? Who uses the store?", text: $question, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)

            Button("Ask memory") {
                answer = store.ask(question: question, projectId: projectId)
            }
            .buttonStyle(.borderedProminent)
            .tint(TraceTheme.brand(scheme))
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let answer {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        if answer.unknown {
                            Text("Unknown / incomplete")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TraceTheme.review(scheme))
                        }
                        Text(answer.text)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                        if !answer.citations.isEmpty {
                            Text("Citations: " + answer.citations.joined(separator: ", "))
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Text("Ask agent is M2. This answer did not leave the Mac.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()
            HStack {
                Spacer()
                Button("Close") { dismiss() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(TraceTheme.canvas(scheme))
    }
}
