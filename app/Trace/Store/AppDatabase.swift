import Foundation

/// App-only writer. Skills never open this store.
final class AppDatabase: @unchecked Sendable {
    static let shared = AppDatabase()

    private let root: URL
    private let fm = FileManager.default
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    private init() {
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Trace", isDirectory: true)
        root = base
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    var journalURL: URL { root.appendingPathComponent("action-journal.json") }
    var checkpointsURL: URL { root.appendingPathComponent("session-checkpoints.json") }
    var settingsURL: URL { root.appendingPathComponent("settings.json") }

    struct Settings: Codable {
        var neverTouch: [String] = []
        var selectedRoots: [String] = []
        var categories: [String] = ["caches", "builds", "worktrees", "containers", "models", "data"]
        var preferredAgent: String = AgentKind.cursor.rawValue
        /// Agents the user has added. Empty means “use detected first adapters” until Setup saves.
        var enabledAgents: [String] = []
        var backgroundReviewEnabled: Bool = false
        var notificationsDecideLater: Bool = false
        var memoryRetentionDays: Int = 90
        var freedSound: Bool = true
        var optedOutProjects: [String] = []
        var appearance: String = "system"
    }

    func loadSettings() -> Settings {
        guard let data = try? Data(contentsOf: settingsURL),
              let s = try? decoder.decode(Settings.self, from: data) else {
            return Settings()
        }
        return s
    }

    func saveSettings(_ settings: Settings) throws {
        try encoder.encode(settings).write(to: settingsURL, options: .atomic)
    }

    func loadJournal() -> [JournalEntry] {
        guard let data = try? Data(contentsOf: journalURL),
              let rows = try? decoder.decode([JournalEntry].self, from: data) else {
            return []
        }
        return rows
    }

    func appendJournal(_ entries: [JournalEntry]) throws {
        var all = loadJournal()
        all.append(contentsOf: entries)
        try encoder.encode(all).write(to: journalURL, options: .atomic)
    }

    func loadCheckpoints() -> [SessionCheckpoint] {
        guard let data = try? Data(contentsOf: checkpointsURL),
              let rows = try? decoder.decode([SessionCheckpoint].self, from: data) else {
            return []
        }
        return rows
    }

    func saveCheckpoint(_ checkpoint: SessionCheckpoint) throws {
        var all = loadCheckpoints().filter {
            !($0.projectId == checkpoint.projectId && $0.agent == checkpoint.agent)
        }
        all.append(checkpoint)
        try encoder.encode(all).write(to: checkpointsURL, options: .atomic)
    }
}
