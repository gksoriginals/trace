import SwiftUI

/// S13 Ask Trace — full local memory corpus first; agent = Mode 2 skills+context+input.
struct AskTraceView: View {
    @ObservedObject var model: AppModel
    var initialProjectId: String?
    var initialItemId: String?

    @State private var question = ""
    @State private var projectId = ""
    @State private var itemId: String?
    @State private var answer: AskAnswer?
    @State private var offerAgent = false
    @State private var showAgentConfirm = false
    @State private var selectedAgent: AgentKind = .cursor
    @State private var phase: Phase = .idle

    private enum Phase { case idle, retrieving, answered, escalating, stopped }

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TraceSpace.xl) {
                header
                scopeChips
                questionField
                actions
                if showAgentConfirm { agentConfirm }
                if let answer { answerCard(answer) }
                if supervisor.isBusy || phase == .escalating { agentPanel }
                Text("Ask is read-only. Memory uses the full local corpus for the scope. Agent escalation uses harness tools with composed inputs — it cannot Execute.")
                    .font(TraceType.meta)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            .padding(TraceSpace.xxl)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .background(TraceColor.canvas)
        .onAppear {
            projectId = initialProjectId ?? ""
            itemId = initialItemId
            selectedAgent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
            if let itemId, let item = store.decideLater.first(where: { $0.id == itemId }) {
                question = "Why is \(item.action ?? item.artifact_id ?? item.id) doubtful, and what would resolve it?"
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            TraceScreenHeader(
                title: "Ask Trace",
                subtitle: "Memory only · local · full corpus for scope · no hosted tokens — until you escalate."
            )
            Spacer()
            Button("Close") { model.destination = .home }
                .buttonStyle(.bordered)
        }
    }

    private var scopeChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scope")
                .font(.system(size: 13, weight: .semibold))
            HStack {
                Picker("Project", selection: $projectId) {
                    Text("All permitted").tag("")
                    ForEach(store.projects) { Text($0.displayName).tag($0.id) }
                }
                .labelsHidden()
                .frame(maxWidth: 280)
                if let itemId {
                    Label("Item \(itemId)", systemImage: TraceSymbol.decideLater)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(TraceColor.elevated)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .traceCard(elevated: true)
    }

    private var questionField: some View {
        TextField("Ask about storage, provenance, or a Decide-later item…", text: $question, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            .onSubmit { runMemory() }
    }

    private var actions: some View {
        HStack {
            Button {
                runMemory()
            } label: {
                Label(phase == .retrieving ? "Retrieving…" : "Ask memory", systemImage: TraceSymbol.memory)
            }
            .buttonStyle(.borderedProminent)
            .tint(TraceColor.brand)
            .keyboardShortcut(.defaultAction)
            .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase == .retrieving)

            if offerAgent {
                Button("Ask agent…") {
                    showAgentConfirm = true
                }
                .buttonStyle(.bordered)
            }
            if supervisor.isBusy {
                Button {
                    Task {
                        await supervisor.cancel()
                        phase = .stopped
                    }
                } label: {
                    Label("Stop", systemImage: TraceSymbol.stop)
                }
            }
        }
    }

    private var agentConfirm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accept agent scope")
                .font(.system(size: 15, weight: .semibold))
            Text("Before the first outbound message: agent, project scope, and minimized evidence that may leave this Mac. There is no token allowance to accept.")
                .font(.caption)
                .foregroundStyle(TraceColor.textSecondary)
            Picker("Agent", selection: $selectedAgent) {
                ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            labeled("Project", projectId.isEmpty ? (store.projects.first?.displayName ?? "Pick a project") : projectId)
            labeled("Evidence leaving Mac", "Question + paths to local memory/decide-later/insights (harness tools read them). Prior memory answer summary if any.")
            HStack {
                Button("Stay on memory answer") { showAgentConfirm = false }
                Button("Accept & ask agent") {
                    showAgentConfirm = false
                    Task { await runAgent() }
                }
                .buttonStyle(.borderedProminent)
                .tint(TraceColor.brand)
            }
        }
        .traceCard(elevated: true)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(TraceColor.textSecondary)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
    }

    private func answerCard(_ answer: AskAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(answer.tier.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(TraceColor.elevated)
                    .foregroundStyle(TraceColor.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Spacer()
                Text("Usage: \(answer.usage?.display ?? "unavailable")")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Text(answer.text)
                .textSelection(.enabled)
            if !answer.citations.isEmpty {
                Text("Sources: \(answer.citations.joined(separator: ", "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(TraceColor.brand)
            }
            if answer.unknown {
                Text("Memory is insufficient or stale for a confident answer. Escalate only if you accept provider scope.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.review)
            }
        }
        .traceCard()
    }

    private var agentPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                AgentBadge(kind: selectedAgent, compact: true)
                Text(supervisor.status)
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Text(supervisor.log.suffix(10).joined(separator: "\n"))
                .font(.system(.caption, design: .monospaced))
            if supervisor.pendingPermission != nil {
                HStack {
                    Button("Allow once") { Task { await supervisor.replyToPermission(allow: true) } }
                    Button("Reject") { Task { await supervisor.replyToPermission(allow: false) } }
                }
            }
        }
        .traceCard(elevated: true)
    }

    private func runMemory() {
        phase = .retrieving
        let events: [MemoryEvent]
        if projectId.isEmpty {
            events = store.projects.flatMap { store.events(for: $0.id) }
        } else {
            events = store.events(for: projectId)
        }
        let result = MemoryAsk.answer(
            question: question,
            events: events,
            scopeProjectId: projectId.isEmpty ? nil : projectId
        )
        answer = result
        offerAgent = result.unknown || result.citations.isEmpty
        showAgentConfirm = false
        phase = .answered
    }

    private func runAgent() async {
        guard let project = store.projects.first(where: { $0.id == projectId })
                ?? store.projects.first else {
            answer = AskAnswer(
                tier: "agent",
                text: "Pick a project scope before asking the agent.",
                citations: [],
                unknown: true,
                usage: .unavailable
            )
            return
        }
        phase = .escalating
        let root = store.projectRoot(for: project)
        let payload = SkillComposer.askPayload(
            project: project,
            store: store,
            question: question,
            priorMemoryAnswer: answer?.text,
            itemId: itemId
        )
        await supervisor.start(
            kind: selectedAgent,
            projectRoot: root,
            resumeId: nil,
            prompt: SkillComposer.compose(payload)
        )
        answer = AskAnswer(
            tier: "agent",
            text: supervisor.log.suffix(12).joined(separator: "\n"),
            citations: answer?.citations ?? [],
            unknown: false,
            usage: supervisor.usage
        )
        phase = .answered
    }
}
