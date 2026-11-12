import Foundation

enum AgentEvent: Equatable {
    case status(String)
    case assistant(String)
    case tool(String)
    case permission(requestId: String, message: String)
    case question(requestId: String, message: String)
    case usage(UsageReport)
    case completed
    case error(String)
}

protocol AgentSession: AnyObject {
    var sessionId: String? { get }
    func send(_ message: String) async throws -> AsyncStream<AgentEvent>
    func reply(requestId: String, decision: String) async throws
    func interrupt() async throws
    func cancel() async throws
    func checkpoint(projectId: String, scopeHash: String) -> SessionCheckpoint
}

protocol AgentAdapter {
    var kind: AgentKind { get }
    func probe() async -> (version: String?, auth: AgentAuthStatus, capabilities: [String])
    func open(scope: String, resumeId: String?) async throws -> AgentSession
}

enum AdapterError: LocalizedError {
    case binaryMissing(String)
    case handshakeFailed(String)
    case unsupported
    case timeout

    var errorDescription: String? {
        switch self {
        case .binaryMissing(let name): return "\(name) is not on PATH"
        case .handshakeFailed(let detail): return "Handshake failed: \(detail)"
        case .unsupported: return "Adapter unavailable for this install"
        case .timeout: return "Agent session timed out"
        }
    }
}

enum AgentRegistry {
    static func adapter(for kind: AgentKind) -> AgentAdapter {
        switch kind {
        case .cursor: return CursorACPAdapter()
        case .codex: return CodexAppServerAdapter()
        }
    }
}
