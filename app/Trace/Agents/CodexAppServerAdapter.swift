import Foundation

final class CodexAppServerAdapter: AgentAdapter {
    let kind: AgentKind = .codex

    func probe() async -> (version: String?, auth: AgentAuthStatus, capabilities: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["codex"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else {
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
        if let resumeId {
            let result = try await rpc.request("thread/resume", params: ["threadId": resumeId])
            sessionId = (result["threadId"] as? String) ?? resumeId
        } else {
            let result = try await rpc.request("thread/start", params: [
                "cwd": cwd.path,
            ])
            sessionId = result["threadId"] as? String
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
                turnId = result["turnId"] as? String
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
            model: nil,
            protocolVersion: "app-server",
            sessionId: sessionId,
            cursor: turnId,
            scopeHash: scopeHash,
            pendingRequestIds: [],
            usage: lastUsage
        )
    }

    private func handleNotification(_ method: String, _ params: [String: Any]) {
        switch method {
        case "turn/completed", "turn.completed":
            eventContinuation?.yield(.completed)
            eventContinuation?.finish()
        case "item/agentMessage", "item.agentMessage", "turn/stream":
            if let text = params["text"] as? String ?? (params["item"] as? [String: Any])?["text"] as? String {
                eventContinuation?.yield(.assistant(text))
            } else {
                eventContinuation?.yield(.status(method))
            }
        case "item/tool", "item.tool":
            eventContinuation?.yield(.tool(String(describing: params)))
        default:
            if method.contains("approval") || method.contains("permission") {
                let requestId = (params["requestId"] as? String) ?? UUID().uuidString
                eventContinuation?.yield(.permission(requestId: requestId, message: method))
            } else {
                eventContinuation?.yield(.status(method))
            }
        }
    }
}
