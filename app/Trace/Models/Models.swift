import Foundation

struct ProjectIndexFile: Codable {
    var schema_version: Int
    var projects: [ProjectIndexRow]
}

struct ProjectIndexRow: Codable, Identifiable, Hashable {
    var id: String
    var display_name: String?
    var roots: [String]?
    var memory_log: String
    var memory_dir: String?
    var opt_out: Bool?
    var updated_at: String?
    var displayName: String { display_name ?? id }

    enum CodingKeys: String, CodingKey {
        case id, display_name, roots, memory_log, memory_dir, opt_out, updated_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        roots = try c.decodeIfPresent([String].self, forKey: .roots)
        memory_dir = try c.decodeIfPresent(String.self, forKey: .memory_dir)
        memory_log = try c.decodeIfPresent(String.self, forKey: .memory_log)
            ?? memory_dir
            ?? ""
        opt_out = try c.decodeIfPresent(Bool.self, forKey: .opt_out)
        updated_at = try c.decodeIfPresent(String.self, forKey: .updated_at)
    }

    init(id: String, display_name: String? = nil, roots: [String]? = nil, memory_log: String, memory_dir: String? = nil, opt_out: Bool? = nil, updated_at: String? = nil) {
        self.id = id
        self.display_name = display_name
        self.roots = roots
        self.memory_log = memory_log
        self.memory_dir = memory_dir
        self.opt_out = opt_out
        self.updated_at = updated_at
    }
}

struct MemoryEvent: Codable, Identifiable, Hashable {
    var schema_version: Int?
    var event_id: String
    var event_type: String?
    var what: What?
    var why: String?
    var claim: String?
    var agent: AgentRef?
    var project: ProjectRef?
    var created: CreatedRef?
    var can_go_when: String?
    var evidence_ids: [String]?
    var correction_of: String?
    var attribution: AttributionRef?

    var id: String { event_id }

    struct What: Codable, Hashable {
        var id: String?
        var kind: String?
        var location: String?
        var bytes: Int?
        var completeness: String?
    }

    struct AgentRef: Codable, Hashable {
        var harness: String?
        var session_id: String?
    }

    struct ProjectRef: Codable, Hashable {
        var id: String?
        var consumers: [String]?
    }

    struct CreatedRef: Codable, Hashable {
        var at: String?
        var source: String?
    }

    struct AttributionRef: Codable, Hashable {
        var source: String?
        var label: String?
        var counts: Bool?
    }
}

struct DecideLaterItem: Codable, Identifiable, Hashable {
    var schema_version: Int?
    var id: String
    var project_id: String?
    var agent: String?
    var session_id: String?
    var artifact_id: String?
    var action: String?
    var why_doubtful: String?
    var bytes: Int?
    var completeness: String?
    var evidence_ids: [String]?
    var would_resolve: String?
    var first_observed: String?
    var last_observed: String?
    var status: String?
}

struct DecideLaterFile: Codable {
    var items: [DecideLaterItem]
}

struct ProjectInsight: Identifiable, Hashable {
    var id: String
    var project: ProjectIndexRow
    var recentEvents: [MemoryEvent]
    var openQueueCount: Int
}

/// Opt-in skills for one coding-agent host (each host has its own skills folder).
struct AgentSkillsOptIn: Codable, Equatable {
    var hygienicSetup: Bool = true
    var sessionEnd: Bool = true
    var memoryWriter: Bool = true

    var anyEnabled: Bool { hygienicSetup || sessionEnd || memoryWriter }

    /// Skill directory names under `skills/` (product skills only).
    var skillDirectoryNames: [String] {
        var names: [String] = []
        if hygienicSetup { names.append("hygienic-setup") }
        if sessionEnd { names.append("session-end-cleanup") }
        if memoryWriter { names.append("memory-writer") }
        return names
    }

    var summaryLabel: String {
        let parts = skillDirectoryNames
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}

/// Per-agent skill opt-in. Migrates the older flat `SkillsOptIn` shape on load.
struct SkillsOptIn: Codable, Equatable {
    var agents: [String: AgentSkillsOptIn]

    init(agents: [String: AgentSkillsOptIn]? = nil) {
        if let agents, !agents.isEmpty {
            self.agents = agents
        } else {
            self.agents = [
                AgentKind.cursor.rawValue: AgentSkillsOptIn(),
                AgentKind.codex.rawValue: AgentSkillsOptIn(),
            ]
        }
    }

    subscript(_ kind: AgentKind) -> AgentSkillsOptIn {
        get { agents[kind.rawValue] ?? AgentSkillsOptIn() }
        set { agents[kind.rawValue] = newValue }
    }

    private enum CodingKeys: String, CodingKey {
        case agents, hygienicSetup, sessionEnd, memoryWriter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let agents = try c.decodeIfPresent([String: AgentSkillsOptIn].self, forKey: .agents), !agents.isEmpty {
            self.agents = agents
            return
        }
        let flat = AgentSkillsOptIn(
            hygienicSetup: try c.decodeIfPresent(Bool.self, forKey: .hygienicSetup) ?? true,
            sessionEnd: try c.decodeIfPresent(Bool.self, forKey: .sessionEnd) ?? true,
            memoryWriter: try c.decodeIfPresent(Bool.self, forKey: .memoryWriter) ?? true
        )
        self.agents = [
            AgentKind.cursor.rawValue: flat,
            AgentKind.codex.rawValue: flat,
        ]
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(agents, forKey: .agents)
    }

    static func load() -> SkillsOptIn {
        guard let data = UserDefaults.standard.data(forKey: "trace.skillsOptIn"),
              let value = try? JSONDecoder().decode(SkillsOptIn.self, from: data) else {
            return SkillsOptIn()
        }
        return value
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "trace.skillsOptIn")
        }
    }
}

enum AgentKind: String, CaseIterable, Identifiable, Codable {
    case cursor
    case codex

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cursor: return "Cursor"
        case .codex: return "Codex"
        }
    }
}

enum AgentAuthStatus: String, Codable {
    case ready, unknown, unsupported, termsUnmet
}

struct ActionCard: Identifiable, Hashable {
    var id: String
    var title: String
    var summary: String
    var paths: [String]
    var bytes: Int?
    var safety: SafetyState
    var projectId: String
    var agent: String
    var reversible: Bool
    var selected: Bool
    var fingerprints: [String: String]

    enum SafetyState: String, Hashable {
        case verifiedDisposable
        case needsReview
        case protected
        case shared
        case unknown
    }
}

struct JournalEntry: Codable, Identifiable, Hashable {
    var id: String
    var selectionId: String
    var path: String
    var fingerprintAtConfirm: String
    var fingerprintBeforeMove: String?
    var trashDestination: String?
    var outcome: String
    var reason: String?
    var at: String
}

/// One finished (or cancelled/failed) Reviewing pass from Home/Run.
struct RunHistoryEntry: Codable, Identifiable, Hashable {
    var id: String
    /// ISO-8601 start time.
    var startedAt: String
    /// ISO-8601 end time.
    var finishedAt: String
    /// `completed`, `failed`, or `cancelled`.
    var status: String
    var agent: String
    var scopeLabel: String
    var projectIds: [String]
    var rootPath: String?
    var summary: String
    var openDecideLaterCount: Int
    var logTail: [String]
    var usage: UsageReport?
}

struct SessionCheckpoint: Codable, Hashable {
    var projectId: String
    var agent: String
    var model: String?
    var protocolVersion: String
    var sessionId: String?
    var cursor: String?
    var scopeHash: String
    var pendingRequestIds: [String]
    var usage: UsageReport?
}

struct UsageReport: Codable, Hashable {
    var inputTokens: Int?
    var outputTokens: Int?
    var cost: Double?
    var available: Bool

    static let unavailable = UsageReport(inputTokens: nil, outputTokens: nil, cost: nil, available: false)

    var display: String {
        guard available else { return "unavailable" }
        var parts: [String] = []
        if let inputTokens { parts.append("in \(inputTokens)") }
        if let outputTokens { parts.append("out \(outputTokens)") }
        if let cost { parts.append(String(format: "$%.4f", cost)) }
        return parts.isEmpty ? "unavailable" : parts.joined(separator: " · ")
    }
}

struct AskAnswer: Hashable {
    var tier: String
    var text: String
    var citations: [String]
    var unknown: Bool
    var usage: UsageReport?
}
