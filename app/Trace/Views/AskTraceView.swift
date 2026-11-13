import SwiftUI

/// S13 Ask Trace — chat-style memory-first Ask; agent escalation after scope accept.
/// `compact` presents as the floating corner mini-chat with composer focused.
struct AskTraceView: View {
    @ObservedObject var model: AppModel
    var initialProjectId: String?
    var initialItemId: String?
    var compact: Bool = false
    var onClose: (() -> Void)? = nil

    @State private var question = ""
    @State private var projectId = ""
    @State private var itemId: String?
    @State private var messages: [ChatMessage] = []
    @State private var offerAgent = false
    @State private var showAgentConfirm = false
    @State private var selectedAgent: AgentKind = .cursor
    @State private var phase: Phase = .idle
    @FocusState private var composerFocused: Bool

    private enum Phase { case idle, retrieving, answered, escalating, stopped }

    private struct ChatMessage: Identifiable, Hashable {
        let id = UUID()
        let role: Role
        let text: String
        var tier: String?
        var citations: [String] = []
        var usage: UsageReport?
        var unknown: Bool = false

        enum Role { case user, assistant }
    }

    private var store: TraceStore { model.store }
    private var supervisor: SessionSupervisor { model.supervisor }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(TraceColor.line.opacity(0.35))
            messageList
            if showAgentConfirm {
                agentConfirm.padding(.horizontal, compact ? TraceSpace.md : TraceSpace.xl)
            }
            if supervisor.isBusy || phase == .escalating {
                agentPanel
                    .padding(.horizontal, compact ? TraceSpace.md : TraceSpace.xl)
                    .padding(.bottom, TraceSpace.sm)
            }
            composer
        }
        .background(compact ? TraceColor.surface : TraceColor.canvas)
        .onAppear {
            projectId = initialProjectId ?? ""
            itemId = initialItemId
            selectedAgent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
            if let itemId, let item = store.decideLater.first(where: { $0.id == itemId }) {
                question = "Why is \(item.action ?? item.artifact_id ?? item.id) doubtful, and what would resolve it?"
            }
            if messages.isEmpty {
                messages.append(ChatMessage(
                    role: .assistant,
                    text: compact
                        ? "Ask about storage or a Decide-later item. Memory first — escalate only if needed."
                        : "Ask about storage, provenance, or a Decide-later item. Memory only · local · no hosted tokens — until you escalate.",
                    tier: "memory"
                ))
            }
            if compact {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    composerFocused = true
                }
            }
        }
        .onChange(of: initialProjectId) { _, newValue in
            if let newValue { projectId = newValue }
        }
        .onChange(of: initialItemId) { _, newValue in
            itemId = newValue
        }
    }

    private var header: some View {
        HStack(spacing: TraceSpace.sm) {
            Text("Ask")
                .font(compact ? TraceType.section : TraceType.screen)
                .foregroundStyle(TraceColor.textPrimary)
            Spacer(minLength: 0)
            Picker("Project", selection: $projectId) {
                Text("All permitted").tag("")
                ForEach(store.projects) { Text($0.displayName).tag($0.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: compact ? 140 : 200)
            if let onClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TraceColor.textSecondary)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Close Ask")
                .accessibilityLabel("Close Ask")
            }
        }
        .padding(.horizontal, compact ? TraceSpace.md : TraceSpace.windowPad)
        .padding(.vertical, compact ? TraceSpace.sm : TraceSpace.md)
        .background(compact ? TraceColor.elevated.opacity(0.55) : TraceColor.surface)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: TraceSpace.sm) {
                    ForEach(messages) { message in
                        bubble(message).id(message.id)
                    }
                }
                .padding(compact ? TraceSpace.md : TraceSpace.xl)
                .frame(maxWidth: compact ? .infinity : 720, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: compact ? .leading : .center)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 8) {
                if message.role == .assistant, let tier = message.tier {
                    HStack {
                        Text(tier.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TraceColor.elevated)
                            .foregroundStyle(TraceColor.brand)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        if let usage = message.usage {
                            Text("Usage: \(usage.display)")
                                .font(.caption)
                                .foregroundStyle(TraceColor.textSecondary)
                        }
                    }
                }
                Text(message.text)
                    .textSelection(.enabled)
                    .foregroundStyle(TraceColor.textPrimary)
                if !message.citations.isEmpty {
                    Text("Sources: \(message.citations.joined(separator: ", "))")
                        .font(.caption.monospaced())
                        .foregroundStyle(TraceColor.brand)
                }
                if message.unknown {
                    Text("Memory is insufficient or stale. Escalate only if you accept provider scope.")
                        .font(.caption)
                        .foregroundStyle(TraceColor.review)
                }
            }
            .padding(TraceSpace.md)
            .background(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .fill(message.role == .user ? TraceColor.brand.opacity(0.12) : TraceColor.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .stroke(TraceColor.line.opacity(0.35), lineWidth: 1)
            )
            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: TraceSpace.sm) {
            TextField(
                compact ? "Ask Trace…" : "Ask about storage, provenance, or a Decide-later item…",
                text: $question,
                axis: .vertical
            )
            .lineLimit(compact ? 2...4 : 2...5)
            .textFieldStyle(.plain)
            .focused($composerFocused)
            .padding(TraceSpace.md)
            .background(compact ? TraceColor.canvas : TraceColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: TraceSpace.radius, style: .continuous)
                    .stroke(TraceColor.line.opacity(0.35), lineWidth: 1)
            )
            .onSubmit { runMemory() }

            HStack(spacing: TraceSpace.sm) {
                if compact {
                    Button {
                        runMemory()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(TraceColor.brand)
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut(.defaultAction)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase == .retrieving)
                    .help(phase == .retrieving ? "Retrieving…" : "Ask memory")
                    .accessibilityLabel(phase == .retrieving ? "Retrieving" : "Ask memory")
                } else {
                    Button {
                        runMemory()
                    } label: {
                        Label(phase == .retrieving ? "Retrieving…" : "Ask memory", systemImage: TraceSymbol.memory)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TraceColor.brand)
                    .keyboardShortcut(.defaultAction)
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || phase == .retrieving)
                }

                if offerAgent {
                    Button("Ask agent…") { showAgentConfirm = true }
                        .buttonStyle(.bordered)
                        .controlSize(compact ? .small : .regular)
                }
                if supervisor.isBusy {
                    Button {
                        Task {
                            await supervisor.cancel()
                            phase = .stopped
                            messages.append(ChatMessage(role: .assistant, text: "Stopped.", tier: "agent"))
                        }
                    } label: {
                        Label("Stop", systemImage: TraceSymbol.stop)
                    }
                    .controlSize(compact ? .small : .regular)
                }
                if !compact {
                    Spacer()
                    Text("Ask is read-only. It cannot Execute.")
                        .font(TraceType.meta)
                        .foregroundStyle(TraceColor.textSecondary)
                }
            }
        }
        .padding(.horizontal, compact ? TraceSpace.md : TraceSpace.windowPad)
        .padding(.vertical, TraceSpace.md)
        .background(TraceColor.elevated)
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
        .padding(.bottom, TraceSpace.sm)
    }

    private func labeled(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(TraceColor.textSecondary)
            Text(value).font(.system(size: 12, design: .monospaced))
        }
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
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        messages.append(ChatMessage(role: .user, text: q))
        question = ""
        phase = .retrieving
        let events: [MemoryEvent]
        if projectId.isEmpty {
            events = store.projects.flatMap { store.events(for: $0.id) }
        } else {
            events = store.events(for: projectId)
        }
        let result = MemoryAsk.answer(
            question: q,
            events: events,
            scopeProjectId: projectId.isEmpty ? nil : projectId
        )
        messages.append(ChatMessage(
            role: .assistant,
            text: result.text,
            tier: result.tier,
            citations: result.citations,
            usage: result.usage,
            unknown: result.unknown
        ))
        offerAgent = result.unknown || result.citations.isEmpty
        showAgentConfirm = false
        phase = .answered
    }

    private func runAgent() async {
        guard let project = store.projects.first(where: { $0.id == projectId })
                ?? store.projects.first else {
            messages.append(ChatMessage(
                role: .assistant,
                text: "Pick a project scope before asking the agent.",
                tier: "agent",
                usage: .unavailable,
                unknown: true
            ))
            return
        }
        phase = .escalating
        let prior = messages.last(where: { $0.role == .assistant })?.text
        let lastUser = messages.last(where: { $0.role == .user })?.text ?? ""
        let root = store.projectRoot(for: project)
        let payload = SkillComposer.askPayload(
            project: project,
            store: store,
            question: lastUser,
            priorMemoryAnswer: prior,
            itemId: itemId
        )
        await supervisor.start(
            kind: selectedAgent,
            projectRoot: root,
            resumeId: nil,
            prompt: SkillComposer.compose(payload)
        )
        messages.append(ChatMessage(
            role: .assistant,
            text: supervisor.log.suffix(12).joined(separator: "\n"),
            tier: "agent",
            citations: messages.last(where: { !$0.citations.isEmpty })?.citations ?? [],
            usage: supervisor.usage
        ))
        phase = .answered
    }
}
