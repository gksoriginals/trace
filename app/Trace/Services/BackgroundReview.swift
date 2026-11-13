import Foundation

/// Optional scoped review while the Trace app process is running. Never Execute. Dies on quit.
@MainActor
final class BackgroundReview: ObservableObject {
    @Published var lastRunAt: Date?
    @Published var note: String = "Off"

    private var timer: Timer?
    private weak var store: TraceStore?
    private weak var supervisor: SessionSupervisor?

    func configure(store: TraceStore, supervisor: SessionSupervisor) {
        self.store = store
        self.supervisor = supervisor
        restart()
    }

    func restart() {
        timer?.invalidate()
        timer = nil
        guard let store, store.settings.backgroundReviewEnabled else {
            note = "Off"
            return
        }
        note = "Armed (while app running)"
        // Conservative dogfood interval: hourly tick; real schedule UI later
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.tick()
            }
        }
    }

    private func tick() async {
        guard let store, let supervisor, store.settings.backgroundReviewEnabled else { return }
        guard !supervisor.isBusy else {
            note = "Skipped (agent busy)"
            return
        }
        guard let project = store.projects.first else {
            note = "No projects"
            return
        }
        let agent = AgentKind(rawValue: store.settings.preferredAgent) ?? .cursor
        let payload = SkillComposer.prepareHomePayload(project: project, store: store)
        let prompt = SkillComposer.compose(payload)
        await supervisor.start(kind: agent, projectRoot: store.projectRoot(for: project), resumeId: nil, prompt: prompt)
        lastRunAt = Date()
        note = "Last review \(lastRunAt?.description ?? "")"
        store.refresh()
    }
}
