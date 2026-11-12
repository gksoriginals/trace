import Foundation

// MARK: - Skill-owned files (app reads; skills write)

struct ProjectIndexFile: Codable, Equatable {
    var schema_version: Int
    var projects: [ProjectRecord]
}

struct ProjectRecord: Codable, Equatable, Identifiable, Hashable {
    var id: String
    var display_name: String?
    var roots: [String]?
    var memory_log: String
    var opt_out: Bool?
    var updated_at: String?
    var name: String { display_name ?? id }
}

struct DecideLaterFile: Codable, Equatable {
    var items: [DecideLaterItem]
}

struct DecideLaterItem: Codable, Equatable, Identifiable, Hashable {
    var schema_version: Int?
    var id: String
    var project_id: String
    var agent: String
    var session_id: String
    var artifact_id: String
    var action: String
    var why_doubtful: String
    var bytes: Int?
    var completeness: String?
    var evidence_ids: [String]?
    var would_resolve: String?
    var first_observed: String?
    var last_observed: String?
    var status: String
}

struct MemoryEvent: Codable, Equatable, Identifiable, Hashable {
    var schema_version: Int?
    var event_id: String
    var event_type: String
    var what: MemoryWhat?
    var why: String?
    var claim: String?
    var agent: MemoryAgent?
    var project: MemoryProject?
    var created: MemoryCreated?
    var can_go_when: String?
    var evidence_ids: [String]?
    var correction_of: String?
    var id: String { event_id }
}

struct MemoryWhat: Codable, Equatable, Hashable {
    var id: String?
    var kind: String?
    var location: String?
    var bytes: Int?
    var completeness: String?
}

struct MemoryAgent: Codable, Equatable, Hashable {
    var harness: String?
    var session_id: String?
}

struct MemoryProject: Codable, Equatable, Hashable {
    var id: String?
    var consumers: [String]?
}

struct MemoryCreated: Codable, Equatable, Hashable {
    var at: String?
    var timezone: String?
    var source: String?
}

// MARK: - App-only store (app is the only writer)

struct AppPreferences: Codable, Equatable {
    var schema_version: Int = 1
    var hasCompletedSetup: Bool = false
    var skills: SkillOptIn = .init()
    var preferredAgent: String = "cursor" // cursor | codex
    var projectRoots: [String] = []
    var categories: CategoryScope = .allOn
    var neverTouch: [String] = []
    var menuBarEnabled: Bool = true
    var decideLaterNotifications: Bool = false
    var scheduleEnabled: Bool = false
    var freedSound: Bool = true
    var memoryRetentionDays: Int? = nil
    var queueOverrides: [String: String] = [:] // id → kept|deferred|open|...
    var declinedSkillInstallHint: Bool = false
}

struct SkillOptIn: Codable, Equatable {
    var memoryWriter: Bool = true
    var sessionEnd: Bool = true
    var hygienicSetup: Bool = true
    var decideLater: Bool = true
}

struct CategoryScope: Codable, Equatable {
    var caches: Bool = true
    var builds: Bool = true
    var worktrees: Bool = true
    var containers: Bool = true
    var models: Bool = true
    var projectData: Bool = true
    static let allOn = CategoryScope()
}

struct AgentStatus: Equatable, Identifiable {
    var id: String
    var displayName: String
    var binary: String?
    var version: String?
    var ready: AgentReadiness
}

enum AgentReadiness: String, Equatable {
    case detecting
    case ready
    case unknown
    case absent
    case unsupported
}

struct ProjectInsight: Identifiable, Equatable {
    var id: String
    var project: ProjectRecord
    var events: [MemoryEvent]
    var openQueue: Int
    var coverageLabel: String
}

struct AskAnswer: Equatable {
    var text: String
    var citations: [String]
    var unknown: Bool
    var tier: String = "Memory only · local · no hosted tokens"
}

enum AppRoute: Equatable, Hashable {
    case home
    case setup
    case memory(projectId: String?)
    case decideLater(String)
}
