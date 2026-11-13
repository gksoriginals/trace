import Foundation

final class CodexAppServerAdapter: AgentAdapter {
    let kind: AgentKind = .codex

    func probe() async -> (version: String?, auth: AgentAuthStatus, capabilities: [String]) {
        guard AgentPath.isAvailable("codex") else {
            return (nil, .unsupported, [])
        }
        return (nil, .unknown, ["stream", "multi-turn", "permission", "interrupt", "resume", "terminal"])
    }

    func open(scope: String, resumeId: String?) async throws -> AgentSession {
        let cwd = URL(fileURLWithPath: scope, isDirectory: true)
        // Codex app-server omits jsonrpc header per engineering.md
        let rpc = try JSONRPCProcess(
            command: ["codex", "app-server", "--listen", "stdio://"],
            cwd: cwd,
            jsonrpcHeader: false
        )
        let session = CodexSession(rpc: rpc, cwd: cwd)
        try await session.handshake(resumeId: resumeId)
        return session
    }
}

final class CodexSession: AgentSession {
    private let rpc: JSONRPCProcess
    private let cwd: URL
    private(set) var sessionId: String?
    private var turnId: String?
    private var selectedModel: String?
    private var eventContinuation: AsyncStream<AgentEvent>.Continuation?
    private var lastUsage = UsageReport.unavailable

    init(rpc: JSONRPCProcess, cwd: URL) {
        self.rpc = rpc
        self.cwd = cwd
        rpc.setNotificationHandler { [weak self] method, params in
            self?.handleNotification(method, params)
        }
    }

    func handshake(resumeId: String?) async throws {
        // Required: initialize once per connection, then `initialized`, then thread APIs.
        // Skipping initialize returns JSON-RPC -32600 "Not initialized".
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
        _ = try await rpc.request("initialize", params: [
            "clientInfo": [
                "name": "trace",
                "title": "Trace",
                "version": version,
            ],
        ])
        try rpc.notify("initialized", params: [:])

        // ChatGPT accounts reject stale ~/.codex model ids (e.g. gpt-6-luna). Prefer the
        // account's default from model/list so thread/start does not inherit a broken config.
        selectedModel = try await resolveSupportedModel()

        if let resumeId {
            let result = try await rpc.request("thread/resume", params: ["threadId": resumeId])
            sessionId = Self.threadId(from: result) ?? resumeId
        } else {
            var params: [String: Any] = ["cwd": cwd.path]
            if let selectedModel {
                params["model"] = selectedModel
            }
            let result = try await rpc.request("thread/start", params: params)
            sessionId = Self.threadId(from: result)
            if let model = result["model"] as? String {
                selectedModel = model
            }
        }
        guard sessionId != nil else { throw AdapterError.handshakeFailed("no thread id") }
    }

    func send(_ message: String) async throws -> AsyncStream<AgentEvent> {
        let stream = AsyncStream<AgentEvent> { cont in
            self.eventContinuation = cont
        }
        guard let sessionId else { throw AdapterError.handshakeFailed("no thread") }
        Task {
            do {
                let result = try await rpc.request("turn/start", params: [
                    "threadId": sessionId,
                    "input": [["type": "text", "text": message]],
                ], timeout: 300)
                turnId = (result["turnId"] as? String)
                    ?? (result["turn"] as? [String: Any])?["id"] as? String
                // Completion often arrives as notification turn/completed
            } catch {
                eventContinuation?.yield(.error(error.localizedDescription))
                eventContinuation?.finish()
            }
        }
        return stream
    }

    func reply(requestId: String, decision: String) async throws {
        let approved = decision == "allow"
        _ = try await rpc.request("turn/respond", params: [
            "requestId": requestId,
            "decision": approved ? "accept" : "decline",
        ])
    }

    func interrupt() async throws {
        guard let turnId else { return }
        _ = try? await rpc.request("turn/interrupt", params: ["turnId": turnId])
    }

    func cancel() async throws {
        try await interrupt()
        rpc.interruptThenKill()
        eventContinuation?.finish()
    }

    func checkpoint(projectId: String, scopeHash: String) -> SessionCheckpoint {
        SessionCheckpoint(
            projectId: projectId,
            agent: AgentKind.codex.rawValue,
            model: selectedModel,
            protocolVersion: "app-server",
            sessionId: sessionId,
            cursor: turnId,
            scopeHash: scopeHash,
            pendingRequestIds: [],
            usage: lastUsage
        )
    }

    private func resolveSupportedModel() async throws -> String? {
        let result = try await rpc.request("model/list", params: [:])
        let data = result["data"] as? [[String: Any]] ?? []
        if let preferred = data.first(where: { ($0["isDefault"] as? Bool) == true }) {
            return (preferred["id"] as? String) ?? (preferred["model"] as? String)
        }
        let first = data.first
        return (first?["id"] as? String) ?? (first?["model"] as? String)
    }

    private static func threadId(from result: [String: Any]) -> String? {
        if let id = result["threadId"] as? String { return id }
        if let thread = result["thread"] as? [String: Any] {
            return (thread["id"] as? String) ?? (thread["sessionId"] as? String)
        }
        return nil
    }

    /// Map turn/completed payload → success or surfaced failure (ChatGPT model_not_found etc.).
    static func terminalEvent(fromTurn params: [String: Any]) -> AgentEvent {
        let turn = params["turn"] as? [String: Any] ?? params
        let status = ((turn["status"] as? String) ?? "").lowercased()
        if status == "failed" || status == "error" || status == "cancelled" {
            let message = Self.turnErrorMessage(from: turn)
                ?? (status == "cancelled" ? "Codex turn cancelled." : "Codex turn failed.")
            return .error(message)
        }
        return .completed
    }

    private static func turnErrorMessage(from turn: [String: Any]) -> String? {
        if let error = turn["error"] as? [String: Any] {
            if let message = error["message"] as? String, !message.isEmpty { return message }
            if let message = error["error"] as? String, !message.isEmpty { return message }
        }
        if let message = turn["error"] as? String, !message.isEmpty { return message }
        return nil
    }

    private func handleNotification(_ method: String, _ params: [String: Any]) {
        // Codex app-server emits many protocol chatter notifications (account/rateLimit/*,
        // item/completed, item/started, …). Never dump raw method names into the Home banner.
        if Self.isProtocolChatter(method) { return }

        switch method {
        case "turn/completed", "turn.completed":
            eventContinuation?.yield(Self.terminalEvent(fromTurn: params))
            eventContinuation?.finish()
        case "turn/failed", "turn.failed":
            let message = Self.turnErrorMessage(from: params["turn"] as? [String: Any] ?? params)
                ?? "Codex turn failed."
            eventContinuation?.yield(.error(message))
            eventContinuation?.finish()
        case "item/agentMessage", "item.agentMessage", "turn/stream", "item/agentMessage/delta",
             "item/agentMessage/completed", "agentMessage/delta":
            if let text = params["text"] as? String
                ?? (params["item"] as? [String: Any])?["text"] as? String
                ?? (params["delta"] as? String)
                ?? ((params["item"] as? [String: Any])?["content"] as? [[String: Any]])?.compactMap({ $0["text"] as? String }).joined() {
                eventContinuation?.yield(.assistant(text))
            }
            // No text → ignore; do not surface the method name.
        case "item/tool", "item.tool", "item/tool/call", "item/commandExecution":
            let name = (params["name"] as? String)
                ?? (params["item"] as? [String: Any])?["name"] as? String
                ?? (params["tool"] as? String)
                ?? "tool"
            eventContinuation?.yield(.tool(name))
        default:
            if method.contains("approval") || method.contains("permission") {
                let requestId = (params["requestId"] as? String) ?? UUID().uuidString
                eventContinuation?.yield(.permission(requestId: requestId, message: method))
            }
            // Unknown non-permission notifications: ignore (do not show method strings).
        }
    }

    /// Wire events that are not user-meaningful progress.
    private static func isProtocolChatter(_ method: String) -> Bool {
        let m = method.lowercased()
        if m.hasPrefix("account/") { return true }
        if m.hasPrefix("thread/") { return true }
        if m.contains("ratelimit") || m.contains("rate_limit") || m.contains("rate-limit") { return true }
        if m.contains("tokenusage") || m.contains("token_usage") { return true }
        // item / turn lifecycle without payload we care about
        let chatter = [
            "item/completed", "item.completed",
            "item/started", "item.started",
            "item/queued", "item.queued",
            "turn/started", "turn.started",
            "turn/diff/updated", "turn.diff.updated",
            "thread/updated", "thread.updated",
            "thread/status/changed",
            "session/updated",
        ]
        return chatter.contains(m)
    }

    /// Drop protocol junk already sitting in supervisor logs before History stores a tail.
    static func meaningfulLogLines(_ lines: [String]) -> [String] {
        lines.filter { line in
            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty || t == "." || t == "preserved" { return false }
            // Raw JSON-RPC method names look like path segments with a slash and no spaces.
            if t.contains("/"), !t.contains(" ") { return false }
            if isProtocolChatter(t) { return false }
            return true
        }
    }
}
