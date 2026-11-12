import SwiftUI

/// S13 Ask Trace — memory-first, optional agent escalation, read-only.
struct AskTraceView: View {
    @ObservedObject var model: AppModel
    var initialProjectId: String?
    var initialItemId: String?

    @State private var question = ""
    @State private var projectId = ""
    @State private var itemId: String?
    @State private var answer: AskAnswer?
    @State private var offerAgent = false
    @State private var selectedAgent: AgentKind = .cursor
    @State private var phase: Phase = .idle

    private enum Phase { case idle, retrieving, answered, escalating, stopped }

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                scopeChips
                questionField
                actions
                if let answer { answerCard(answer) }
                if supervisor.isBusy || phase == .escalating { agentPanel }
                Text("Ask is read-only. It can propose an action card; it cannot Execute.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            .padding(32)
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ask Trace")
                    .font(.system(size: 28, weight: .semibold))
                Text("Memory only · local · no hosted tokens — until you escalate.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Spacer()
            Button("Close") { model.destination = .home }
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
            HStack(spacing: 8) {
                ForEach(["Why was this kept?", "What shares this cache?", "Is coverage fresh?"], id: \.self) { example in
                    Button(example) { question = example }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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
                Picker("Agent", selection: $selectedAgent) {
                    ForEach(AgentKind.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 140)
                Button("Ask agent") { Task { await runAgent() } }
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

    private func answerCard(_ answer: AskAnswer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                tierLabel(answer.tier)
                Spacer()
                Text("Usage: \(answer.usage?.display ?? "unavailable")")
                    .font(.caption)
                    .foregroundStyle(TraceColor.textSecondary)
            }
            Text(answer.text)
                .textSelection(.enabled)
                .foregroundStyle(TraceColor.textPrimary)

            if !answer.citations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sources")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TraceColor.textSecondary)
                    ForEach(answer.citations, id: \.self) { cite in
                        Text(cite)
                            .font(.caption.monospaced())
                            .foregroundStyle(TraceColor.brand)
                            .onTapGesture {
                                if !projectId.isEmpty {
                                    model.destination = .memory(projectId)
                                }
                            }
                    }
                }
            }

            if answer.unknown {
                Text("Memory is insufficient or stale for a confident answer. Escalate only if you accept provider scope.")
                    .font(.caption)
                    .foregroundStyle(TraceColor.review)
            }
        }
        .traceCard()
    }

    private func tierLabel(_ tier: String) -> some View {
        Text(tier.uppercased())
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(TraceColor.elevated)
            .foregroundStyle(TraceColor.brand)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
        let memoryBits = String((answer?.text ?? "").prefix(800))
        let payload = SkillComposer.Payload(
            skillIds: ["prepare-home", "memory-writer"],
            params: [
                "project_id": project.id,
                "roots": project.roots ?? [root],
                "never_touch": store.settings.neverTouch,
            ],
            inputs: [
                "question": question,
                "memory_summary": memoryBits,
                "item_id": itemId ?? "",
                "index_path": store.indexURL.path,
            ],
            task: """
            Trace Ask (read-only). Answer the question using project memory. \
            Separate memory facts from new observations. Cite event ids. Do not delete or move files.
            """
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
