import Foundation
import Combine

/// Reads skill-owned local stores. Home never starts a model call or scan.
@MainActor
final class TraceStore: ObservableObject {
    @Published var projects: [ProjectIndexRow] = []
    @Published var insights: [ProjectInsight] = []
    @Published var decideLater: [DecideLaterItem] = []
    @Published var loadError: String?
    @Published var hasCompletedSetup: Bool
    @Published var skillsOptIn: SkillsOptIn

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.hasCompletedSetup = UserDefaults.standard.bool(forKey: "trace.hasCompletedSetup")
        self.skillsOptIn = SkillsOptIn.load()
        refresh()
    }

    var traceHome: URL {
        if let env = ProcessInfo.processInfo.environment["TRACE_HOME"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return fileManager.homeDirectoryForCurrentUser.appendingPathComponent(".trace", isDirectory: true)
    }

    var indexURL: URL {
        traceHome.appendingPathComponent("index.json")
    }

    func refresh() {
        loadError = nil
        do {
            let index = try loadIndex()
            projects = index.projects.filter { !($0.opt_out ?? false) }
            var queue: [DecideLaterItem] = []
            var cards: [ProjectInsight] = []
            for project in projects {
                let events = (try? loadMemory(at: project.memory_log)) ?? []
                let projectQueue = (try? loadQueue(nearMemoryLog: project.memory_log)) ?? []
                queue.append(contentsOf: projectQueue.filter { $0.status == "open" || $0.status == "planned" || $0.status == "deferred" })
                cards.append(ProjectInsight(
                    id: project.id,
                    project: project,
                    recentEvents: Array(events.suffix(5).reversed()),
                    openQueueCount: projectQueue.filter { $0.status == "open" }.count
                ))
            }
            decideLater = queue.sorted { ($0.last_observed ?? "") > ($1.last_observed ?? "") }
            insights = cards
        } catch {
            loadError = error.localizedDescription
            projects = []
            insights = []
            decideLater = []
        }
    }

    func markSetupComplete() {
        hasCompletedSetup = true
        UserDefaults.standard.set(true, forKey: "trace.hasCompletedSetup")
        skillsOptIn.save()
        refresh()
    }

    private func loadIndex() throws -> ProjectIndexFile {
        let url = indexURL
        guard fileManager.fileExists(atPath: url.path) else {
            return ProjectIndexFile(schema_version: 1, projects: [])
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProjectIndexFile.self, from: data)
    }

    private func loadMemory(at path: String) throws -> [MemoryEvent] {
        let url = URL(fileURLWithPath: path)
        guard fileManager.fileExists(atPath: url.path) else { return [] }
        let text = try String(contentsOf: url, encoding: .utf8)
        var events: [MemoryEvent] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { continue }
            if let event = try? JSONDecoder().decode(MemoryEvent.self, from: data) {
                events.append(event)
            }
        }
        return events
    }

    private func loadQueue(nearMemoryLog path: String) throws -> [DecideLaterItem] {
        let memoryURL = URL(fileURLWithPath: path)
        let queueURL = memoryURL.deletingLastPathComponent().appendingPathComponent("decide-later.json")
        guard fileManager.fileExists(atPath: queueURL.path) else { return [] }
        let data = try Data(contentsOf: queueURL)
        let file = try JSONDecoder().decode(DecideLaterFile.self, from: data)
        return file.items
    }
}

struct SkillsOptIn: Codable, Equatable {
    var memoryWriter: Bool = true
    var sessionEnd: Bool = true
    var hygienicSetup: Bool = true

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
