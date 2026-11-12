import Foundation

/// Owns live agent work: spawn, stream, deadlines, interrupt, drain, checkpoint.
@MainActor
final class SessionSupervisor: ObservableObject {
    @Published var status: String = "idle"
    @Published var log: [String] = []
    @Published var usage: UsageReport = .unavailable
    @Published var pendingPermission: (requestId: String, message: String)?
    @Published var isBusy = false

    private var session: AgentSession?
    private var kind: AgentKind = .cursor

    func probe(_ kind: AgentKind) async -> (version: String?, auth: AgentAuthStatus, capabilities: [String]) {
        await AgentRegistry.adapter(for: kind).probe()
    }

    func start(kind: AgentKind, projectRoot: String, resumeId: String?, prompt: String) async {
        stopLocalOnly()
        self.kind = kind
        isBusy = true
        status = "handshake"
        log.append("Opening \(kind.title) session…")
        do {
            let adapter = AgentRegistry.adapter(for: kind)
            let session = try await adapter.open(scope: projectRoot, resumeId: resumeId)
            self.session = session
            status = "running"
            log.append("Session \(session.sessionId ?? "unknown")")
            let stream = try await session.send(prompt)
            for await event in stream {
                handle(event)
            }
            status = "completed"
        } catch {
            status = "error"
            log.append(error.localizedDescription)
        }
        isBusy = false
        persistCheckpoint(projectId: projectRoot, scopeHash: projectRoot)
    }

    func replyToPermission(allow: Bool) async {
        guard let pending = pendingPermission, let session else { return }
        // Never allow-always for delete / wider root
        do {
            try await session.reply(requestId: pending.requestId, decision: allow ? "allow" : "reject")
            log.append(allow ? "Allowed once" : "Rejected")
        } catch {
            log.append(error.localizedDescription)
        }
        pendingPermission = nil
    }

    func cancel() async {
        status = "cancelling"
        do {
            try await session?.cancel()
        } catch {
            log.append(error.localizedDescription)
        }
        session = nil
        isBusy = false
        status = "cancelled"
        log.append("Cancelled; process group reaped")
    }

    private func handle(_ event: AgentEvent) {
        switch event {
        case .status(let s):
            log.append(s)
        case .assistant(let text):
            log.append(text)
        case .tool(let name):
            log.append("tool: \(name)")
        case .permission(let id, let message):
            pendingPermission = (id, message)
            status = "needs_answer"
            log.append("Permission: \(message)")
        case .question(let id, let message):
            pendingPermission = (id, message)
            status = "needs_answer"
            log.append("Question: \(message)")
        case .usage(let report):
            usage = report
        case .completed:
            status = "completed"
            log.append("Completed")
        case .error(let message):
            status = "error"
            log.append(message)
        }
    }

    private func persistCheckpoint(projectId: String, scopeHash: String) {
        guard let session else { return }
        let cp = session.checkpoint(projectId: projectId, scopeHash: scopeHash)
        try? AppDatabase.shared.saveCheckpoint(cp)
    }

    private func stopLocalOnly() {
        session = nil
        pendingPermission = nil
        log = []
        usage = .unavailable
    }
}
