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
    var opt_out: Bool?
    var updated_at: String?

    var name: String { display_name ?? id }
}

struct DecideLaterFile: Codable {
    var items: [DecideLaterItem]
}

struct DecideLaterItem: Codable, Identifiable, Hashable {
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

struct MemoryEvent: Codable, Identifiable, Hashable {
    var schema_version: Int?
    var event_id: String
    var event_type: String
    var what: MemoryWhat?
    var why: String?
    var claim: String?
    var can_go_when: String?

    var id: String { event_id }
}

struct MemoryWhat: Codable, Hashable {
    var id: String?
    var kind: String?
    var location: String?
    var bytes: Int?
    var completeness: String?
}

struct ProjectInsight: Identifiable, Hashable {
    var id: String
    var project: ProjectIndexRow
    var recentEvents: [MemoryEvent]
    var openQueueCount: Int
}
