import Foundation
import Combine

/// Reads skill-owned markdown stores. Home never starts a model call or scan.
@MainActor
final class TraceStore: ObservableObject {
    @Published var projects: [ProjectIndexRow] = []
    @Published var insights: [ProjectInsight] = []
    @Published var decideLater: [DecideLaterItem] = []
    @Published var insightBodies: [String: String] = [:]
    @Published var loadError: String?
    @Published var hasCompletedSetup: Bool
    @Published var skillsOptIn: SkillsOptIn
    @Published var settings: AppDatabase.Settings
    @Published var journal: [JournalEntry] = []

    private let fileManager: FileManager
    let database: AppDatabase

    init(fileManager: FileManager = .default, database: AppDatabase = .shared) {
        self.fileManager = fileManager
        self.database = database
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: "trace.hasCompletedSetup")
        self.skillsOptIn = SkillsOptIn.load()
        self.settings = database.loadSettings()
        self.journal = database.loadJournal()
        refresh()
    }

    var traceHome: URL {
        if let env = ProcessInfo.processInfo.environment["TRACE_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".trace", isDirectory: true)
    }

    var indexURL: URL {
        let md = traceHome.appendingPathComponent("index.md")
        if fileManager.fileExists(atPath: md.path) { return md }
        let json = traceHome.appendingPathComponent("index.json")
        if fileManager.fileExists(atPath: json.path) { return json }
        return md
    }

    func refresh() {
        loadError = nil
        journal = database.loadJournal()
        settings = database.loadSettings()
        do {
            let index = try MarkdownStore.parseIndex(at: indexURL)
            projects = index.projects.filter { !($0.opt_out ?? false) }
            var queue: [DecideLaterItem] = []
            var cards: [ProjectInsight] = []
            var bodies: [String: String] = [:]
            for project in projects {
                let events = loadMemory(for: project)
                let projectQueue = loadQueue(for: project)
                queue.append(contentsOf: projectQueue.filter {
                    ["open", "planned", "deferred"].contains($0.status ?? "")
                })
                let insightsURL = insightsURL(for: project)
                bodies[project.id] = MarkdownStore.insightsBody(at: insightsURL)
                cards.append(ProjectInsight(
                    id: project.id,
                    project: project,
                    recentEvents: Array(events.suffix(5).reversed()),
                    openQueueCount: projectQueue.filter { $0.status == "open" }.count
                ))
            }
            decideLater = queue.sorted { ($0.last_observed ?? "") > ($1.last_observed ?? "") }
            insights = cards
            insightBodies = bodies
        } catch {
            loadError = error.localizedDescription
            projects = []
            insights = []
            decideLater = []
            insightBodies = [:]
        }
    }

    func markSetupComplete() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: "trace.hasCompletedSetup")
        skillsOptIn.save()
        try? database.saveSettings(settings)
        refresh()
    }

    func updateQueueStatus(id: String, status: String) {
        // Local Keep/Defer: rewrite decide-later.json beside md when present
        for project in projects {
            var items = loadQueue(for: project)
            guard let idx = items.firstIndex(where: { $0.id == id }) else { continue }
            items[idx].status = status
            let url = queueURL(for: project)
            let payload = DecideLaterFile(items: items)
            if let data = try? JSONEncoder().encode(payload) {
                let jsonURL = url.deletingPathExtension().appendingPathExtension("json")
                try? data.write(to: jsonURL, options: .atomic)
            }
        }
        refresh()
    }

    func events(for projectId: String) -> [MemoryEvent] {
        guard let project = projects.first(where: { $0.id == projectId }) else { return [] }
        return loadMemory(for: project)
    }

    func projectRoot(for project: ProjectIndexRow) -> String {
        if let root = project.roots?.first, !root.isEmpty { return root }
        let mem = project.memory_log
        return URL(fileURLWithPath: mem).deletingLastPathComponent().deletingLastPathComponent().path
    }

    private func memoryURL(for project: ProjectIndexRow) -> URL {
        let path = project.memory_log
        let url = URL(fileURLWithPath: path)
        if path.hasSuffix(".jsonl") {
            return url.deletingLastPathComponent().appendingPathComponent("memory", isDirectory: true)
        }
        return url
    }

    private func loadMemory(for project: ProjectIndexRow) -> [MemoryEvent] {
        let url = memoryURL(for: project)
        if url.hasDirectoryPath || url.pathExtension.isEmpty || !url.path.contains(".") {
            let dir = fileManager.fileExists(atPath: url.path) ? url : URL(fileURLWithPath: project.memory_log)
            if dir.pathExtension == "jsonl", let text = try? String(contentsOf: dir, encoding: .utf8) {
                return text.split(separator: "\n").compactMap {
                    try? JSONDecoder().decode(MemoryEvent.self, from: Data($0.utf8))
                }
            }
            return MarkdownStore.parseMemoryDir(at: dir.pathExtension == "jsonl"
                ? dir.deletingLastPathComponent().appendingPathComponent("memory")
                : dir)
        }
        if url.pathExtension == "jsonl" {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
            return text.split(separator: "\n").compactMap {
                try? JSONDecoder().decode(MemoryEvent.self, from: Data($0.utf8))
            }
        }
        return MarkdownStore.parseMemoryDir(at: url)
    }

    private func queueURL(for project: ProjectIndexRow) -> URL {
        let mem = URL(fileURLWithPath: project.memory_log)
        let base = mem.pathExtension == "jsonl" || mem.pathExtension == "md"
            ? mem.deletingLastPathComponent()
            : mem.deletingLastPathComponent()
        let md = base.appendingPathComponent("decide-later.md")
        if fileManager.fileExists(atPath: md.path) { return md }
        return base.appendingPathComponent("decide-later.json")
    }

    private func insightsURL(for project: ProjectIndexRow) -> URL {
        let mem = URL(fileURLWithPath: project.memory_log)
        let base = mem.pathExtension.isEmpty ? mem.deletingLastPathComponent() : mem.deletingLastPathComponent()
        return base.appendingPathComponent("insights.md")
    }

    private func loadQueue(for project: ProjectIndexRow) -> [DecideLaterItem] {
        MarkdownStore.parseDecideLater(at: queueURL(for: project))
    }
}
