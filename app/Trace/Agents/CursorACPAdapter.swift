import Foundation

final class CursorACPAdapter: AgentAdapter {
    let kind: AgentKind = .cursor

    func probe() async -> (version: String?, auth: AgentAuthStatus, capabilities: [String]) {
        let binary = Self.binaryName()
        guard binary != nil else {
            return (nil, .unsupported, [])
        }
        return (nil, .unknown, ["stream", "multi-turn", "permission", "interrupt", "resume", "terminal"])
    }

    func open(scope: String, resumeId: String?) async throws -> AgentSession {
        guard let binary = Self.binaryName() else { throw AdapterError.binaryMissing("agent") }
        let cwd = URL(fileURLWithPath: scope, isDirectory: true)
        let rpc = try JSONRPCProcess(command: [binary, "acp"], cwd: cwd, jsonrpcHeader: true)
        let session = CursorSession(rpc: rpc, cwd: cwd)
        try await session.handshake(resumeId: resumeId)
        return session
    }

    static func binaryName() -> String? {
        for name in ["agent", "cursor-agent"] {
            if AgentPath.isAvailable(name) { return name }
        }
        return nil
    }
}

final class CursorSession: AgentSession {
    private let rpc: JSONRPCProcess
    private let cwd: URL
    private(set) var sessionId: String?
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
        _ = try await rpc.request("initialize", params: [
            "protocolVersion": 1,
            "clientCapabilities": [
                "fs": ["readTextFile": true, "writeTextFile": false],
                "terminal": false,
            ],
        ])
        _ = try? await rpc.request("authenticate", params: ["methodId": "cursor_login"])
        if let resumeId {
            let result = try await rpc.request("session/load", params: ["sessionId": resumeId])
            sessionId = (result["sessionId"] as? String) ?? resumeId
        } else {
            let result = try await rpc.request("session/new", params: [
                "cwd": cwd.path,
                "mcpServers": [],
            ])
            sessionId = result["sessionId"] as? String
        }
        guard sessionId != nil else { throw AdapterError.handshakeFailed("no session id") }
    }

    func send(_ message: String) async throws -> AsyncStream<AgentEvent> {
        let stream = AsyncStream<AgentEvent> { cont in
            self.eventContinuation = cont
        }
        guard let sessionId else { throw AdapterError.handshakeFailed("no session") }
        Task {
            do {
                _ = try await rpc.request("session/prompt", params: [
                    "sessionId": sessionId,
                    "prompt": [["type": "text", "text": message]],
                ], timeout: 300)
                eventContinuation?.yield(.completed)
                eventContinuation?.finish()
            } catch {
                eventContinuation?.yield(.error(error.localizedDescription))
                eventContinuation?.finish()
            }
        }
        return stream
    }

    func reply(requestId: String, decision: String) async throws {
        // Cursor permission reply: allow-once / reject-once (never allow-always for delete)
        let optionId = decision == "allow" ? "allow-once" : "reject-once"
        try rpc.notify("session/request_permission_response", params: [
            "requestId": requestId,
            "outcome": ["outcome": "selected", "optionId": optionId],
        ])
    }

    func interrupt() async throws {
        guard let sessionId else { return }
        _ = try? await rpc.request("session/cancel", params: ["sessionId": sessionId])
    }

    func cancel() async throws {
        try await interrupt()
        rpc.interruptThenKill()
        eventContinuation?.finish()
    }

    func checkpoint(projectId: String, scopeHash: String) -> SessionCheckpoint {
        SessionCheckpoint(
            projectId: projectId,
            agent: AgentKind.cursor.rawValue,
            model: nil,
            protocolVersion: "acp-1",
            sessionId: sessionId,
            cursor: nil,
            scopeHash: scopeHash,
            pendingRequestIds: [],
            usage: lastUsage
        )
    }

    private func handleNotification(_ method: String, _ params: [String: Any]) {
        switch method {
        case "session/update":
            if let update = params["update"] as? [String: Any] {
                if let text = update["text"] as? String {
                    eventContinuation?.yield(.assistant(text))
                } else if let message = update["message"] as? String {
                    eventContinuation?.yield(.assistant(message))
                } else {
                    eventContinuation?.yield(.status(String(describing: update["sessionUpdate"] ?? "update")))
                }
            }
        case "session/request_permission":
            let requestId = (params["requestId"] as? String) ?? UUID().uuidString
            let message = String(describing: params["toolCall"] ?? params)
            eventContinuation?.yield(.permission(requestId: requestId, message: message))
        case "cursor/ask_question", "cursor/create_plan":
            let requestId = (params["requestId"] as? String) ?? UUID().uuidString
            eventContinuation?.yield(.question(requestId: requestId, message: method))
        default:
            eventContinuation?.yield(.status(method))
        }
    }
}
