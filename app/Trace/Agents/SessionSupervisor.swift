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
    /// Bumped on every start/cancel so a superseded `for await` stream stops mutating UI.
    private var runGeneration = 0

    func probe(_ kind: AgentKind) async -> (version: String?, auth: AgentAuthStatus, capabilities: [String]) {
        await AgentRegistry.adapter(for: kind).probe()
    }

    func start(kind: AgentKind, projectRoot: String, resumeId: String?, prompt: String) async {
        await replaceSession(clearLog: true)
        let generation = runGeneration
        self.kind = kind
        isBusy = true
        status = "handshake"
        log.append("Opening \(kind.title) session…")
        do {
            let adapter = AgentRegistry.adapter(for: kind)
            let opened = try await adapter.open(scope: projectRoot, resumeId: resumeId)
            guard isCurrent(generation) else {
                await reap(opened)
                return
            }
            self.session = opened
            status = "running"
            log.append("Session \(opened.sessionId ?? "unknown")")
            let stream = try await opened.send(prompt)
            for await event in stream {
                guard isCurrent(generation) else { return }
                handle(event)
            }
            guard isCurrent(generation) else { return }
            // Never overwrite a real terminal failure/cancel with a synthetic "completed".
            if status != "error" && status != "cancelled" && status != "completed" {
                status = "completed"
                if log.last != "Completed" { log.append("Completed") }
            }
        } catch {
            guard isCurrent(generation) else { return }
            status = "error"
            log.append(error.localizedDescription)
        }
        guard isCurrent(generation) else { return }
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
        // Idempotent: Stop on an already-dead session must clear the banner, not append more noise.
        guard isBusy || session != nil else {
            dismissStatus()
            return
        }
        runGeneration += 1
        status = "cancelling"
        do {
            try await session?.cancel()
        } catch {
            log.append(error.localizedDescription)
        }
        session = nil
        pendingPermission = nil
        isBusy = false
        status = "cancelled"
        log.append("Cancelled")
    }

    /// Latest useful line for banners (skip empty / duplicate cancel noise).
    var lastMessage: String? {
        for line in log.reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed == "Cancelled" || trimmed.hasPrefix("Cancelled;") { continue }
            return trimmed
        }
        return log.last
    }

    var isFailed: Bool { status == "error" }
    var isCancelled: Bool { status == "cancelled" }
    var isCompleted: Bool { status == "completed" }
    /// Home always shows live work and the last finished outcome until the user dismisses it.
    var showsHomeBanner: Bool { isBusy || isFailed || isCancelled || isCompleted }

    /// Clear a finished/failed session so Home/Run stop showing the banner.
    func dismissStatus() {
        guard !isBusy else { return }
        status = "idle"
        log = []
        usage = .unavailable
        pendingPermission = nil
        session = nil
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

    private func isCurrent(_ generation: Int) -> Bool {
        generation == runGeneration
    }

    /// Cancel a session that never became `self.session` (superseded during `open`).
    private func reap(_ session: AgentSession) async {
        do {
            try await session.cancel()
        } catch {
            log.append(error.localizedDescription)
        }
    }

    /// Invalidate any in-flight start and cancel the owned process group before opening another.
    private func replaceSession(clearLog: Bool) async {
        runGeneration += 1
        let previous = session
        session = nil
        pendingPermission = nil
        if clearLog {
            log = []
            usage = .unavailable
        }
        guard let previous else { return }
        do {
            try await previous.cancel()
        } catch {
            log.append(error.localizedDescription)
        }
    }
}
