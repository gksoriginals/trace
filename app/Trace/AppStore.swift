import Combine
import Foundation
import SwiftUI

@MainActor
final class AppStore: ObservableObject {
    @Published var preferences: AppPreferences
    @Published var agents: [AgentStatus] = []
    @Published var projects: [ProjectRecord] = []
    @Published var insights: [ProjectInsight] = []
    @Published var decideLater: [DecideLaterItem] = []
    @Published var route: AppRoute = .home
    @Published var statusMessage: String?
    @Published var skillsRootPath: String = ""
    @Published var installLog: String = ""

    private let prefsStore = AppPreferencesStore()

    init() {
        preferences = prefsStore.load()
        if let source = TracePaths.skillsSource {
            skillsRootPath = source.path
        }
        agents = AgentDetector.detect()
        if preferences.hasCompletedSetup {
            route = .home
            refreshEvidence()
        } else {
            route = .setup
        }
    }

    var showSetup: Bool { !preferences.hasCompletedSetup || route == .setup }

    func refreshAgents() {
        agents = AgentDetector.detect()
    }

    func refreshEvidence() {
        let index = LocalEvidence.loadIndex()
        let opted = Set(preferences.projectRoots)
        projects = index.projects.filter { project in
            if project.opt_out == true { return false }
            if opted.isEmpty { return true }
            let roots = project.roots ?? []
            return roots.contains { root in opted.contains { root.hasPrefix($0) || $0.hasPrefix(root) } }
                || opted.contains(where: { project.memory_log.hasPrefix($0) })
        }
        var queue: [DecideLaterItem] = []
        var cards: [ProjectInsight] = []
        for project in projects {
            let events = LocalEvidence.loadMemory(at: project.memory_log)
            let rawQueue = LocalEvidence.loadQueue(nearMemoryLog: project.memory_log)
            let merged = rawQueue.map { LocalEvidence.mergeStatus($0, overrides: preferences.queueOverrides) }
            let openish = merged.filter { ["open", "planned", "deferred"].contains($0.status) }
            queue.append(contentsOf: openish)
            let coverage: String
            let receipts = events.filter { $0.event_type == "coverage_receipt" }
            if receipts.isEmpty {
                coverage = "Coverage unknown"
            } else if receipts.contains(where: { ($0.why ?? "").lowercased().contains("partial") }) {
                coverage = "Partial coverage"
            } else {
                coverage = "Receipt present"
            }
            cards.append(ProjectInsight(
                id: project.id,
                project: project,
                events: Array(events.suffix(8).reversed()),
                openQueue: merged.filter { $0.status == "open" }.count,
                coverageLabel: coverage
            ))
        }
        decideLater = queue.sorted { ($0.last_observed ?? "") > ($1.last_observed ?? "") }
        insights = cards
    }

    func setQueueStatus(id: String, status: String) {
        preferences.queueOverrides[id] = status
        persist()
        refreshEvidence()
    }

    func persist() {
        do {
            try prefsStore.save(preferences)
            statusMessage = nil
        } catch {
            statusMessage = "Could not save preferences: \(error.localizedDescription)"
        }
    }

    func saveSetup(runFirstReviewNote: Bool) {
        preferences.hasCompletedSetup = true
        persist()
        let root = URL(fileURLWithPath: skillsRootPath, isDirectory: true)
        let result = SkillInstaller.install(skillsRoot: root, projects: preferences.projectRoots)
        installLog = result.output
        if !result.ok {
            statusMessage = "Saved prefs, but skill install failed. See log."
        } else {
            statusMessage = runFirstReviewNote
                ? "Saved and installed skills. First Reviewing is read-only in M1 — use Home; Execute is M2."
                : "Saved without a first run. Home reads local skill files."
        }
        route = .home
        refreshEvidence()
    }

    func ask(question: String, projectId: String?) -> AskAnswer {
        let events: [MemoryEvent]
        if let projectId, let project = projects.first(where: { $0.id == projectId }) {
            events = LocalEvidence.loadMemory(at: project.memory_log)
        } else {
            events = insights.flatMap(\.events)
        }
        return MemoryAsk.answer(question: question, events: events, projectId: projectId)
    }
}
