import Foundation
import Combine
import AppKit
import SwiftUI

/// Shared state for the main-window app (ADR-0012: no menu bar companion).
@MainActor
final class AppModel: ObservableObject {
    enum Destination: Hashable {
        case setup
        case home
        /// Queue of open Decide-later items (rail destination).
        case decideLaterQueue
        /// One Decide-later item detail.
        case decideLaterItem(String)
        case ask(projectId: String?, itemId: String?)
        case run(RunScope)
        case result
        case recovery
        case memory(String?)
        case history
        case settings
    }

    /// Deep Run scope. "All permitted" is every indexed Trace project under selected roots — never whole-disk.
    enum RunScope: Hashable {
        case project(ProjectIndexRow)
        case allPermitted

        var title: String {
            switch self {
            case .project(let p): return p.displayName
            case .allPermitted: return "All permitted projects"
            }
        }
    }

    @Published var destination: Destination = .home
    @Published var setupDraft = SetupDraft()
    /// Floating Ask mini-chat (not a full-page destination).
    @Published var showAskPanel = false
    @Published var askProjectId: String?
    @Published var askItemId: String?
    /// In-place Home run: which project id is active (nil = all permitted / unknown).
    @Published var activeRunProjectId: String?
    @Published var activeRunLabel: String?
    /// Filled after a finished in-place run so Home can show proposal / empty outcome.
    @Published var lastRunOutcome: String?

    let store: TraceStore
    let supervisor: SessionSupervisor
    let conductor: RunConductor
    let background: BackgroundReview

    private var cancellables = Set<AnyCancellable>()

    init() {
        let store = TraceStore()
        let supervisor = SessionSupervisor()
        self.store = store
        self.supervisor = supervisor
        self.conductor = RunConductor()
        self.background = BackgroundReview()
        self.destination = store.hasCompletedSetup ? .home : .setup
        self.setupDraft = SetupDraft.from(store: store)
        background.configure(store: store, supervisor: supervisor)

        store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        supervisor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        conductor.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)

        NotificationCenter.default.addObserver(
            forName: .traceOpenAsk,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openAsk(projectId: nil, itemId: nil)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .traceOpenHome,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMain(to: .home)
            }
        }
        NotificationCenter.default.addObserver(
            forName: .traceOpenSettings,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.openMain(to: .settings)
            }
        }
    }

    func openMain(to dest: Destination) {
        destination = dest
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func openAsk(projectId: String?, itemId: String?) {
        askProjectId = projectId
        askItemId = itemId
        showAskPanel = true
        // Keep the current surface; Ask floats over it.
        if case .ask = destination {
            destination = .home
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func closeAskPanel() {
        showAskPanel = false
        askProjectId = nil
        askItemId = nil
    }

    /// Start a read-only Reviewing pass on Home — progress stays in the status banner, no Run screen.
    func runInPlace(_ scope: RunScope) async {
        guard !supervisor.isBusy else { return }
        destination = .home
        lastRunOutcome = nil
        let projects: [ProjectIndexRow]
        switch scope {
        case .project(let p):
            projects = [p]
            activeRunProjectId = p.id
            activeRunLabel = p.displayName
        case .allPermitted:
            projects = store.projects
            activeRunProjectId = nil
            activeRunLabel = "All permitted projects"
        }
        guard !projects.isEmpty else {
            activeRunLabel = nil
            lastRunOutcome = "Add at least one project folder, then Run."
            return
        }
        let agent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
        // Prefer the shallowest selected root as cwd so nested roots stay in scope.
        let rootProject = projects.min(by: {
            store.projectRoot(for: $0).count < store.projectRoot(for: $1).count
        }) ?? projects[0]
        let root = store.projectRoot(for: rootProject)
        let scopeLabel = activeRunLabel ?? scope.title
        let startedAt = ISO8601DateFormatter().string(from: Date())
        let payload = SkillComposer.reviewingPayload(projects: projects, store: store)
        await supervisor.start(
            kind: agent,
            projectRoot: root,
            resumeId: nil,
            prompt: SkillComposer.compose(payload)
        )
        store.refresh()
        let open = store.decideLater.count
        let agentTitle = agent.title
        let status: String
        if supervisor.isFailed {
            status = "failed"
            lastRunOutcome = supervisor.lastMessage ?? "\(agentTitle) failed."
        } else if supervisor.isCancelled {
            status = "cancelled"
            lastRunOutcome = "Stopped before proposals were ready."
        } else {
            status = "completed"
            lastRunOutcome = open == 0
                ? "\(agentTitle) finished. No disposable proposals in this pass."
                : "\(agentTitle) finished. \(open) item\(open == 1 ? "" : "s") ready in Decide later."
        }
        let logTail = CodexSession.meaningfulLogLines(Array(supervisor.log.suffix(24))).suffix(8).map { $0 }
        let entry = RunHistoryEntry(
            id: UUID().uuidString,
            startedAt: startedAt,
            finishedAt: ISO8601DateFormatter().string(from: Date()),
            status: status,
            agent: agent.rawValue,
            scopeLabel: scopeLabel,
            projectIds: projects.map(\.id),
            rootPath: root,
            summary: lastRunOutcome ?? status,
            openDecideLaterCount: open,
            logTail: logTail,
            usage: supervisor.usage.available ? supervisor.usage : nil
        )
        store.recordRun(entry)
        // Always leave a project-visible receipt, even when nothing was proposed for Trash.
        store.writeRunReceipts(projects: projects, entry: entry)
    }

    /// Add project folders after setup (Home / Settings). Seeds the index immediately.
    func addProjectFolders() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Add"
        panel.message = "Choose project folders for Trace to manage."
        panel.begin { [weak self] response in
            guard response == .OK, let self else { return }
            Task { @MainActor in
                for url in panel.urls {
                    self.store.addSelectedRoot(url.path)
                }
            }
        }
    }

    func clearRunBanner() {
        supervisor.dismissStatus()
        activeRunProjectId = nil
        activeRunLabel = nil
        lastRunOutcome = nil
    }

    func finishSetup(runFirstPass: Bool) async {
        applySetupDraft()
        do {
            let project = setupDraft.optedOutProjects.contains(setupDraft.projectPaths.first ?? "")
                ? nil
                : setupDraft.projectPaths.first
            let enabled = store.settings.enabledAgents.compactMap(AgentKind.init(rawValue:))
            _ = try SkillInstaller.install(optIn: store.skillsOptIn, enabledAgents: enabled, projectPath: project)
        } catch {
            setupDraft.lastMessage = error.localizedDescription
        }
        store.seedProjectsFromSelectedRoots()
        store.markSetupComplete()
        destination = .home

        // S4: first run stays on Home with a progress banner (never Execute, no Run screen).
        guard runFirstPass else { return }
        guard !store.projects.isEmpty else {
            setupDraft.lastMessage = "Saved. Add at least one project root, then use Run from Home."
            return
        }
        let scope: RunScope = store.projects.count == 1
            ? .project(store.projects[0])
            : .allPermitted
        await runInPlace(scope)
    }

    func applySetupDraft() {
        store.skillsOptIn = setupDraft.skillsOptIn
        store.settings.preferredAgent = setupDraft.preferredAgent.rawValue
        store.settings.selectedRoots = setupDraft.projectPaths
        store.settings.categories = setupDraft.enabledCategories
        store.settings.neverTouch = setupDraft.neverTouch
        store.settings.backgroundReviewEnabled = setupDraft.backgroundReview
        store.settings.notificationsDecideLater = setupDraft.notifyDecideLater
        store.settings.memoryRetentionDays = setupDraft.retentionDays
        store.settings.freedSound = setupDraft.freedSound
        store.settings.optedOutProjects = setupDraft.optedOutProjects
        store.settings.enabledAgents = setupDraft.enabledAgents.map(\.rawValue).sorted()
        try? store.database.saveSettings(store.settings)
        store.skillsOptIn.save()
        background.restart()
    }
}

struct SetupDraft {
    var step = 0
    var skillsByAgent: [AgentKind: AgentSkillsOptIn] = [
        .cursor: AgentSkillsOptIn(),
        .codex: AgentSkillsOptIn(),
    ]
    /// Agents the user has added (detected or kept). Unavailable adapters stay out until Add agent finds them.
    var enabledAgents: Set<AgentKind> = []
    var preferredAgent: AgentKind = .cursor
    var cursorStatus: AgentAuthStatus = .unknown
    var codexStatus: AgentAuthStatus = .unknown
    var cursorVersion: String?
    var codexVersion: String?
    var projectPaths: [String] = []
    var suggestedPaths: [String] = []
    var enabledCategories: [String] = StorageCategory.allCases.map(\.rawValue)
    var neverTouch: [String] = []
    var backgroundReview = false
    var notifyDecideLater = false
    var retentionDays = 90
    var freedSound = true
    var optedOutProjects: [String] = []
    var lastMessage = ""

    var skillsOptIn: SkillsOptIn {
        SkillsOptIn(agents: Dictionary(uniqueKeysWithValues: skillsByAgent.map { ($0.key.rawValue, $0.value) }))
    }

    func status(for kind: AgentKind) -> AgentAuthStatus {
        switch kind {
        case .cursor: return cursorStatus
        case .codex: return codexStatus
        }
    }

    func version(for kind: AgentKind) -> String? {
        switch kind {
        case .cursor: return cursorVersion
        case .codex: return codexVersion
        }
    }

    mutating func applyProbe(cursor: (String?, AgentAuthStatus), codex: (String?, AgentAuthStatus)) {
        cursorVersion = cursor.0
        cursorStatus = cursor.1
        codexVersion = codex.0
        codexStatus = codex.1
        for kind in AgentKind.allCases {
            if status(for: kind) != .unsupported {
                enabledAgents.insert(kind)
            }
        }
        if !enabledAgents.contains(preferredAgent), let first = enabledAgents.sorted(by: { $0.rawValue < $1.rawValue }).first {
            preferredAgent = first
        }
    }

    @MainActor
    static func from(store: TraceStore) -> SetupDraft {
        var d = SetupDraft()
        d.skillsByAgent[.cursor] = store.skillsOptIn[.cursor]
        d.skillsByAgent[.codex] = store.skillsOptIn[.codex]
        let saved = store.settings.enabledAgents.compactMap(AgentKind.init(rawValue:))
        d.enabledAgents = Set(saved.isEmpty ? AgentKind.allCases : saved)
        d.preferredAgent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
        d.projectPaths = store.settings.selectedRoots
        d.enabledCategories = store.settings.categories
        d.neverTouch = store.settings.neverTouch
        d.backgroundReview = store.settings.backgroundReviewEnabled
        d.notifyDecideLater = store.settings.notificationsDecideLater
        d.retentionDays = store.settings.memoryRetentionDays
        d.freedSound = store.settings.freedSound
        d.optedOutProjects = store.settings.optedOutProjects
        return d
    }
}

enum StorageCategory: String, CaseIterable, Identifiable {
    case caches, builds, worktrees, containers, models, data
    var id: String { rawValue }
    var title: String {
        switch self {
        case .caches: return "Caches"
        case .builds: return "Builds & environments"
        case .worktrees: return "Worktrees"
        case .containers: return "Containers"
        case .models: return "Models"
        case .data: return "Project data"
        }
    }
    var symbol: String {
        switch self {
        case .caches: return TraceSymbol.caches
        case .builds: return TraceSymbol.builds
        case .worktrees: return TraceSymbol.worktrees
        case .containers: return TraceSymbol.containers
        case .models: return TraceSymbol.models
        case .data: return TraceSymbol.data
        }
    }
    var accent: Color {
        switch self {
        case .caches: return TraceColor.caches
        case .builds: return TraceColor.builds
        case .worktrees: return TraceColor.worktrees
        case .containers: return TraceColor.containers
        case .models: return TraceColor.models
        case .data: return TraceColor.textSecondary
        }
    }
}

extension Notification.Name {
    static let traceOpenAsk = Notification.Name("trace.openAsk")
    static let traceOpenHome = Notification.Name("trace.openHome")
    static let traceOpenSettings = Notification.Name("trace.openSettings")
    static let traceStopAgent = Notification.Name("trace.stopAgent")
}
